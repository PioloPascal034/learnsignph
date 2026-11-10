"""Compare an RBF SVM and a small MLP, exporting the MLP to TFLite."""

from __future__ import annotations

import argparse
import json
import random
from pathlib import Path

import joblib
import numpy as np
import tensorflow as tf
from sklearn.metrics import classification_report, confusion_matrix
from sklearn.svm import SVC


def metrics(y_true: np.ndarray, y_pred: np.ndarray, labels: list[str]) -> dict:
    report = classification_report(y_true, y_pred, labels=range(len(labels)),
                                   target_names=labels, output_dict=True,
                                   zero_division=0)
    return {
        "accuracy": float(report["accuracy"]),
        "macro_precision": float(report["macro avg"]["precision"]),
        "macro_recall": float(report["macro avg"]["recall"]),
        "macro_f1": float(report["macro avg"]["f1-score"]),
        "classification_report": report,
        "confusion_matrix": confusion_matrix(y_true, y_pred,
                                              labels=range(len(labels))).tolist(),
    }


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

    x = np.load(args.dataset / "features.npy").astype(np.float32)
    y = np.load(args.dataset / "labels.npy").astype(np.int64)
    label_map = json.loads((args.dataset / "label_map.json").read_text(encoding="utf-8"))
    labels = [label for label, _ in sorted(label_map.items(), key=lambda item: item[1])]
    splits = json.loads((args.dataset / "splits.json").read_text(encoding="utf-8"))
    train_idx = np.asarray(splits["train"], dtype=np.int64)
    validation_idx = np.asarray(splits["validation"], dtype=np.int64)
    test_idx = np.asarray(splits["test"], dtype=np.int64)

    svm = SVC(C=10.0, kernel="rbf", gamma="scale", probability=True,
              cache_size=2048, random_state=args.seed)
    svm.fit(x[train_idx], y[train_idx])
    svm_validation = svm.predict(x[validation_idx])
    svm_test = svm.predict(x[test_idx])
    joblib.dump(svm, args.output / "alphabet_svm.joblib")

    model = tf.keras.Sequential([
        tf.keras.layers.Input(shape=(63,)),
        tf.keras.layers.Dense(128, activation="relu"),
        tf.keras.layers.Dropout(0.25),
        tf.keras.layers.Dense(64, activation="relu"),
        tf.keras.layers.Dropout(0.20),
        tf.keras.layers.Dense(len(labels), activation="softmax"),
    ])
    model.compile(optimizer=tf.keras.optimizers.Adam(learning_rate=1e-3),
                  loss="sparse_categorical_crossentropy", metrics=["accuracy"])
    history = model.fit(
        x[train_idx], y[train_idx],
        validation_data=(x[validation_idx], y[validation_idx]),
        epochs=args.epochs,
        batch_size=64,
        callbacks=[
            tf.keras.callbacks.EarlyStopping(monitor="val_accuracy", patience=12,
                                             restore_best_weights=True),
            tf.keras.callbacks.ReduceLROnPlateau(monitor="val_loss", factor=0.5,
                                                  patience=5, min_lr=1e-5),
        ],
        verbose=2,
    )
    mlp_validation = model.predict(x[validation_idx], verbose=0).argmax(axis=1)
    mlp_test = model.predict(x[test_idx], verbose=0).argmax(axis=1)
    model.save(args.output / "alphabet_mlp.keras")
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    (args.output / "alphabet_mlp.tflite").write_bytes(converter.convert())

    results = {
        "seed": args.seed,
        "input_shape": [1, 63],
        "output_shape": [1, len(labels)],
        "train_samples": len(train_idx),
        "validation_samples": len(validation_idx),
        "test_samples": len(test_idx),
        "best_mlp_epoch": int(np.argmax(history.history["val_accuracy"]) + 1),
        "svm": {
            "validation": metrics(y[validation_idx], svm_validation, labels),
            "test": metrics(y[test_idx], svm_test, labels),
        },
        "mlp": {
            "validation": metrics(y[validation_idx], mlp_validation, labels),
            "test": metrics(y[test_idx], mlp_test, labels),
        },
        "label_order": labels,
        "participant_independent": False,
        "limitations": "The source contains no participant IDs; source-group splits prevent augmentation leakage where filename grouping is available but do not establish signer-independent accuracy.",
    }
    (args.output / "evaluation.json").write_text(json.dumps(results, indent=2), encoding="utf-8")
    (args.output / "label_map.json").write_text(json.dumps(label_map, indent=2), encoding="utf-8")
    (args.output / "inference_config.json").write_text(json.dumps({
        "model": "alphabet_mlp.tflite",
        "input_shape": [1, 63],
        "landmark_order": "MediaPipe Hand Landmarker 0..20, xyz",
        "normalization": "wrist-relative; divide by wrist-to-middle-MCP distance; fallback to maximum radius",
        "handedness": "Canonicalize Left by negating normalized x; Right unchanged",
        "static_labels": labels,
        "dynamic_labels": ["J", "Z"],
        "unknown_threshold": 0.65,
    }, indent=2), encoding="utf-8")
    print(json.dumps({
        "svm_validation_accuracy": results["svm"]["validation"]["accuracy"],
        "svm_test_accuracy": results["svm"]["test"]["accuracy"],
        "mlp_validation_accuracy": results["mlp"]["validation"]["accuracy"],
        "mlp_test_accuracy": results["mlp"]["test"]["accuracy"],
    }, indent=2))


if __name__ == "__main__":
    main()
