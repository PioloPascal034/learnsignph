# FSL Dataset Evaluation

## Sources reviewed

| Source | Verified metadata | Compatibility | Decision |
|---|---|---|---|
| [FSL-105](https://data.mendeley.com/datasets/48y2y99mb9/2) | 2,130 four-second 640x360 videos, 105 signs, `train.csv`, `test.csv`, `labels.csv`, CC BY 4.0 | Raw video; requires a separate landmark-extraction stage and subject/group metadata review | Good future video source, not the first pipeline input |
| [Transactional FSL](https://data.mendeley.com/datasets/jdyrr7cm4z/2) | 1,065 `.npy` coordinate samples, 26 classes, zero-padded to 100 frames, MediaPipe Holistic, CC BY 4.0 | Closest to the current live landmark stream, but Holistic hand-column layout must be verified from downloaded files | Recommended first candidate |
| [MediaPipe-FSL-Alphabet](https://github.com/ji-chani/MediaPipe-FSL-Alphabet) | Repository contains a 24-class `.npy` feature dataset, a 63-feature SVM module, scaler, classifier, and predicted labels; README says J and Z are omitted | Static single-hand 21x3 flattened features; useful compatibility reference, but repository does not provide a complete raw-label manifest | Useful baseline/reference, not sufficient as sole source |

The two Mendeley datasets explicitly state CC BY 4.0. Attribution and dataset-specific terms must be retained in any released training artifact. Mendeley states that publication review checks repository requirements, not the scientific correctness or FSL/community validity of the labels; Deaf-community and subject-matter review is still required before teaching or scoring signs.

## Format decision

The preprocessing target is `[sample, frame, hand, landmark, xyz]` with shape `[N, T, 2, 21, 3]`, a presence mask, integer labels, and deterministic group splits. The current Android detector returns one or two hands with 21 normalized `(x, y, z)` landmarks, so this representation is directly consumable by a future classifier after the dataset's Holistic columns are verified.

The Transactional dataset's published description says its arrays are 100-frame, zero-padded MediaPipe Holistic coordinates. Holistic hand coordinates must not be assumed to equal the Android Hand Landmarker output: the pipeline requires an explicit `--hand-slice START:END` when the source array includes pose/face or other Holistic columns. It rejects unknown feature widths instead of silently mapping them.

## Usage

```text
python tools/datasets/preprocess_fsl.py \
  --features path/to/features.npy \
  --labels path/to/labels.csv \
  --output build/fsl_dataset \
  --max-frames 100 \
  --seed 42 \
  --hand-slice START:END
```

The labels CSV must contain `label` and may contain `sample_id`/`id` and `group`. Group IDs should identify a signer, recording session, or source clip family; splitting by group prevents near-duplicate frames from crossing train/validation/test. The script normalizes each present hand wrist-relative and scales by the wrist-to-middle-MCP distance, pads/truncates sequences, preserves labels, and records `landmarks.npz`, `label_map.json`, and `splits.json`.

No dataset files are copied into the Flutter application, no model is trained, and no production content is changed.
