"""Preview and import the approved Phase 6A content set.

The default target is the local Firestore emulator and the default operation is
preview. Production requests require a short-lived Firebase ID token for the
existing content-admin account in ``FIREBASE_ID_TOKEN``. The script never
deletes documents and updates only fields supplied by the prepared content.
"""

from __future__ import annotations

import argparse
import json
import os
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any


COLLECTIONS = ("signs", "lessons", "grammarExercises")
APPROVED_STATUSES = {"approved", "community_approved", "published"}


def firestore_value(value: Any) -> dict[str, Any]:
    if value is None:
        return {"nullValue": None}
    if isinstance(value, bool):
        return {"booleanValue": value}
    if isinstance(value, int) and not isinstance(value, bool):
        return {"integerValue": str(value)}
    if isinstance(value, float):
        return {"doubleValue": value}
    if isinstance(value, str):
        return {"stringValue": value}
    if isinstance(value, list):
        return {"arrayValue": {"values": [firestore_value(item) for item in value]}}
    if isinstance(value, dict):
        return {"mapValue": {"fields": {
            key: firestore_value(item) for key, item in value.items()
        }}}
    raise TypeError(f"Unsupported Firestore value: {type(value)!r}")


def python_value(value: dict[str, Any]) -> Any:
    if "nullValue" in value:
        return None
    if "booleanValue" in value:
        return value["booleanValue"]
    if "integerValue" in value:
        return int(value["integerValue"])
    if "doubleValue" in value:
        return value["doubleValue"]
    if "stringValue" in value:
        return value["stringValue"]
    if "arrayValue" in value:
        return [python_value(item) for item in value["arrayValue"].get("values", [])]
    if "mapValue" in value:
        return {
            key: python_value(item)
            for key, item in value["mapValue"].get("fields", {}).items()
        }
    raise ValueError(f"Unsupported Firestore response value: {value}")


def validate(payload: dict[str, Any], operation: str) -> None:
    for section in COLLECTIONS:
        if not isinstance(payload.get(section), list):
            raise ValueError(f"{section} must be a list")

    ids: dict[str, set[str]] = {}
    for section in COLLECTIONS:
        ids[section] = set()
        for item in payload[section]:
            item_id = str(item.get("id", "")).strip()
            if not item_id:
                raise ValueError(f"{section} contains a document without an id")
            if item_id in ids[section]:
                raise ValueError(f"duplicate {section} id: {item_id}")
            ids[section].add(item_id)

    for item in payload["signs"]:
        for field in ("word", "category", "difficulty"):
            if not str(item.get(field, "")).strip():
                raise ValueError(f"sign missing {field}: {item['id']}")

    for item in payload["lessons"]:
        for field in ("title", "category", "description", "signIds", "activities"):
            if field not in item:
                raise ValueError(f"lesson missing {field}: {item['id']}")
        if not isinstance(item["activities"], list):
            raise ValueError(f"lesson activities must be a list: {item['id']}")
        missing = set(item["signIds"]) - ids["signs"]
        if missing:
            raise ValueError(f"lesson {item['id']} references missing signs: {sorted(missing)}")

    for item in payload["grammarExercises"]:
        for field in ("category", "difficulty", "promptText", "tiles"):
            if field not in item:
                raise ValueError(f"grammar exercise missing {field}: {item['id']}")
        if item.get("lessonId") and item["lessonId"] not in ids["lessons"]:
            raise ValueError(f"grammar exercise {item['id']} references missing lesson")
        for tile in item["tiles"]:
            if tile.get("signId") not in ids["signs"] or not isinstance(
                    tile.get("correctPosition"), int):
                raise ValueError(f"invalid grammar tile: {item['id']}")

    if operation == "publish":
        unapproved = []
        for section in COLLECTIONS:
            for item in payload[section]:
                status = str(item.get("contentValidationStatus", "")).lower()
                if status not in APPROVED_STATUSES:
                    unapproved.append(f"{section}/{item['id']} ({status or 'missing status'})")
        if unapproved:
            raise ValueError(
                "publish requires approved content; review these first: "
                + ", ".join(unapproved)
            )


def request_json(
    url: str,
    method: str,
    body: dict[str, Any] | None = None,
    id_token: str | None = None,
) -> tuple[int, str]:
    data = None if body is None else json.dumps(body).encode("utf-8")
    headers = {"Content-Type": "application/json"}
    if id_token:
        headers["Authorization"] = f"Bearer {id_token}"
    request = urllib.request.Request(url, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(request, timeout=15) as response:
            return response.status, response.read().decode("utf-8")
    except urllib.error.HTTPError as error:
        return error.code, error.read().decode("utf-8")
    except urllib.error.URLError as error:
        raise RuntimeError(f"Could not reach Firestore at {url}: {error.reason}") from error


def collection_url(base: str, project: str, collection: str) -> str:
    return f"{base}/v1/projects/{project}/databases/(default)/documents/{collection}"


def inspect_document(
    base: str,
    project: str,
    collection: str,
    document_id: str,
    id_token: str | None,
) -> tuple[str, dict[str, Any]]:
    encoded_id = urllib.parse.quote(document_id, safe="")
    url = f"{collection_url(base, project, collection)}/{encoded_id}"
    status, response = request_json(url, "GET", id_token=id_token)
    if status == 404:
        return "missing", {}
    if status != 200:
        raise RuntimeError(
            f"Could not inspect {collection}/{document_id}: HTTP {status} {response}"
        )
    raw = json.loads(response)
    return "existing", {
        key: python_value(value) for key, value in raw.get("fields", {}).items()
    }


def changed_fields(existing: dict[str, Any], document: dict[str, Any]) -> dict[str, Any]:
    return {
        key: value for key, value in document.items()
        if key != "id" and existing.get(key) != value
    }


def write_document(
    base: str,
    project: str,
    collection: str,
    document: dict[str, Any],
    state: str,
    fields: dict[str, Any],
    id_token: str | None,
) -> None:
    document_id = document["id"]
    encoded_id = urllib.parse.quote(document_id, safe="")
    document_url = f"{collection_url(base, project, collection)}/{encoded_id}"
    encoded_fields = {key: firestore_value(value) for key, value in fields.items()}
    if state == "missing":
        url = f"{collection_url(base, project, collection)}?documentId={encoded_id}"
        status, response = request_json(
            url, "POST", {"fields": encoded_fields}, id_token=id_token
        )
    else:
        query = urllib.parse.urlencode(
            [("updateMask.fieldPaths", key) for key in encoded_fields]
        )
        status, response = request_json(
            f"{document_url}?{query}",
            "PATCH",
            {"fields": encoded_fields},
            id_token=id_token,
        )
    if status not in (200, 201):
        raise RuntimeError(
            f"Could not write {collection}/{document_id}: HTTP {status} {response}"
        )


def import_collection(
    base: str,
    project: str,
    collection: str,
    documents: list[dict[str, Any]],
    operation: str,
    dry_run: bool,
    id_token: str | None,
) -> dict[str, int]:
    totals = {"created": 0, "updated": 0, "unchanged": 0, "skipped": 0}
    for document in documents:
        state, existing = inspect_document(
            base, project, collection, document["id"], id_token
        )
        fields = changed_fields(existing, document) if state == "existing" else {
            key: value for key, value in document.items() if key != "id"
        }
        if not fields:
            totals["unchanged"] += 1
            continue
        if operation == "create" and state == "existing":
            totals["skipped"] += 1
            continue
        if operation == "update" and state == "missing":
            totals["skipped"] += 1
            continue

        action = "create" if state == "missing" else "update"
        print(json.dumps({
            "action": action,
            "document": f"{collection}/{document['id']}",
            "fields": fields,
            "applied": not dry_run,
        }, sort_keys=True))
        if not dry_run:
            write_document(base, project, collection, document, state, fields, id_token)
        totals["created" if action == "create" else "updated"] += 1
    return totals


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--content", type=Path, default=Path("content/phase6a_fsl_draft.json"))
    parser.add_argument("--project", default="learn-sign-ph")
    parser.add_argument("--target", choices=("emulator", "production"), default="emulator")
    parser.add_argument(
        "--operation",
        choices=("preview", "create", "update", "publish"),
        default="preview",
        help="preview is read-only; publish creates or updates approved content",
    )
    parser.add_argument("--dry-run", action="store_true", help="do not write changes")
    args = parser.parse_args()

    payload = json.loads(args.content.read_text(encoding="utf-8"))
    validate(payload, args.operation)

    if args.target == "production":
        base = "https://firestore.googleapis.com"
        id_token = os.environ.get("FIREBASE_ID_TOKEN", "").strip()
        if not id_token:
            raise SystemExit(
                "Production access requires FIREBASE_ID_TOKEN for the existing "
                "content-admin account. No token was read or displayed."
            )
    else:
        base = "http://127.0.0.1:8080"
        id_token = None

    dry_run = args.dry_run or args.operation == "preview"
    totals = {}
    try:
        for collection in COLLECTIONS:
            totals[collection] = import_collection(
                base, args.project, collection, payload[collection],
                args.operation, dry_run, id_token,
            )
    except RuntimeError as error:
        raise SystemExit(str(error)) from error
    print(json.dumps({
        "target": args.target,
        "operation": args.operation,
        "dry_run": dry_run,
        "deletions": "disabled",
        "collections": totals,
    }, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
