"""
Update the hand overlay BEFORE the slow classifier runs, so the box follows
the hand without waiting for TFLite. Run from the project root, AFTER
patch_performance.py:
    python patch_early_overlay.py
"""
import os
import shutil
import sys

SCREEN = os.path.join("lib", "screens", "sign_detector_screen_mobile.dart")
if not os.path.exists(SCREEN):
    sys.exit(f"Not found: {SCREEN}  (run this from the project root)")

with open(SCREEN, "r", encoding="utf-8", newline="") as f:
    text = f.read()

if "Publish the hand overlay NOW" in text:
    sys.exit("Already patched, nothing to do.")
if "_overlayHands" not in text:
    sys.exit("Run patch_performance.py first (it makes the overlay repaint on its own), then run this again.")

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
    "publish the overlay before classification",
    "      SignResult? hit;\n"
    "      final canClassify = _detectionArmed && _startCountdown == 0;\n",
    "      // Publish the hand overlay NOW (before the slow classifier runs) so the\n"
    "      // box follows the hand without waiting for TFLite.\n"
    "      final handPresenceChanged =\n"
    "          (displayHandLandmarks == null) != (_handLandmarks == null);\n"
    "      _handLandmarks = displayHandLandmarks;\n"
    "      _handsLandmarks = displayHandsLandmarks;\n"
    "\n"
    "      SignResult? hit;\n"
    "      final canClassify = _detectionArmed && _startCountdown == 0;\n",
)

replace(
    "remove the late overlay update",
    "      final handPresenceChanged =\n"
    "          (displayHandLandmarks == null) != (_handLandmarks == null);\n"
    "      final uiTimerExpired = now.difference(_lastUiUpdateAt) >= _minUiGap;\n"
    "\n"
    "      // Always update internal state\n"
    "      _handLandmarks = displayHandLandmarks;\n"
    "      _handsLandmarks = displayHandsLandmarks;\n"
    "      _currentHit = visibleHit;\n",
    "      final uiTimerExpired = now.difference(_lastUiUpdateAt) >= _minUiGap;\n"
    "\n"
    "      // The overlay was already published above; only the hit changes here.\n"
    "      _currentHit = visibleHit;\n",
)

if problems:
    print("\nNOT saved (nothing changed):", ", ".join(problems))
    sys.exit(1)

shutil.copyfile(SCREEN, SCREEN + ".bak5")
with open(SCREEN, "w", encoding="utf-8", newline="") as f:
    f.write(text)
print("\nSaved (backup: .bak5).")
