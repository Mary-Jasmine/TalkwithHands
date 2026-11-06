"""
Let the USER choose Landscape or Portrait in the sign detection screen.
Adds a 'Landscape' / 'Portrait' button in the top bar and remembers the choice.

Run AFTER patch_landscape.py, from the project root:
    python patch_orientation_choice.py
"""
import os
import shutil
import sys

SCREEN = os.path.join("lib", "screens", "sign_detector_screen_mobile.dart")

if not os.path.exists(SCREEN):
    sys.exit(f"Not found: {SCREEN}  (run this from the project root)")

with open(SCREEN, "r", encoding="utf-8", newline="") as f:
    text = f.read()

if "_toggleOrientation" in text:
    sys.exit("Already patched, nothing to do.")
if "_uprightRotation" not in text:
    sys.exit("Run patch_landscape.py first, then run this again.")

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
    "import shared_preferences",
    "import 'package:flutter/services.dart';\n",
    "import 'package:flutter/services.dart';\n"
    "import 'package:shared_preferences/shared_preferences.dart';\n",
)

replace(
    "initState loads the saved choice instead of forcing landscape",
    "    SystemChrome.setPreferredOrientations(const [\n"
    "      DeviceOrientation.landscapeLeft,\n"
    "      DeviceOrientation.landscapeRight,\n"
    "    ]);\n",
    "    _loadOrientationChoice();\n",
)

replace(
    "orientation choice methods",
    "  /// Clockwise degrees that make the raw sensor frame upright right now.\n"
    "  int get _uprightRotation {\n",
    """  static const String _kOrientationKey = 'sign_detector_landscape';
  bool _landscape = false; // default: portrait

  Future<void> _loadOrientationChoice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _landscape = prefs.getBool(_kOrientationKey) ?? false;
    } catch (_) {}
    _applyOrientation();
    if (mounted) setState(() {});
  }

  void _applyOrientation() {
    SystemChrome.setPreferredOrientations(
      _landscape
          ? const [
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ]
          : const [DeviceOrientation.portraitUp],
    );
  }

  Future<void> _toggleOrientation() async {
    setState(() => _landscape = !_landscape);
    _applyOrientation();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kOrientationKey, _landscape);
    } catch (_) {}
  }

  /// Clockwise degrees that make the raw sensor frame upright right now.
  int get _uprightRotation {
""",
)

replace(
    "top bar toggle button",
    "          const SizedBox(width: 8),\n"
    "          _TopBtn(\n"
    "            label: 'Collect',\n",
    "          const SizedBox(width: 8),\n"
    "          _TopBtn(\n"
    "            label: _landscape ? 'Portrait' : 'Landscape',\n"
    "            active: false,\n"
    "            onTap: _toggleOrientation,\n"
    "          ),\n"
    "          const SizedBox(width: 6),\n"
    "          _TopBtn(\n"
    "            label: 'Collect',\n",
)

if problems:
    print("\nNOT saved (nothing changed):", ", ".join(problems))
    sys.exit(1)

shutil.copyfile(SCREEN, SCREEN + ".bak2")
with open(SCREEN, "w", encoding="utf-8", newline="") as f:
    f.write(text)
print("\nSaved (backup: .bak2). Run the app: tap Landscape / Portrait in the top bar.")
