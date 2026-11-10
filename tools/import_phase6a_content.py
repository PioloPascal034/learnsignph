"""Validate and idempotently import Phase 6A content into Firestore Emulator.

This script never updates an existing document. It is intentionally limited to
the supplied draft JSON and a development/emulator endpoint.
"""

from __future__ import annotations

import argparse
import json
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any


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


def validate(payload: dict[str, Any]) -> None:
    required_sections = ("signs", "lessons", "grammarExercises")
    for section in required_sections:
        if not isinstance(payload.get(section), list):
            raise ValueError(f"{section} must be a list")
    for item in payload["signs"]:
        for field in ("id", "word", "category", "difficulty"):
            if not str(item.get(field, "")).strip():
                raise ValueError(f"sign missing {field}: {item}")
    for item in payload["lessons"]:
        for field in ("id", "title", "category", "description", "signIds"):
            if field not in item:
                raise ValueError(f"lesson missing {field}: {item.get('id')}")
        if not isinstance(item["activities"], list):
            raise ValueError(f"lesson activities must be a list: {item['id']}")
    for item in payload["grammarExercises"]:
        for field in ("id", "category", "difficulty", "promptText", "tiles"):
            if field not in item:
                raise ValueError(f"grammar exercise missing {field}: {item.get('id')}")
        for tile in item["tiles"]:
            if not tile.get("signId") or not isinstance(tile.get("correctPosition"), int):
                raise ValueError(f"invalid grammar tile: {item['id']}")


def request_json(url: str, method: str, body: dict[str, Any] | None = None) -> tuple[int, str]:
    data = None if body is None else json.dumps(body).encode("utf-8")
    request = urllib.request.Request(url, data=data, method=method,
                                     headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(request, timeout=15) as response:
            return response.status, response.read().decode("utf-8")
    except urllib.error.HTTPError as error:
        return error.code, error.read().decode("utf-8")


def import_collection(base: str, project: str, collection: str,
                      documents: list[dict[str, Any]], dry_run: bool) -> tuple[int, int]:
    created = 0
    skipped = 0
    collection_url = f"{base}/v1/projects/{project}/databases/(default)/documents/{collection}"
    for document in documents:
        document_id = document["id"]
        encoded_id = urllib.parse.quote(document_id, safe="")
        document_url = f"{collection_url}/{encoded_id}"
        status, _ = request_json(document_url, "GET")
        if status == 200:
            skipped += 1
            continue
        if status != 404:
            raise RuntimeError(f"Could not inspect {collection}/{document_id}: HTTP {status}")
        if dry_run:
            created += 1
            continue
        fields = {key: firestore_value(value) for key, value in document.items() if key != "id"}
        create_url = f"{collection_url}?documentId={encoded_id}"
        status, response = request_json(create_url, "POST", {"fields": fields})
        if status not in (200, 201):
            raise RuntimeError(f"Could not create {collection}/{document_id}: HTTP {status} {response}")
        created += 1
    return created, skipped


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--content", type=Path, default=Path("content/phase6a_fsl_draft.json"))
    parser.add_argument("--host", default="http://127.0.0.1:8080")
    parser.add_argument("--project", default="learn-sign-ph")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    payload = json.loads(args.content.read_text(encoding="utf-8"))
    validate(payload)
    base = args.host.rstrip("/")
    totals = {}
    for collection in ("signs", "lessons", "grammarExercises"):
        created, skipped = import_collection(base, args.project, collection,
                                              payload[collection], args.dry_run)
        totals[collection] = {"created": created, "skipped_existing": skipped}
    print(json.dumps({"dry_run": args.dry_run, "collections": totals}, indent=2))


if __name__ == "__main__":
    main()
