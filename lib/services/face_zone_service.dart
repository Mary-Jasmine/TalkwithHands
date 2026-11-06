import 'dart:collection';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../classifiers/sign_classifier.dart' show HandLandmark;

/// Where the signing hand is relative to the face.
enum FaceZone { none, forehead, eyes, nose, mouth, chin, side, below, away }

// ── Face-placement table (EDIT THIS to match the signs in your app) ─────────
// Key = sequence-model label (lowercase). Value = zones where that sign is
// made. Defaults below follow ASL (father = thumb at forehead, mother =
// thumb at chin). Check against how YOUR app teaches them (FSL may differ).
const Map<String, Set<FaceZone>> kFaceSignZones = {
  'father': {FaceZone.forehead, FaceZone.eyes},
  'grandfather': {FaceZone.forehead, FaceZone.eyes},
  'mother': {FaceZone.mouth, FaceZone.chin},
  'grandmother': {FaceZone.mouth, FaceZone.chin},
};

// Signs that share the same hand shape and differ only by face placement.
const Map<String, String> kFaceSignTwins = {
  'father': 'mother',
  'mother': 'father',
  'grandfather': 'grandmother',
  'grandmother': 'grandfather',
};

// These family signs use the thumb tip as their face contact point.
const Map<String, int> kFaceSignContactLandmarks = {
  'father': 4,
  'mother': 4,
  'grandfather': 4,
  'grandmother': 4,
};

/// Returns a face-dependent label only when the hand is in the trained zone.
/// A missing face or a hand outside the required zone is not a match.
String? correctFaceSignLabel(String label, FaceZone zone) {
  final key = label.toLowerCase();
  final expected = kFaceSignZones[key];
  if (expected == null) return label;
  if (zone == FaceZone.none || zone == FaceZone.away) return null;
  if (expected.contains(zone)) return label;
  final twin = kFaceSignTwins[key];
  if (twin != null && (kFaceSignZones[twin]?.contains(zone) ?? false)) {
    return label.replaceRange(0, 1, twin[0].toUpperCase());
  }
  return null;
}

class _FaceGeometry {
  _FaceGeometry({
    required this.box,
    required this.eyeY,
    required this.mouthY,
    required this.centerX,
    required this.imageSize,
    required this.seenAt,
  });

  final Rect box; // upright-image pixels
  final double eyeY;
  final double mouthY;
  final double centerX;
  final Size imageSize; // upright-image size in pixels
  final DateTime seenAt;

  /// eye-line -> mouth distance, the "unit" used for the zone bands.
  double get d => math.max(mouthY - eyeY, box.height * 0.2);
}

/// Face detection (ML Kit) + hand-vs-face zone. Android only; every call is
/// cheap/no-op when it should not run.
class FaceZoneService {
  FaceZoneService({
    this.minInterval = const Duration(milliseconds: 120),
    this.staleAfter = const Duration(milliseconds: 2500),
  });

  final Duration minInterval;
  final Duration staleAfter;

  FaceDetector? _detector;
  _FaceGeometry? _face;
  int _rotationDeg = 0;
  bool _busy = false;
  DateTime _lastRun = DateTime.fromMillisecondsSinceEpoch(0);
  final Queue<FaceZone> _history = Queue<FaceZone>();
  final Map<int, Queue<FaceZone>> _fingerHistory = {
    for (final index in [4, 8, 12, 16, 20]) index: Queue<FaceZone>(),
  };

  // ── Debug info (drawn by FaceDebugPainter) ───────────────────────────────
  String debugStatus = 'face: not run yet';
  Offset? debugFinger; // upright-image pixels
  Rect? get debugFaceBox => _face?.box;
  Size? get debugImageSize => _face?.imageSize;
  bool get faceFresh =>
      _face != null && DateTime.now().difference(_face!.seenAt) <= staleAfter;

  /// Face geometry normalized to the upright, unmirrored camera frame:
  /// left, top, width, height, eye line, mouth line, and nose-center x.
  List<double>? get normalizedFaceFeatures {
    final face = _face;
    if (face == null || !faceFresh) return null;
    final width = face.imageSize.width;
    final height = face.imageSize.height;
    if (width <= 0 || height <= 0) return null;
    return [
      face.box.left / width,
      face.box.top / height,
      face.box.width / width,
      face.box.height / height,
      face.eyeY / height,
      face.mouthY / height,
      face.centerX / width,
    ];
  }

  /// Smoothed zone of the hand over the last few frames.
  FaceZone get currentZone => _stableZone(_history);

  FaceZone zoneForSign(String label) {
    final landmarkIndex = kFaceSignContactLandmarks[label.toLowerCase()];
    if (landmarkIndex == null) return currentZone;
    return _stableZone(_fingerHistory[landmarkIndex] ?? const <FaceZone>[]);
  }

  FaceZone _stableZone(Iterable<FaceZone> zones) {
    final counts = <FaceZone, int>{};
    final recent = zones.toList(growable: false).reversed.take(3);
    var known = 0;
    for (final z in recent) {
      if (z == FaceZone.none) continue;
      known++;
      counts[z] = (counts[z] ?? 0) + 1;
    }
    if (known < 2) return FaceZone.none;
    final best = counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return best.value >= 2 ? best.key : FaceZone.none;
  }

  // ── Face detection (throttled, non-blocking) ──────────────────────────────

  Future<void> maybeUpdate(CameraImage image, int sensorOrientation) async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      debugStatus = 'face: Android only';
      return;
    }
    if (image.planes.length < 3) {
      debugStatus = 'face: need 3 planes, got ${image.planes.length}';
      return;
    }
    if (_busy) return;
    final now = DateTime.now();
    if (now.difference(_lastRun) < minInterval) return;
    _busy = true;
    _lastRun = now;
    try {
      final rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
      if (rotation == null) return;
      _detector ??= FaceDetector(
        options: FaceDetectorOptions(
          performanceMode: FaceDetectorMode.fast,
          enableLandmarks: true,
          enableContours: false,
          enableClassification: false,
          minFaceSize: 0.10,
        ),
      );
      final nv21 = _yuv420ToNv21(image); // done before the first await
      final input = InputImage.fromBytes(
        bytes: nv21,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: image.width,
        ),
      );
      final faces = await _detector!.processImage(input);
      if (faces.isEmpty) {
        debugStatus = 'face: 0 faces';
        return; // keep last geometry until it goes stale
      }

      final face = faces.reduce((a, b) =>
          a.boundingBox.width * a.boundingBox.height >=
                  b.boundingBox.width * b.boundingBox.height
              ? a
              : b);
      final box = face.boundingBox;

      double? ly(FaceLandmarkType t) =>
          face.landmarks[t]?.position.y.toDouble();
      double? lx(FaceLandmarkType t) =>
          face.landmarks[t]?.position.x.toDouble();
      double avg(List<double?> v, double fallback) {
        final k = v.whereType<double>().toList();
        return k.isEmpty ? fallback : k.reduce((a, b) => a + b) / k.length;
      }

      final eyeY = avg([
        ly(FaceLandmarkType.leftEye),
        ly(FaceLandmarkType.rightEye),
      ], box.top + box.height * 0.38);
      final mouthY = avg([
        ly(FaceLandmarkType.bottomMouth),
        ly(FaceLandmarkType.leftMouth),
        ly(FaceLandmarkType.rightMouth),
      ], box.top + box.height * 0.78);
      final centerX = lx(FaceLandmarkType.noseBase) ?? box.center.dx;

      final swap = sensorOrientation == 90 || sensorOrientation == 270;
      _rotationDeg = sensorOrientation;
      _face = _FaceGeometry(
        box: box,
        eyeY: eyeY,
        mouthY: mouthY,
        centerX: centerX,
        imageSize: swap
            ? Size(image.height.toDouble(), image.width.toDouble())
            : Size(image.width.toDouble(), image.height.toDouble()),
        seenAt: DateTime.now(),
      );
      debugStatus = 'face: OK (${faces.length})';
    } catch (e) {
      debugStatus = 'face ERROR: $e';
      debugPrint('Face detection skipped: $e');
    } finally {
      _busy = false;
    }
  }

  // ── Hand vs face ──────────────────────────────────────────────────────────

  /// Call once per classified frame (cheap).
  void observeHand(List<HandLandmark> lm) {
    _history.addLast(_zoneOf(lm));
    while (_history.length > 8) {
      _history.removeFirst();
    }
    for (final entry in _fingerHistory.entries) {
      entry.value.addLast(_zoneAtLandmark(lm, entry.key));
      while (entry.value.length > 8) {
        entry.value.removeFirst();
      }
    }
  }

  void reset() {
    _history.clear();
    for (final history in _fingerHistory.values) {
      history.clear();
    }
  }

  FaceZone _zoneAtLandmark(List<HandLandmark> lm, int index) {
    final g = _face;
    if (g == null || lm.length < 21) return FaceZone.none;
    if (DateTime.now().difference(g.seenAt) > staleAfter) {
      return FaceZone.none;
    }
    final n = _toUpright(lm[index].x, lm[index].y, _rotationDeg);
    return _classifyPoint(
      Offset(n.dx * g.imageSize.width, n.dy * g.imageSize.height),
      g,
    );
  }

  FaceZone _zoneOf(List<HandLandmark> lm) {
    final g = _face;
    if (g == null || lm.length < 21) return FaceZone.none;
    if (DateTime.now().difference(g.seenAt) > staleAfter) return FaceZone.none;

    // The fingertip closest to the face is the one that touches it.
    Offset? best;
    var bestDist = double.infinity;
    for (final i in const [4, 8, 12, 16, 20]) {
      final n = _toUpright(lm[i].x, lm[i].y, _rotationDeg);
      final p = Offset(n.dx * g.imageSize.width, n.dy * g.imageSize.height);
      final dist = (p - g.box.center).distance;
      if (dist < bestDist) {
        bestDist = dist;
        best = p;
      }
    }
    debugFinger = best;
    return _classifyPoint(best!, g);
  }

  FaceZone _classifyPoint(Offset p, _FaceGeometry g) {
    final d = g.d;
    final dx = (p.dx - g.centerX).abs();
    final y = p.dy;
    final faceW = g.box.width;

    if (dx > faceW * 1.1) return FaceZone.away;

    final foreheadEnd = g.eyeY - 0.30 * d;
    final eyesEnd = g.eyeY + 0.25 * d;
    final noseEnd = g.eyeY + 0.70 * d;
    final mouthEnd = g.mouthY + 0.35 * d;
    final chinEnd = g.mouthY + 0.95 * d;

    if (y < foreheadEnd) {
      return y < foreheadEnd - 1.2 * d ? FaceZone.away : FaceZone.forehead;
    }
    if (y >= chinEnd) {
      return y > chinEnd + 2.5 * d ? FaceZone.away : FaceZone.below;
    }
    if (dx > faceW * 0.42 && y < mouthEnd) return FaceZone.side;
    if (y < eyesEnd) return FaceZone.eyes;
    if (y < noseEnd) return FaceZone.nose;
    if (y < mouthEnd) return FaceZone.mouth;
    return FaceZone.chin;
  }

  /// Raw (sensor-frame) normalized point -> upright, UNMIRRORED frame.
  /// Matches the verified correction in TfliteSignClassifier for 270°
  /// (x' = y, y' = 1 - x). Same frame ML Kit reports faces in when given
  /// the sensor rotation.
  static Offset _toUpright(double x, double y, int rotationDeg) {
    switch (rotationDeg) {
      case 90:
        return Offset(1 - y, x);
      case 180:
        return Offset(1 - x, 1 - y);
      case 270:
        return Offset(y, 1 - x);
      default:
        return Offset(x, y);
    }
  }

  static Offset toUprightPoint(double x, double y, int rotationDeg) =>
      _toUpright(x, y, rotationDeg);

  // ── YUV420 (3 planes) -> NV21 for ML Kit ──────────────────────────────────

  static Uint8List _yuv420ToNv21(CameraImage image) {
    final w = image.width;
    final h = image.height;
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];
    final out = Uint8List(w * h + (w * h) ~/ 2);

    var idx = 0;
    for (var row = 0; row < h; row++) {
      final start = row * yPlane.bytesPerRow;
      out.setRange(idx, idx + w, yPlane.bytes, start);
      idx += w;
    }

    final uvRowStride = uPlane.bytesPerRow;
    final uvPixelStride = uPlane.bytesPerPixel ?? 1;
    for (var row = 0; row < h ~/ 2; row++) {
      for (var col = 0; col < w ~/ 2; col++) {
        final uvIndex = row * uvRowStride + col * uvPixelStride;
        out[idx++] = vPlane.bytes[uvIndex];
        out[idx++] = uPlane.bytes[uvIndex];
      }
    }
    return out;
  }

  Future<void> dispose() async {
    await _detector?.close();
    _detector = null;
    _face = null;
    reset();
  }
}

/// Debug overlay: face box, nearest fingertip and current zone.
/// Put it in the same Stack as the camera preview (same size as the
/// upright display preview).
class FaceDebugPainter extends CustomPainter {
  FaceDebugPainter({required this.service, required this.mirror});

  final FaceZoneService service;
  final bool mirror; // true for the front camera

  @override
  void paint(Canvas canvas, Size size) {
    final img = service.debugImageSize;
    final box = service.debugFaceBox;
    Offset map(Offset p) {
      var x = p.dx / img!.width * size.width;
      if (mirror) x = size.width - x;
      return Offset(x, p.dy / img.height * size.height);
    }

    if (img != null && box != null && service.faceFresh) {
      final a = map(box.topLeft);
      final b = map(box.bottomRight);
      canvas.drawRect(
        Rect.fromPoints(a, b),
        Paint()
          ..color = const Color(0xFFFFC107)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant FaceDebugPainter old) => true;
}
