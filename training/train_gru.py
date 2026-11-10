"""Train and evaluate a small GRU classifier and export it to TensorFlow Lite."""

from __future__ import annotations

import argparse
import json
import random
from pathlib import Path

import numpy as np
import tensorflow as tf
from sklearn.metrics import classification_report, confusion_matrix


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dataset", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--epochs", type=int, default=80)
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args()

    random.seed(args.seed)
    np.random.seed(args.seed)
    tf.random.set_seed(args.seed)
    args.output.mkdir(parents=True, exist_ok=True)

    data = np.load(args.dataset / "landmarks.npz")
    label_map = json.loads((args.dataset / "label_map.json").read_text(encoding="utf-8"))
    splits = json.loads((args.dataset / "splits.json").read_text(encoding="utf-8"))
    labels_by_index = {int(index): label for label, index in label_map.items()}
    x = data["features"].astype(np.float32)
    # Flatten the two hand streams while preserving frame order.
    x = x.reshape(x.shape[0], x.shape[1], -1)
    y = data["labels"].astype(np.int64)
    train_idx = np.asarray(splits["train"], dtype=np.int64)
    valid_idx = np.asarray(splits["validation"], dtype=np.int64)
    test_idx = np.asarray(splits["test"], dtype=np.int64)

    model = tf.keras.Sequential([
        tf.keras.layers.Input(shape=x.shape[1:]),
        # The dataset is already fixed-length (75 frames). Unrolling keeps
        # TensorFlow Lite export on builtin operators without Select TF Ops.
        tf.keras.layers.GRU(96, return_sequences=True, unroll=True),
        tf.keras.layers.Dropout(0.25),
        tf.keras.layers.GRU(64, unroll=True),
        tf.keras.layers.Dense(64, activation="relu"),
        tf.keras.layers.Dropout(0.25),
        tf.keras.layers.Dense(len(label_map), activation="softmax"),
    ])
    model.compile(optimizer=tf.keras.optimizers.Adam(learning_rate=1e-3),
                  loss="sparse_categorical_crossentropy", metrics=["accuracy"])
    callbacks = [
        tf.keras.callbacks.EarlyStopping(monitor="val_accuracy", patience=12,
                                         restore_best_weights=True),
        tf.keras.callbacks.ReduceLROnPlateau(monitor="val_loss", factor=0.5,
                                              patience=5, min_lr=1e-5),
    ]
    history = model.fit(x[train_idx], y[train_idx], validation_data=(x[valid_idx], y[valid_idx]),
                        epochs=args.epochs, batch_size=32, callbacks=callbacks, verbose=2)

    probabilities = model.predict(x[test_idx], verbose=0)
    predictions = probabilities.argmax(axis=1)
    report = classification_report(y[test_idx], predictions,
                                   labels=sorted(labels_by_index),
                                   target_names=[labels_by_index[i] for i in sorted(labels_by_index)],
                                   output_dict=True, zero_division=0)
    matrix = confusion_matrix(y[test_idx], predictions, labels=sorted(labels_by_index))
    evaluation = {
        "seed": args.seed,
        "input_shape": list(x.shape[1:]),
        "train_samples": len(train_idx),
        "validation_samples": len(valid_idx),
        "test_samples": len(test_idx),
        "best_epoch": int(np.argmax(history.history["val_accuracy"]) + 1),
        "validation_accuracy": float(max(history.history["val_accuracy"])),
        "test_accuracy": float(report["accuracy"]),
        "macro_precision": float(report["macro avg"]["precision"]),
        "macro_recall": float(report["macro avg"]["recall"]),
        "classification_report": report,
        "label_order": [labels_by_index[i] for i in sorted(labels_by_index)],
        "confusion_matrix": matrix.tolist(),
    }
    model.save(args.output / "transactional_fsl_gru.keras")
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    tflite_model = converter.convert()
    (args.output / "transactional_fsl_gru.tflite").write_bytes(tflite_model)
    (args.output / "evaluation.json").write_text(json.dumps(evaluation, indent=2), encoding="utf-8")
    (args.output / "training_config.json").write_text(json.dumps({
        "architecture": "Masking -> GRU(96) -> Dropout -> GRU(64) -> Dense(64 relu) -> Dense(26 softmax)",
        "input_shape": list(x.shape[1:]),
        "normalization": "wrist-relative and wrist-to-middle-MCP scale from preprocess_fsl.py",
        "feature_order": "frame, left hand 21 xyz, right hand 21 xyz",
        "seed": args.seed,
        "epochs_requested": args.epochs,
        "batch_size": 32,
    }, indent=2), encoding="utf-8")
    print(json.dumps({k: evaluation[k] for k in ("train_samples", "validation_samples", "test_samples", "validation_accuracy", "test_accuracy", "macro_precision", "macro_recall")}, indent=2))


if __name__ == "__main__":
    main()
