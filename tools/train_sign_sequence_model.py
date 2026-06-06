"""
Train an LSTM model for dynamic/motion ASL signs.

Input:  data/sign_sequences.csv
        Each row: label, then 30 frames × 21 landmarks × 3 coords = 1890 values

Output: assets/ml/sign_sequence_classifier.tflite
        assets/ml/sequence_labels.txt

Usage:
    pip install -r tools/requirements-tflite.txt
    python tools/train_sign_sequence_model.py --csv data/sign_sequences.csv
"""

import argparse
import os
import numpy as np
import pandas as pd

def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument('--csv',     default='data/sign_sequences.csv')
    p.add_argument('--out_dir', default='assets/ml')
    p.add_argument('--frames',  type=int, default=30)
    p.add_argument('--epochs',  type=int, default=80)
    p.add_argument('--batch',   type=int, default=32)
    return p.parse_args()

LANDMARKS = 21
COORDS    = 3  # x, y, z

def normalize_sequence(seq):
    """
    Wrist-relative normalization applied frame-by-frame.
    seq: (frames, 63) float array
    returns: same shape, normalized
    """
    out = np.empty_like(seq)
    for f in range(seq.shape[0]):
        frame = seq[f].reshape(LANDMARKS, COORDS)
        wrist = frame[0].copy()
        frame -= wrist
        scale = np.max(np.linalg.norm(frame, axis=1))
        if scale < 1e-4:
            scale = 1e-4
        frame /= scale
        out[f] = frame.flatten()
    return out

def main():
    args = parse_args()

    # ── Load CSV ──────────────────────────────────────────────────────────────
    print(f'Loading {args.csv} …')
    df = pd.read_csv(args.csv)

    expected_cols = 1 + args.frames * LANDMARKS * COORDS   # label + values
    if df.shape[1] != expected_cols:
        raise ValueError(
            f'Expected {expected_cols} columns (label + {args.frames} frames × '
            f'{LANDMARKS} landmarks × {COORDS} coords), got {df.shape[1]}.'
        )

    labels_col = df.iloc[:, 0].astype(str).str.strip()
    values     = df.iloc[:, 1:].values.astype(np.float32)

    # ── Labels ────────────────────────────────────────────────────────────────
    label_names = sorted(labels_col.unique().tolist())
    label_to_idx = {lbl: i for i, lbl in enumerate(label_names)}
    y = np.array([label_to_idx[l] for l in labels_col], dtype=np.int32)

    print(f'Labels ({len(label_names)}): {label_names}')
    print(f'Samples: {len(y)}')
    for lbl in label_names:
        print(f'  {lbl}: {(labels_col == lbl).sum()}')

    # ── Normalize + reshape → (samples, frames, 63) ───────────────────────────
    n_features = LANDMARKS * COORDS  # 63
    X = values.reshape(-1, args.frames, n_features)
    X_norm = np.array([normalize_sequence(seq) for seq in X], dtype=np.float32)

    # ── Train/val split ───────────────────────────────────────────────────────
    import tensorflow as tf
    from sklearn.model_selection import train_test_split

    # Works with any number of samples — no minimum required
    n_samples = len(y)
    if n_samples < 10:
        # Too few — use all for training, skip validation
        X_train, X_val, y_train, y_val = X_norm, X_norm, y, y
        print(f'Warning: Only {n_samples} samples — skipping validation split.')
    else:
        test_size = 0.2 if n_samples < 50 else 0.15
        try:
            X_train, X_val, y_train, y_val = train_test_split(
                X_norm, y, test_size=test_size, random_state=42, stratify=y
            )
        except ValueError:
            # stratify fails if any class has only 1 sample
            X_train, X_val, y_train, y_val = train_test_split(
                X_norm, y, test_size=test_size, random_state=42
            )
            print('Warning: stratify skipped — some labels have too few samples.')

    n_classes = len(label_names)

    # ── Model ─────────────────────────────────────────────────────────────────
    model = tf.keras.Sequential([
        tf.keras.layers.Input(shape=(args.frames, n_features)),
        tf.keras.layers.LSTM(128, return_sequences=True),
        tf.keras.layers.Dropout(0.3),
        tf.keras.layers.LSTM(64),
        tf.keras.layers.Dropout(0.3),
        tf.keras.layers.Dense(64, activation='relu'),
        tf.keras.layers.Dense(n_classes, activation='softmax'),
    ])

    model.compile(
        optimizer=tf.keras.optimizers.Adam(1e-3),
        loss='sparse_categorical_crossentropy',
        metrics=['accuracy'],
    )
    model.summary()

    callbacks = [
        tf.keras.callbacks.EarlyStopping(patience=12, restore_best_weights=True),
        tf.keras.callbacks.ReduceLROnPlateau(patience=6, factor=0.5, min_lr=1e-5),
    ]

    model.fit(
        X_train, y_train,
        validation_data=(X_val, y_val),
        epochs=args.epochs,
        batch_size=args.batch,
        callbacks=callbacks,
    )

    val_loss, val_acc = model.evaluate(X_val, y_val, verbose=0)
    print(f'\nVal accuracy: {val_acc:.3f}')

    # ── Convert to TFLite ─────────────────────────────────────────────────────
    os.makedirs(args.out_dir, exist_ok=True)

    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    converter.target_spec.supported_ops = [
        tf.lite.OpsSet.TFLITE_BUILTINS,
        tf.lite.OpsSet.SELECT_TF_OPS,
    ]
    converter._experimental_lower_tensor_list_ops = False
    tflite_model = converter.convert()

    tflite_path = os.path.join(args.out_dir, 'sign_sequence_classifier.tflite')
    with open(tflite_path, 'wb') as f:
        f.write(tflite_model)
    print(f'Saved TFLite model → {tflite_path}')

    labels_path = os.path.join(args.out_dir, 'sequence_labels.txt')
    with open(labels_path, 'w') as f:
        f.write('\n'.join(label_names))
    print(f'Saved labels       → {labels_path}')
    print('\nDone! Now run: flutter pub get && flutter run')

if __name__ == '__main__':
    main()