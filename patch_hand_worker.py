"""
Move hand detection off the UI thread (background isolate) with an automatic
fallback to the old main-isolate detection if the worker can't start.

1. Put hand_landmark_worker.dart (the new one) in lib/classifiers/
2. From the project root:   python patch_hand_worker.py
"""
import os
import shutil
import sys

SCREEN = os.path.join("lib", "screens", "sign_detector_screen_mobile.dart")
WORKER = os.path.join("lib", "classifiers", "hand_landmark_worker.dart")
if not os.path.exists(SCREEN):
    sys.exit(f"Not found: {SCREEN}  (run this from the project root)")
if not os.path.exists(WORKER):
    sys.exit(f"Not found: {WORKER}  (copy the new hand_landmark_worker.dart there first)")
with open(WORKER, "r", encoding="utf-8") as f:
    if "_InitError" not in f.read():
        sys.exit("lib/classifiers/hand_landmark_worker.dart is the OLD file. "
                 "Replace it with the new one first.")

with open(SCREEN, "r", encoding="utf-8", newline="") as f:
    text = f.read()
if "_handWorker" in text:
    sys.exit("Already patched, nothing to do.")

nl = "\r\n" if "\r\n" in text else "\n"
problems = []


def fix(s):
    return s.replace("\r\n", "\n").replace("\n", nl)


def replace(name, old, new):
    global text
    old, new = fix(old), fix(new)
    n = text.count(old)
    if n == 1:
        text = text.replace(old, new)
        print(f"  ok   {name}")
    else:
        problems.append(name)
        print(f"  FAIL {name}: found {n} times")


replace(
    "import worker",
    "import '../classifiers/sign_classifier.dart';\n",
    "import '../classifiers/hand_landmark_worker.dart';\n"
    "import '../classifiers/sign_classifier.dart';\n",
)

replace(
    "worker field",
    "  List<List<HandLandmark>>? _smoothedHandsLandmarks;\n",
    "  List<List<HandLandmark>>? _smoothedHandsLandmarks;\n"
    "  HandLandmarkWorker? _handWorker;\n",
)

replace(
    "start tracker (worker first, main isolate as fallback)",
    "    _handLandmarker = mp_hand.HandLandmarkerPlugin.create(\n"
    "      numHands: 2,\n"
    "      minHandDetectionConfidence: 0.55,\n"
    "      // GPU is the faster path for this plugin on supported Android devices.\n"
    "      delegate: mp_hand.HandLandmarkerDelegate.gpu,\n"
    "    );\n",
    "    await _startHandTracker();\n",
)

replace(
    "tracker helper methods",
    "  Future<void> _requestCameraPermission() async {\n",
    """  Future<void> _startHandTracker() async {
    try {
      final worker = HandLandmarkWorker();
      await worker.start(
        numHands: 2,
        minHandDetectionConfidence: 0.55,
        delegate: mp_hand.HandLandmarkerDelegate.gpu,
      );
      _handWorker = worker;
      debugPrint('Hand tracker: running on a background isolate');
    } catch (e) {
      debugPrint('Hand worker unavailable ($e) - using main isolate');
      _useMainIsolateTracker();
    }
  }

  void _useMainIsolateTracker() {
    _handWorker?.dispose();
    _handWorker = null;
    _handLandmarker ??= mp_hand.HandLandmarkerPlugin.create(
      numHands: 2,
      minHandDetectionConfidence: 0.55,
      // GPU is the faster path for this plugin on supported Android devices.
      delegate: mp_hand.HandLandmarkerDelegate.gpu,
    );
  }

  Future<List<List<HandLandmark>>> _detectViaWorker(
    HandLandmarkWorker worker,
    CameraImage image,
    int sensorOrientation,
  ) async {
    try {
      final hands = await worker.detect(image, sensorOrientation);
      return hands.map((flat) {
        final landmarks = <HandLandmark>[];
        for (var i = 0; i + 2 < flat.length; i += 3) {
          landmarks.add(HandLandmark(flat[i], flat[i + 1], flat[i + 2]));
        }
        return landmarks;
      }).toList(growable: false);
    } catch (e) {
      debugPrint('Hand worker failed ($e) - switching to main isolate');
      _useMainIsolateTracker();
      return const [];
    }
  }

  Future<void> _requestCameraPermission() async {
""",
)

replace(
    "detect via worker, else main isolate",
    "          final handLandmarker = _handLandmarker;\n"
    "          if (handLandmarker == null) return;\n"
    "          final detectedHands = handLandmarker.detect(image, sensorOrientation);\n",
    "          final worker = _handWorker;\n"
    "          final List<List<HandLandmark>> detectedHands;\n"
    "          if (worker != null) {\n"
    "            detectedHands =\n"
    "                await _detectViaWorker(worker, image, sensorOrientation);\n"
    "          } else {\n"
    "            final handLandmarker = _handLandmarker;\n"
    "            if (handLandmarker == null) return;\n"
    "            detectedHands = handLandmarker\n"
    "                .detect(image, sensorOrientation)\n"
    "                .map((hand) => _mapHandLandmarks(hand.landmarks))\n"
    "                .toList(growable: false);\n"
    "          }\n",
)

replace(
    "use already-mapped landmarks",
    "              ? detectedHands\n"
    "                  .take(maxHands)\n"
    "                  .map((hand) => _mapHandLandmarks(hand.landmarks))\n"
    "                  .toList(growable: false)\n"
    "              : null;\n",
    "              ? detectedHands.take(maxHands).toList(growable: false)\n"
    "              : null;\n",
)

replace(
    "dispose worker",
    "    _handLandmarker?.dispose();\n",
    "    _handWorker?.dispose();\n    _handLandmarker?.dispose();\n",
)

if problems:
    print("\nNOT saved (nothing changed):", ", ".join(problems))
    sys.exit(1)

shutil.copyfile(SCREEN, SCREEN + ".bak4")
with open(SCREEN, "w", encoding="utf-8", newline="") as f:
    f.write(text)
print("\nSaved (backup: .bak4).")
print("In the run log, look for:  'Hand tracker: running on a background isolate'")
print("or:                        'Hand worker unavailable ... using main isolate'")
