"""Train a landmark-based sign classifier and export it to TensorFlow Lite.

Expected CSV format:

label,hand0_x0,hand0_y0,hand0_z0,...,hand1_x20,hand1_y20,hand1_z20
A,0.48,0.72,-0.01,...

Legacy one-hand CSV rows with 63 coordinates are also accepted and padded
with an empty second hand. Each hand uses the MediaPipe landmark order used by
the Flutter app.
"""

from __future__ import annotations

import argparse
import csv
import json
import math
import random
import re
from pathlib import Path


HAND_LANDMARK_VALUE_COUNT = 21 * 3
HAND_FEATURE_COUNT = HAND_LANDMARK_VALUE_COUNT + 2
LANDMARK_VALUE_COUNT = HAND_LANDMARK_VALUE_COUNT * 2
MODEL_FEATURE_COUNT = HAND_FEATURE_COUNT * 2
_ALPHABET_LABEL = re.compile(r"^[A-Z]$")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", required=True, help="Path to landmark CSV data.")
    parser.add_argument(
        "--out-dir",
        default="assets/ml",
        help="Output directory for .tflite, labels.txt, and metadata.",
    )
    parser.add_argument("--epochs", type=int, default=80)
    parser.add_argument("--batch-size", type=int, default=32)
    parser.add_argument("--validation-split", type=float, default=0.2)
    parser.add_argument("--seed", type=int, default=42)
    return parser.parse_args()


def normalize_hand(values: list[float]) -> list[float]:
    points = [
        values[i : i + 3]
        for i in range(0, HAND_LANDMARK_VALUE_COUNT, 3)
    ]
    wrist = points[0]
    centered = [
        [point[0] - wrist[0], point[1] - wrist[1], point[2] - wrist[2]]
        for point in points
    ]
    scale = max(
        max((x * x + y * y + z * z) ** 0.5 for x, y, z in centered),
        0.0001,
    )
    # Keep the wrist's position as well as its normalized shape. This lets
    # location-sensitive signs such as father/mother remain distinguishable.
    return [value / scale for point in centered for value in point] + [
        wrist[0],
        wrist[1],
    ]


def load_csv(csv_path: Path) -> tuple[list[list[float]], list[str]]:
    features: list[list[float]] = []
    labels: list[str] = []
    with csv_path.open("r", newline="", encoding="utf-8") as handle:
        reader = csv.reader(handle)
        first_row = next(reader, None)
        if first_row is None:
            raise ValueError("CSV file is empty.")

        has_header = first_row[0].strip().lower() == "label"
        rows = reader if has_header else [first_row, *reader]

        for row_number, row in enumerate(rows, start=2 if has_header else 1):
            if not row or not row[0].strip():
                continue
            label = row[0].strip()
            raw_values = [float(value) for value in row[1:]]
            if len(raw_values) == HAND_LANDMARK_VALUE_COUNT:
                first_hand = normalize_hand(raw_values)
                second_hand = [0.0] * HAND_FEATURE_COUNT
            elif len(raw_values) == LANDMARK_VALUE_COUNT:
                first_hand = normalize_hand(raw_values[:HAND_LANDMARK_VALUE_COUNT])
                second_hand = normalize_hand(raw_values[HAND_LANDMARK_VALUE_COUNT:])
            else:
                raise ValueError(
                    f"Row {row_number} has {len(raw_values)} values; "
                    f"expected {HAND_LANDMARK_VALUE_COUNT} (legacy) or "
                    f"{LANDMARK_VALUE_COUNT} (two hands)."
                )
            labels.append(label)
            features.append(first_hand + second_hand)

    if not features:
        raise ValueError("No training rows found.")
    return features, labels


def augment_tilted_word_samples(x, y, label_names):
    """Add modest in-plane hand rotations to word training samples only."""
    import numpy as np

    augmented_x = [x]
    augmented_y = [y]
    extra_count = 0
    for sample_index, (sample, label_index) in enumerate(zip(x, y)):
        label = label_names[int(label_index)]
        if _ALPHABET_LABEL.fullmatch(label) or label.isdigit():
            continue
        for _ in range(2):
            angle = math.radians(random.uniform(-25.0, 25.0))
            cosine, sine = math.cos(angle), math.sin(angle)
            rotated = sample.copy()
            for hand_offset in (0, HAND_FEATURE_COUNT):
                points = rotated[
                    hand_offset : hand_offset + HAND_LANDMARK_VALUE_COUNT
                ].reshape(21, 3)
                original_x = points[:, 0].copy()
                original_y = points[:, 1].copy()
                points[:, 0] = original_x * cosine - original_y * sine
                points[:, 1] = original_x * sine + original_y * cosine
            augmented_x.append(rotated.reshape(1, MODEL_FEATURE_COUNT))
            augmented_y.append(y[sample_index : sample_index + 1])
            extra_count += 1
    if extra_count == 0:
        return x, y, 0
    return (
        np.concatenate(augmented_x, axis=0),
        np.concatenate(augmented_y, axis=0),
        extra_count,
    )


def main() -> None:
    args = parse_args()

    import numpy as np
    import tensorflow as tf

    random.seed(args.seed)
    np.random.seed(args.seed)
    tf.random.set_seed(args.seed)

    csv_path = Path(args.csv)
    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    features, labels = load_csv(csv_path)
    label_names = sorted(set(labels))
    label_to_index = {label: index for index, label in enumerate(label_names)}

    x = np.asarray(features, dtype=np.float32)
    y = np.asarray([label_to_index[label] for label in labels], dtype=np.int64)

    # Split each label independently. A global random split can place all
    # samples for a small class in validation, leaving the model unable to
    # learn that sign at all.
    train_indices: list[int] = []
    validation_indices: list[int] = []
    for label_index in range(len(label_names)):
        label_indices = np.flatnonzero(y == label_index)
        np.random.shuffle(label_indices)
        validation_count = (
            max(1, int(len(label_indices) * args.validation_split))
            if len(label_indices) >= 5
            else 0
        )
        validation_indices.extend(label_indices[:validation_count])
        train_indices.extend(label_indices[validation_count:])

    np.random.shuffle(train_indices)
    np.random.shuffle(validation_indices)
    x_train = x[train_indices]
    y_train = y[train_indices]
    x_val = x[validation_indices]
    y_val = y[validation_indices]

    model = tf.keras.Sequential(
        [
            tf.keras.layers.Input(shape=(MODEL_FEATURE_COUNT,)),
            tf.keras.layers.Dense(128, activation="relu"),
            tf.keras.layers.Dropout(0.25),
            tf.keras.layers.Dense(64, activation="relu"),
            tf.keras.layers.Dropout(0.15),
            tf.keras.layers.Dense(len(label_names), activation="softmax"),
        ]
    )
    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=0.001),
        loss="sparse_categorical_crossentropy",
        metrics=["accuracy"],
    )

    callbacks = [
        tf.keras.callbacks.EarlyStopping(
            monitor="val_accuracy",
            patience=12,
            restore_best_weights=True,
        )
    ]
    class_counts = np.bincount(y_train, minlength=len(label_names))
    mean_class_count = float(np.mean(class_counts))
    class_weights = {
        index: min(2.0, float((mean_class_count / max(count, 1)) ** 0.5))
        for index, count in enumerate(class_counts)
    }
    original_x_train, original_y_train = x_train, y_train
    x_train, y_train, augmented_count = augment_tilted_word_samples(
        x_train, y_train, label_names
    )
    history = model.fit(
        x_train,
        y_train,
        validation_data=(x_val, y_val) if len(x_val) else None,
        class_weight=class_weights,
        epochs=args.epochs,
        batch_size=args.batch_size,
        callbacks=callbacks,
        verbose=2,
    )

    final_accuracy = float(
        model.evaluate(original_x_train, original_y_train, verbose=0)[1]
    )
    final_val_accuracy = (
        float(model.evaluate(x_val, y_val, verbose=0)[1]) if len(x_val) else 0.0
    )

    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    tflite_model = converter.convert()

    (out_dir / "sign_landmark_classifier.tflite").write_bytes(tflite_model)
    (out_dir / "labels.txt").write_text("\n".join(label_names) + "\n", encoding="utf-8")
    (out_dir / "training_metadata.json").write_text(
        json.dumps(
            {
                "labels": label_names,
                "samples": len(features),
                "train_samples": len(original_x_train),
                "augmented_training_samples": augmented_count,
                "effective_train_samples": len(x_train),
                "validation_samples": len(x_val),
                "final_accuracy": final_accuracy,
                "final_val_accuracy": final_val_accuracy,
                "input_features": MODEL_FEATURE_COUNT,
                "word_rotation_augmentation_degrees": [-25, 25],
                "class_weights": {
                    label_names[index]: weight
                    for index, weight in class_weights.items()
                },
            },
            indent=2,
        ),
        encoding="utf-8",
    )

    print(f"Wrote {out_dir / 'sign_landmark_classifier.tflite'}")
    print(f"Wrote {out_dir / 'labels.txt'}")


if __name__ == "__main__":
    main()
