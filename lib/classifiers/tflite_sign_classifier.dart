import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import 'sign_classifier.dart';

// ── How many frames the LSTM expects (must match train_sign_sequence_model.py)
const int kSequenceFrames = 30;
const int _kLandmarks = 21;

class TfliteSignClassifier {
  TfliteSignClassifier({
    this.modelAssetPath = 'assets/ml/sign_landmark_classifier.tflite',
    this.labelsAssetPath = 'assets/ml/labels.txt',
    this.sequenceModelAssetPath = 'assets/ml/sign_sequence_classifier.tflite',
    this.sequenceLabelsAssetPath = 'assets/ml/sequence_labels.txt',
    this.minimumConfidence = 0.78,
  });

  final String modelAssetPath;
  final String labelsAssetPath;
  final String sequenceModelAssetPath;
  final String sequenceLabelsAssetPath;
  final double minimumConfidence;

  // Static (dense) model
  Interpreter? _interpreter;
  List<String> _labels = const [];

  // Sequence (LSTM) model
  Interpreter? _seqInterpreter;
  List<String> _seqLabels = const [];

  // Rolling frame buffer fed by the camera pipeline
  final List<List<double>> _frameBuffer = [];

  bool get isReady => _interpreter != null && _labels.isNotEmpty;
  bool get isSequenceReady => _seqInterpreter != null && _seqLabels.isNotEmpty;

  // ── Load ──────────────────────────────────────────────────────────────────

  Future<void> load() async {
    await _loadStatic();
    await _loadSequence();
  }

  Future<void> _loadStatic() async {
    try {
      final labelsText = await rootBundle.loadString(labelsAssetPath);
      _labels = labelsText
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList(growable: false);
      final options = InterpreterOptions()..threads = 2;
      _interpreter =
          await Interpreter.fromAsset(modelAssetPath, options: options);
      _interpreter!.allocateTensors();
      debugPrint('TFLite static model loaded (${_labels.length} labels)');
    } catch (e) {
      _labels = const [];
      _interpreter?.close();
      _interpreter = null;
      debugPrint('TFLite static model disabled: $e');
    }
  }

  Future<void> _loadSequence() async {
    try {
      final labelsText = await rootBundle.loadString(sequenceLabelsAssetPath);
      _seqLabels = labelsText
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList(growable: false);
      final options = InterpreterOptions()..threads = 2;
      _seqInterpreter =
          await Interpreter.fromAsset(sequenceModelAssetPath, options: options);
      _seqInterpreter!.allocateTensors();
      debugPrint('TFLite sequence model loaded (${_seqLabels.length} labels)');
    } catch (e) {
      _seqLabels = const [];
      _seqInterpreter?.close();
      _seqInterpreter = null;
      debugPrint('TFLite sequence model disabled (not trained yet): $e');
    }
  }

  // ── Static classification ─────────────────────────────────────────────────

  SignResult? classifyAlphabet(List<HandLandmark> landmarks) =>
      _classify(landmarks, (l) => RegExp(r'^[A-Z]$').hasMatch(l), 'alphabet');

  SignResult? classifyNumber(List<HandLandmark> landmarks) =>
      _classify(landmarks, (l) => int.tryParse(l) != null, 'number');

  SignResult? classifyWordsFromHands(List<List<HandLandmark>>? hands) {
    if (hands == null || hands.isEmpty) return null;
    return _classify(
      hands.first,
      (l) => !RegExp(r'^[A-Z]$').hasMatch(l) && int.tryParse(l) == null,
      'word',
    );
  }

  SignResult? _classify(
    List<HandLandmark> landmarks,
    bool Function(String) acceptsLabel,
    String type,
  ) {
    final interpreter = _interpreter;
    if (interpreter == null || _labels.isEmpty || landmarks.length < 21) {
      return null;
    }

    final input = [_normalizeLandmarks(landmarks)];
    final outputShape = interpreter.getOutputTensor(0).shape;
    final outputCount =
        outputShape.isNotEmpty ? outputShape.last : _labels.length;
    final output = [List<double>.filled(outputCount, 0)];

    try {
      interpreter.run(input, output);
    } catch (e) {
      debugPrint('TFLite static inference failed: $e');
      return null;
    }

    var bestIndex = -1;
    var bestConf = 0.0;
    final limit = min(min(output[0].length, _labels.length), outputCount);
    for (var i = 0; i < limit; i++) {
      if (!acceptsLabel(_labels[i])) continue;
      if (output[0][i] > bestConf) {
        bestConf = output[0][i];
        bestIndex = i;
      }
    }

    if (bestIndex == -1 || bestConf < minimumConfidence) return null;
    return SignResult(
      label: _labels[bestIndex],
      confidence: bestConf,
      type: type,
      isModelConfidence: true,
    );
  }

  // ── Sequence / LSTM classification ────────────────────────────────────────

  /// Call this every frame from the camera pipeline (same cadence as static).
  /// Returns a [SignResult] once the buffer is full and a confident match is found,
  /// otherwise returns null.
  SignResult? pushFrameAndClassify(List<HandLandmark> landmarks) {
    if (!isSequenceReady) return null;

    // Append normalized frame to rolling buffer
    _frameBuffer.add(_normalizeLandmarks(landmarks));
    if (_frameBuffer.length > kSequenceFrames) {
      _frameBuffer.removeAt(0);
    }
    if (_frameBuffer.length < kSequenceFrames) return null;

    return _classifySequence();
  }

  /// Resets the frame buffer (e.g. when switching modes or on confirmed sign).
  void resetSequenceBuffer() => _frameBuffer.clear();

  SignResult? _classifySequence() {
    final interpreter = _seqInterpreter;
    if (interpreter == null || _seqLabels.isEmpty) return null;

    // Input shape: [1, kSequenceFrames, _kFeatures]
    final input = [_frameBuffer.map((f) => f).toList()];

    final outputShape = interpreter.getOutputTensor(0).shape;
    final outputCount =
        outputShape.isNotEmpty ? outputShape.last : _seqLabels.length;
    final output = [List<double>.filled(outputCount, 0)];

    try {
      interpreter.run(input, output);
    } catch (e) {
      debugPrint('TFLite sequence inference failed: $e');
      return null;
    }

    var bestIndex = -1;
    var bestConf = 0.0;
    final limit = min(output[0].length, _seqLabels.length);
    for (var i = 0; i < limit; i++) {
      if (output[0][i] > bestConf) {
        bestConf = output[0][i];
        bestIndex = i;
      }
    }

    if (bestIndex == -1 || bestConf < minimumConfidence) return null;
    return SignResult(
      label: _seqLabels[bestIndex],
      confidence: bestConf,
      type: 'sequence',
      isModelConfidence: true,
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  List<double> _normalizeLandmarks(List<HandLandmark> landmarks) {
    final wrist = landmarks[0];
    var scale = 0.0;
    for (final lm in landmarks.take(_kLandmarks)) {
      final dx = lm.x - wrist.x;
      final dy = lm.y - wrist.y;
      final dz = lm.z - wrist.z;
      scale = max(scale, sqrt(dx * dx + dy * dy + dz * dz));
    }
    scale = max(scale, 0.0001);

    final values = <double>[];
    for (final lm in landmarks.take(_kLandmarks)) {
      values.add((lm.x - wrist.x) / scale);
      values.add((lm.y - wrist.y) / scale);
      values.add((lm.z - wrist.z) / scale);
    }
    return values;
  }

  void close() {
    _interpreter?.close();
    _interpreter = null;
    _seqInterpreter?.close();
    _seqInterpreter = null;
  }
}
