"""Extract Android-compatible 21-landmark features from the Kaggle FSL images."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
from pathlib import Path

import cv2
import mediapipe as mp
import numpy as np
from mediapipe.tasks import python
from mediapipe.tasks.python import vision


STATIC_LABELS = [letter for letter in "ABCDEFGHIJKLMNOPQRSTUVWXYZ" if letter not in {"J", "Z"}]


def normalize_landmarks(points: np.ndarray, handedness: str) -> np.ndarray | None:
    centered = points - points[0]
    scale = float(np.linalg.norm(centered[9]))
    if scale <= 1e-6:
        scale = float(np.max(np.linalg.norm(centered, axis=1)))
    if scale <= 1e-6:
        return None
    normalized = centered / scale
    # Canonicalize left hands to the right-hand orientation. The Android
    # pipeline must apply the same x-axis canonicalization before inference.
    if handedness.lower() == "left":
        normalized[:, 0] *= -1
    return normalized.astype(np.float32)


def source_group(path: Path) -> str:
    # Kaggle files include original names and Roboflow augmentation names such
    # as 100_jpg.rf.<hash>.jpg. They belong to the same source group.
    return path.stem.split("_jpg.rf.", 1)[0]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--images", type=Path, required=True)
    parser.add_argument("--model", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args()

    args.output.mkdir(parents=True, exist_ok=True)
    files = sorted(args.images.glob("*/*.jpg"))
    all_counts = {label: 0 for label in "ABCDEFGHIJKLMNOPQRSTUVWXYZ"}
    excluded_counts = {"J": 0, "Z": 0}
    features: list[np.ndarray] = []
    rows: list[dict[str, str | float]] = []
    invalid = 0
    handedness_counts: dict[str, int] = {}

    base_options = python.BaseOptions(model_asset_path=str(args.model))
    options = vision.HandLandmarkerOptions(
        base_options=base_options,
        running_mode=vision.RunningMode.IMAGE,
        num_hands=1,
        min_hand_detection_confidence=0.5,
        min_hand_presence_confidence=0.5,
    )
    with vision.HandLandmarker.create_from_options(options) as landmarker:
        for index, path in enumerate(files, start=1):
            label = path.parent.name.upper()
            if label not in all_counts:
                continue
            all_counts[label] += 1
            if label not in STATIC_LABELS:
                excluded_counts[label] += 1
                continue
            image = cv2.imread(str(path))
            if image is None:
                invalid += 1
                continue
            rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
            result = landmarker.detect(mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb))
            if not result.hand_landmarks or len(result.hand_landmarks[0]) != 21:
                invalid += 1
                continue
            landmarks = np.asarray(
                [[point.x, point.y, point.z] for point in result.hand_landmarks[0]],
                dtype=np.float32,
            )
            category = result.handedness[0][0]
            handedness = category.category_name or "Unknown"
            normalized = normalize_landmarks(landmarks, handedness)
            if normalized is None:
                invalid += 1
                continue
            features.append(normalized.reshape(63))
            handedness_counts[handedness] = handedness_counts.get(handedness, 0) + 1
            rows.append({
                "sample_id": path.stem,
                "label": label,
                "source_group": f"{label}:{source_group(path)}",
                "source_file": str(path.relative_to(args.images)),
                "handedness": handedness,
                "handedness_score": float(category.score),
            })
            if index % 500 == 0:
                print(f"processed {index}/{len(files)} images; valid={len(features)} invalid={invalid}")

    if not features:
        raise RuntimeError("No valid landmark samples were extracted.")
    feature_array = np.stack(features).astype(np.float32)
    labels = sorted({row["label"] for row in rows})
    label_map = {label: index for index, label in enumerate(labels)}

    groups_by_label: dict[str, list[str]] = {}
    for row in rows:
        groups_by_label.setdefault(str(row["label"]), []).append(str(row["source_group"]))
    split_indices = {"train": [], "validation": [], "test": []}
    for label, groups in groups_by_label.items():
        unique_groups = sorted(set(groups), key=lambda value: hashlib.sha256(
            f"{args.seed}:{value}".encode()).hexdigest())
        train_end = max(1, int(len(unique_groups) * 0.70))
        validation_end = max(train_end + 1, int(len(unique_groups) * 0.85))
        buckets = {
            "train": set(unique_groups[:train_end]),
            "validation": set(unique_groups[train_end:validation_end]),
            "test": set(unique_groups[validation_end:]),
        }
        for split, selected in buckets.items():
            split_indices[split].extend(
                index for index, row in enumerate(rows)
                if row["label"] == label and row["source_group"] in selected
            )

    np.save(args.output / "features.npy", feature_array)
    np.save(args.output / "labels.npy", np.asarray([label_map[str(row["label"])] for row in rows]))
    with (args.output / "metadata.csv").open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=rows[0].keys())
        writer.writeheader()
        writer.writerows(rows)
    (args.output / "label_map.json").write_text(json.dumps(label_map, indent=2), encoding="utf-8")
    (args.output / "splits.json").write_text(json.dumps(split_indices, indent=2), encoding="utf-8")
    (args.output / "extraction_metadata.json").write_text(json.dumps({
        "source": "Kaggle japorton/fsl-dataset",
        "source_license_metadata": "CC0 Public Domain (Kaggle metadata)",
        "raw_images": len(files),
        "raw_counts": all_counts,
        "static_labels": labels,
        "excluded_motion_labels": excluded_counts,
        "valid_samples": len(features),
        "invalid_or_missing_landmarks": invalid,
        "feature_shape": list(feature_array.shape),
        "feature_order": "21 MediaPipe Hand Landmarker landmarks xyz, wrist-relative and middle-MCP scaled",
        "left_hand_policy": "x-axis canonicalized to right-hand orientation",
        "handedness_counts": handedness_counts,
        "participant_metadata_available": False,
        "split_policy": "source-group split; exact/augmentation variants sharing the filename source stem stay together",
        "signer_independent": False,
    }, indent=2), encoding="utf-8")
    print(json.dumps({"valid": len(features), "invalid": invalid, "labels": labels,
                      "splits": {key: len(value) for key, value in split_indices.items()}}, indent=2))


if __name__ == "__main__":
    main()
