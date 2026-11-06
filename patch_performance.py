"""
Smoother sign detection (less UI-thread work). Run from the project root:
    python patch_performance.py

1. A-Z mode runs the static + sequence models at the same time (not one after
   the other) -> faster results per frame.
2. Hand overlay repaints on its own (ValueNotifier) instead of rebuilding the
   whole screen every frame; the rest of the UI refreshes at most every 150 ms.
"""
import os
import shutil
import sys

SCREEN = os.path.join("lib", "screens", "sign_detector_screen_mobile.dart")
if not os.path.exists(SCREEN):
    sys.exit(f"Not found: {SCREEN}  (run this from the project root)")

with open(SCREEN, "r", encoding="utf-8", newline="") as f:
    text = f.read()

if "_overlayHands" in text:
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
    "A-Z: run both models in parallel",
    "        final sequenceHit = await _tfliteClassifier.pushFrameAndClassify(\n"
    "          primaryHandLandmarks,\n"
    "        );\n"
    "        final tfliteHit = await _tfliteClassifier.classifyAlphabet(\n"
    "          primaryHandLandmarks,\n"
    "        );\n",
    "        // Both models run on their own isolates, so start them together.\n"
    "        final sequenceFuture = _tfliteClassifier.pushFrameAndClassify(\n"
    "          primaryHandLandmarks,\n"
    "        );\n"
    "        final tfliteFuture = _tfliteClassifier.classifyAlphabet(\n"
    "          primaryHandLandmarks,\n"
    "        );\n"
    "        final sequenceHit = await sequenceFuture;\n"
    "        final tfliteHit = await tfliteFuture;\n",
)

replace(
    "overlay data in a notifier",
    "  List<List<HandLandmark>>? _handsLandmarks;\n"
    "  List<List<HandLandmark>>? _smoothedHandsLandmarks;\n",
    "  // Overlay data lives in a notifier so only the hand box repaints each\n"
    "  // frame (not the whole screen).\n"
    "  final ValueNotifier<List<List<HandLandmark>>?> _overlayHands =\n"
    "      ValueNotifier<List<List<HandLandmark>>?>(null);\n"
    "  List<List<HandLandmark>>? get _handsLandmarks => _overlayHands.value;\n"
    "  set _handsLandmarks(List<List<HandLandmark>>? value) =>\n"
    "      _overlayHands.value = value;\n"
    "  List<List<HandLandmark>>? _smoothedHandsLandmarks;\n",
)

replace(
    "painter listens to the notifier (start)",
    "                  child: CustomPaint(\n"
    "                    painter: LandmarkPainter(\n"
    "                      handsLandmarks: _handsLandmarks,\n",
    "                  child: ValueListenableBuilder<List<List<HandLandmark>>?>(\n"
    "                    valueListenable: _overlayHands,\n"
    "                    builder: (context, hands, _) => CustomPaint(\n"
    "                    painter: LandmarkPainter(\n"
    "                      handsLandmarks: hands,\n",
)

def close_builder():
    """Add the closing ')' for ValueListenableBuilder by matching parentheses,
    so it works no matter what code surrounds the preview widget."""
    global text
    name = "painter listens to the notifier (end)"
    marker = "builder: (context, hands, _) => CustomPaint("
    if text.count(marker) != 1:
        problems.append(name)
        print(f"  FAIL {name}: start marker not found")
        return
    open_idx = text.index(marker) + len(marker) - 1
    depth = 0
    quote = None
    j = open_idx
    while j < len(text):
        c = text[j]
        if quote:
            if c == "\\":
                j += 2
                continue
            if c == quote:
                quote = None
        elif c in ("'", '"'):
            quote = c
        elif c == "(":
            depth += 1
        elif c == ")":
            depth -= 1
            if depth == 0:
                break
        j += 1
    if depth != 0:
        problems.append(name)
        print(f"  FAIL {name}: parentheses do not match")
        return
    text = text[: j + 1] + "," + nl + "                  )" + text[j + 1 :]
    print(f"  ok   {name}")


close_builder()

replace(
    "rest of the UI refreshes less often",
    "  // UI refreshes at most every 40ms (~25fps).\n"
    "  static const Duration _minUiGap = Duration(milliseconds: 40);\n",
    "  // Non-overlay UI refreshes at most every 150ms (the hand box repaints\n"
    "  // every detection through _overlayHands).\n"
    "  static const Duration _minUiGap = Duration(milliseconds: 150);\n",
)

if problems:
    print("\nNOT saved (nothing changed):", ", ".join(problems))
    sys.exit(1)

shutil.copyfile(SCREEN, SCREEN + ".bak3")
with open(SCREEN, "w", encoding="utf-8", newline="") as f:
    f.write(text)
print("\nSaved (backup: .bak3).")