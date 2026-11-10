"""Prepare the downloaded Transactional FSL v2 archive for preprocessing."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
from pathlib import Path

import numpy as np


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--recorded-data", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    files = sorted(args.recorded_data.glob("*/*.npy"))
    if not files:
        raise FileNotFoundError(f"No .npy samples found below {args.recorded_data}")

    features = []
    rows = []
    shapes: dict[str, int] = {}
    hashes: dict[str, list[str]] = {}
    for path in files:
        array = np.load(path, allow_pickle=False)
        if array.shape != (75, 225):
            raise ValueError(f"{path.name} has {array.shape}, expected (75, 225).")
        # Published processing and the observed 225-feature layout indicate:
        # pose (33*3), left hand (21*3), right hand (21*3). Keep only hands.
        hand_features = array[:, 99:225].astype(np.float32, copy=False)
        digest = hashlib.sha256(array.tobytes()).hexdigest()
        features.append(hand_features)
        hashes.setdefault(digest, []).append(path.name)
        rows.append({
            "sample_id": path.stem,
            "label": path.parent.name,
            # Exact-content groups prevent exact duplicates crossing splits.
            # The archive contains no signer/session/source-recording ID.
            "group": digest,
            "source_file": str(path.relative_to(args.recorded_data)),
        })
        shapes[str(array.shape)] = shapes.get(str(array.shape), 0) + 1

    args.output.mkdir(parents=True, exist_ok=True)
    np.save(args.output / "hand_features.npy", np.stack(features))
    with (args.output / "labels.csv").open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=rows[0].keys())
        writer.writeheader()
        writer.writerows(rows)

    duplicate_groups = [values for values in hashes.values() if len(values) > 1]
    metadata = {
        "sample_count": len(files),
        "class_count": len({row["label"] for row in rows}),
        "source_shape": shapes,
        "selected_columns": "99:225",
        "selected_shape": [75, 126],
        "feature_order": "75 frames; left hand 21 landmarks xyz followed by right hand 21 landmarks xyz",
        "duplicate_groups": len(duplicate_groups),
        "duplicate_files": sum(map(len, duplicate_groups)),
        "signer_ids_available": False,
        "source_recording_ids_available": False,
        "split_limitations": "Exact duplicates are grouped by content hash. Signer-independent and augmentation-independent evaluation cannot be guaranteed from this archive alone.",
    }
    (args.output / "source_metadata.json").write_text(json.dumps(metadata, indent=2), encoding="utf-8")
    print(json.dumps(metadata, indent=2))


if __name__ == "__main__":
    main()
