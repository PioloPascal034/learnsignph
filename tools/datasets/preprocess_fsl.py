"""Offline preprocessing for FSL landmark datasets.

This script intentionally does not train a model and does not modify Firebase.
It accepts MediaPipe-style landmark arrays and emits a stable sequence format:
[sample, frame, hand, landmark, xyz], plus a hand-presence mask and labels.

Dependencies: Python 3.10+, numpy. Install them in an isolated environment;
they are not Flutter application dependencies.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
from pathlib import Path
from typing import Any

import numpy as np


def read_labels(path: Path) -> tuple[list[str], list[str]]:
    """Read labels from CSV columns sample_id/id, label, and optional group."""
    ids: list[str] = []
    labels: list[str] = []
    groups: list[str] = []
    with path.open(newline="", encoding="utf-8-sig") as handle:
        rows = csv.DictReader(handle)
        if not rows.fieldnames or "label" not in rows.fieldnames:
            raise ValueError("Labels CSV must contain a 'label' column.")
        for index, row in enumerate(rows):
            ids.append(row.get("sample_id") or row.get("id") or str(index))
            labels.append(row["label"])
            groups.append(row.get("group") or ids[-1])
    return labels, groups


def load_samples(path: Path) -> list[np.ndarray]:
    """Load fixed or variable-length arrays without guessing unsupported layouts."""
    raw = np.load(path, allow_pickle=True)
    if raw.dtype == object and raw.shape == ():
        raw = raw.item()
    if isinstance(raw, np.ndarray) and raw.dtype == object:
        return [np.asarray(item, dtype=np.float32) for item in raw.tolist()]
    array = np.asarray(raw, dtype=np.float32)
    if array.ndim == 2 and array.shape[1] in (63, 126):
        return [item for item in array]
    if array.ndim in (3, 4):
        return [item for item in array]
    raise ValueError(
        f"Unsupported array shape {array.shape}; expected [N,63], [N,126], "
        "[N,T,63], [N,T,126], or [N,T,21,3]."
    )


def as_hands(sample: np.ndarray, hand_slice: tuple[int, int] | None) -> np.ndarray:
    """Map one sample to [frames, 2, 21, 3].

    A 63-feature sample is one hand. A 126-feature sample is two concatenated
    hands. Holistic arrays must use --hand-slice explicitly; the script never
    assumes that unrelated Holistic landmarks are Hand Landmarker landmarks.
    """
    array = np.asarray(sample, dtype=np.float32)
    if array.ndim == 2 and array.shape == (21, 3):
        array = array[None, None, :, :]
    elif array.ndim == 1:
        array = array[None, :]
    if array.ndim == 3 and array.shape[-2:] == (21, 3):
        array = array[:, None, :, :]
    elif array.ndim == 4 and array.shape[-2:] == (21, 3):
        if array.shape[1] not in (1, 2):
            raise ValueError("The hand axis must contain one or two hands.")
    elif array.ndim == 2:
        if hand_slice is not None:
            start, end = hand_slice
            array = array[:, start:end]
        if array.shape[-1] not in (63, 126):
            raise ValueError(
                f"Sample has {array.shape[-1]} features; provide --hand-slice "
                "for a verified Holistic hand segment."
            )
        hands = array.shape[-1] // 63
        array = array.reshape(array.shape[0], hands, 21, 3)
    else:
        raise ValueError(f"Unsupported sample shape {array.shape}.")
    if array.shape[1] == 1:
        padded = np.zeros((array.shape[0], 2, 21, 3), dtype=np.float32)
        padded[:, 0] = array[:, 0]
        return padded
    if array.shape[1] == 2:
        return array.astype(np.float32, copy=False)
    raise ValueError("Only one- or two-hand samples are supported.")


def normalize(sequence: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Make coordinates wrist-relative and scale each hand by wrist-middle MCP."""
    output = np.zeros_like(sequence, dtype=np.float32)
    present = np.zeros(sequence.shape[:2], dtype=np.uint8)
    for frame in range(sequence.shape[0]):
        for hand in range(2):
            points = sequence[frame, hand]
            if not np.isfinite(points).all() or np.allclose(points, 0):
                continue
            wrist = points[0].copy()
            centered = points - wrist
            scale = float(np.linalg.norm(centered[9]))
            if scale <= 1e-6:
                scale = float(np.max(np.linalg.norm(centered, axis=1)))
            if scale <= 1e-6:
                continue
            output[frame, hand] = centered / scale
            present[frame, hand] = 1
    return output, present


def split_groups(groups: list[str], seed: int) -> dict[str, list[int]]:
    """Deterministically split whole groups to prevent sequence leakage."""
    unique = sorted(set(groups), key=lambda value: hashlib.sha256(
        f"{seed}:{value}".encode()).hexdigest())
    n = len(unique)
    train_end = max(1, int(n * 0.70))
    valid_end = max(train_end + 1, int(n * 0.85)) if n > 1 else n
    buckets = {"train": set(unique[:train_end]),
               "validation": set(unique[train_end:valid_end]),
               "test": set(unique[valid_end:])}
    return {name: [i for i, group in enumerate(groups) if group in values]
            for name, values in buckets.items()}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--features", type=Path, required=True)
    parser.add_argument("--labels", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--max-frames", type=int, default=100)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--hand-slice", type=str)
    args = parser.parse_args()
    hand_slice = None
    if args.hand_slice:
        start, end = args.hand_slice.split(":", 1)
        hand_slice = (int(start), int(end))

    samples = load_samples(args.features)
    labels, groups = read_labels(args.labels)
    if len(samples) != len(labels):
        raise ValueError(f"Feature samples ({len(samples)}) and labels ({len(labels)}) differ.")

    encoded = {label: index for index, label in enumerate(sorted(set(labels)))}
    features = np.zeros((len(samples), args.max_frames, 2, 21, 3), dtype=np.float32)
    mask = np.zeros((len(samples), args.max_frames, 2), dtype=np.uint8)
    for index, sample in enumerate(samples):
        normalized, present = normalize(as_hands(sample, hand_slice))
        length = min(args.max_frames, normalized.shape[0])
        features[index, :length] = normalized[:length]
        mask[index, :length] = present[:length]

    splits = split_groups(groups, args.seed)
    args.output.mkdir(parents=True, exist_ok=True)
    np.savez_compressed(args.output / "landmarks.npz", features=features, mask=mask,
                        labels=np.asarray([encoded[label] for label in labels], dtype=np.int64))
    (args.output / "label_map.json").write_text(json.dumps(encoded, indent=2), encoding="utf-8")
    (args.output / "splits.json").write_text(json.dumps(splits, indent=2), encoding="utf-8")
    print(json.dumps({"samples": len(samples), "features": list(features.shape),
                      "labels": len(encoded), "splits": {k: len(v) for k, v in splits.items()}},
                     indent=2))


if __name__ == "__main__":
    main()
