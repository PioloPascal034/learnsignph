# Phase 5A Training Results

## Dataset

- Source: Transactional Filipino Sign Language Dataset v2, DOI `10.17632/jdyrr7cm4z.2`
- Downloaded archive: `training/data/transactional_fsl_v2.zip`
- Inspected samples: 1,107 `.npy` files
- Classes: 26
- Raw shape: `(75, 225)` `float64`
- Selected hand slice: columns `99:225`, producing `(75, 126)` per sample
- Normalized artifact: `[N, 75, 2, 21, 3]`
- Split: 774 train, 166 validation, 167 test

## Model

Fixed-length GRU classifier:

`GRU(96, unroll=True) -> Dropout(0.25) -> GRU(64, unroll=True) -> Dense(64, relu) -> Dropout(0.25) -> Dense(26, softmax)`

The unrolled GRUs were selected because the first Masking-based model trained successfully but failed builtin TensorFlow Lite conversion due to dynamic tensor-list operations. The replacement exports without Select TF Ops.

## Metrics

- Best epoch: 39
- Validation accuracy: 0.9698795080 (96.99%)
- Held-out test accuracy: 0.9341317365 (93.41%)
- Macro precision: 0.9402625153 (94.03%)
- Macro recall: 0.9285103785 (92.85%)

The complete per-class report and 26x26 confusion matrix are in [`artifacts/evaluation.json`](./artifacts/evaluation.json).

## Outputs

- [`transactional_fsl_gru.keras`](./artifacts/transactional_fsl_gru.keras)
- [`transactional_fsl_gru.tflite`](./artifacts/transactional_fsl_gru.tflite)
- [`label_map.json`](./processed/label_map.json)
- [`live_inference_config.json`](./artifacts/live_inference_config.json)
- [`training_config.json`](./artifacts/training_config.json)

The TFLite interpreter was loaded successfully with input shape `[1, 75, 126]` and output shape `[1, 26]`.

## Evaluation limitation

The archive has no signer IDs, session IDs, or source-recording IDs. Exact duplicate content was grouped by SHA-256 and none was found. Augmented-source separation and signer-independent generalization therefore remain unverified; the reported metrics are sample-level results, not a claim of signer-independent recognition.
