"""
Auto-apply landscape support to TalkWithHands sign detection.

Run from the project root (C:\\Projects\\TalkwithHands):
    python patch_landscape.py

Edits (with .bak backups, safe to run twice):
  lib/screens/sign_detector_screen_mobile.dart
  lib/painters/landmark_painter.dart
"""
import os
import shutil
import sys

SCREEN = os.path.join("lib", "screens", "sign_detector_screen_mobile.dart")
PAINTER = os.path.join("lib", "painters", "landmark_painter.dart")


def load(path):
    with open(path, "r", encoding="utf-8", newline="") as f:
        return f.read()


def save(path, text):
    shutil.copyfile(path, path + ".bak")
    with open(path, "w", encoding="utf-8", newline="") as f:
        f.write(text)


class Patcher:
    def __init__(self, text):
        self.text = text
        self.nl = "\r\n" if "\r\n" in text else "\n"
        self.problems = []

    def fix(self, s):
        return s.replace("\r\n", "\n").replace("\n", self.nl)

    def replace(self, name, old, new, optional=False):
        old, new = self.fix(old), self.fix(new)
        n = self.text.count(old)
        if n == 1:
            self.text = self.text.replace(old, new)
            print(f"  ok   {name}")
        elif n == 0:
            if optional:
                print(f"  skip {name} (not present)")
            else:
                self.problems.append(name)
                print(f"  FAIL {name}: text not found")
        else:
            self.problems.append(name)
            print(f"  FAIL {name}: found {n} times")


# ───────────────────────── screen ─────────────────────────
def patch_screen():
    if not os.path.exists(SCREEN):
        sys.exit(f"Not found: {SCREEN}  (run this from the project root)")
    text = load(SCREEN)
    if "_uprightRotation" in text:
        print("Screen: already patched, skipping.")
        return True
    print("Screen:")
    p = Patcher(text)

    p.replace(
        "import services.dart",
        "import 'package:flutter/material.dart';\n",
        "import 'package:flutter/material.dart';\nimport 'package:flutter/services.dart';\n",
    )
    p.replace(
        "lock landscape in initState",
        "    super.initState();\n    _mode = widget.initialMode;\n",
        "    super.initState();\n"
        "    SystemChrome.setPreferredOrientations(const [\n"
        "      DeviceOrientation.landscapeLeft,\n"
        "      DeviceOrientation.landscapeRight,\n"
        "    ]);\n"
        "    _mode = widget.initialMode;\n",
    )
    p.replace(
        "restore portrait in dispose",
        "    WidgetsBinding.instance.removeObserver(this);\n    _startCountdownTimer?.cancel();\n",
        "    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);\n"
        "    WidgetsBinding.instance.removeObserver(this);\n    _startCountdownTimer?.cancel();\n",
    )
    p.replace(
        "display preview size + rotation helpers",
        "    return Size(previewSize.height, previewSize.width);\n  }\n",
        """    final rot = _uprightRotation;
    return (rot == 90 || rot == 270)
        ? Size(previewSize.height, previewSize.width)
        : previewSize;
  }

  /// Clockwise degrees that make the raw sensor frame upright right now.
  int get _uprightRotation {
    final c = _cameraController;
    if (c == null) return 270;
    const deg = {
      DeviceOrientation.portraitUp: 0,
      DeviceOrientation.landscapeLeft: 90,
      DeviceOrientation.portraitDown: 180,
      DeviceOrientation.landscapeRight: 270,
    };
    final dev = deg[c.value.deviceOrientation] ?? 0;
    final sensor = c.description.sensorOrientation;
    return c.description.lensDirection == CameraLensDirection.front
        ? (sensor + dev) % 360
        : (sensor - dev + 360) % 360;
  }

  /// Makes landscape landmarks look like the portrait ones the classifiers
  /// were built for (same hand size, re-centred). Identity in portrait.
  List<HandLandmark> _toPortraitRaw(List<HandLandmark> lm) {
    final rot = _uprightRotation;
    final raw = _rawPreviewSize;
    if (rot == 270 || raw == null) return lm;
    final rw = raw.width, rh = raw.height;
    final swap = rot == 90 || rot == 270;
    final w = swap ? rh : rw;
    final h = swap ? rw : rh;
    final cw = math.min(rw, rh), ch = math.max(rw, rh);
    return lm.map((p) {
      double ux, uy;
      switch (rot) {
        case 90:
          ux = 1 - p.y;
          uy = p.x;
          break;
        case 180:
          ux = 1 - p.x;
          uy = 1 - p.y;
          break;
        default:
          ux = p.x;
          uy = p.y;
      }
      final cx = 0.5 + (ux * w - w / 2) / cw;
      final cy = 0.5 + (uy * h - h / 2) / ch;
      return HandLandmark(1 - cy, cx, p.z);
    }).toList(growable: false);
  }
""",
    )
    p.replace(
        "classify uses portrait-equivalent landmarks",
        "  Future<SignResult?> _classifyCurrentFrame(\n"
        "    List<HandLandmark> primaryHandLandmarks,\n"
        "    List<List<HandLandmark>>? handsLandmarks,\n"
        "  ) async {\n",
        "  Future<SignResult?> _classifyCurrentFrame(\n"
        "    List<HandLandmark> rawPrimary,\n"
        "    List<List<HandLandmark>>? rawHands,\n"
        "  ) async {\n"
        "    final primaryHandLandmarks = _toPortraitRaw(rawPrimary);\n"
        "    final handsLandmarks =\n"
        "        rawHands?.map(_toPortraitRaw).toList(growable: false);\n",
    )
    p.replace(
        "painter gets the live rotation",
        "                      sensorOrientation:\n"
        "                          controller.description.sensorOrientation,\n",
        "                      sensorOrientation:\n"
        "                          controller.description.sensorOrientation,\n"
        "                      rotationDegrees: _uprightRotation,\n",
    )
    # Only present if the face-zone edits were already applied:
    p.replace(
        "face zones use raw landmarks",
        "_faceZones.observeHand(primaryHandLandmarks);",
        "_faceZones.observeHand(rawPrimary);",
        optional=True,
    )
    p.replace(
        "face zones use live rotation",
        "_faceZones.maybeUpdate(image, sensorOrientation)",
        "_faceZones.maybeUpdate(image, _uprightRotation)",
        optional=True,
    )

    if p.problems:
        print("Screen NOT saved (nothing was changed):", ", ".join(p.problems))
        return False
    save(SCREEN, p.text)
    print("Screen saved (backup: .bak)")
    return True


# ───────────────────────── painter ─────────────────────────
def patch_painter():
    if not os.path.exists(PAINTER):
        sys.exit(f"Not found: {PAINTER}")
    text = load(PAINTER)
    if "rotationDegrees" in text:
        print("Painter: already patched, skipping.")
        return True
    print("Painter:")
    p = Patcher(text)
    p.replace(
        "rotationDegrees field",
        "  final int sensorOrientation;\n\n  const LandmarkPainter({",
        "  final int sensorOrientation;\n\n"
        "  /// Clockwise degrees to turn the raw sensor frame upright right now.\n"
        "  final int? rotationDegrees;\n\n"
        "  const LandmarkPainter({",
    )
    p.replace(
        "constructor param",
        "    this.sensorOrientation = 0,\n  });",
        "    this.sensorOrientation = 0,\n    this.rotationDegrees,\n  });",
    )
    p.replace(
        "scale uses rotation",
        "    final raw = _rawPreviewSize;\n"
        "    // Scale to fit the rotated preview into the widget\n"
        "    final scale = size.width / raw.height;",
        "    final raw = _rawPreviewSize;\n"
        "    final rot = rotationDegrees ?? sensorOrientation;\n"
        "    // Scale to fit the rotated preview into the widget\n"
        "    final swap = rot == 90 || rot == 270;\n"
        "    final scale = size.width / (swap ? raw.height : raw.width);",
    )
    p.replace(
        "canvas rotate",
        "    canvas.rotate(sensorOrientation * math.pi / 180);",
        "    canvas.rotate(rot * math.pi / 180);",
    )
    p.replace(
        "shouldRepaint",
        "        old.sensorOrientation != sensorOrientation) {",
        "        old.sensorOrientation != sensorOrientation ||\n"
        "        old.rotationDegrees != rotationDegrees) {",
    )
    if p.problems:
        print("Painter NOT saved:", ", ".join(p.problems))
        return False
    save(PAINTER, p.text)
    print("Painter saved (backup: .bak)")
    return True


if __name__ == "__main__":
    ok_painter = patch_painter()
    ok_screen = patch_screen()
    if ok_painter and ok_screen:
        print("\nDone. Next: check AndroidManifest.xml has no "
              'android:screenOrientation="portrait", then run the app.')
    else:
        print("\nSome edits failed. Nothing broken was written; "
              "send me the FAIL lines above.")
        sys.exit(1)
