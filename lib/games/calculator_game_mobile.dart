import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:hand_landmarker/hand_landmarker.dart' as mp_hand;
import 'package:permission_handler/permission_handler.dart';

import '../classifiers/sign_classifier.dart';
import '../classifiers/tflite_sign_classifier.dart';
import '../painters/landmark_painter.dart';

class CalculatorGamePage extends StatefulWidget {
  const CalculatorGamePage({super.key});

  @override
  State<CalculatorGamePage> createState() => _CalculatorGamePageState();
}

class _CalculatorGamePageState extends State<CalculatorGamePage>
    with WidgetsBindingObserver {
  static const _assetRoot = 'assets/calcuavatars';

  CameraController? _cameraController;
  late final mp_hand.HandLandmarkerPlugin _handLandmarker;
  final SignClassifier _classifier = SignClassifier();
  final TfliteSignClassifier _tfliteClassifier = TfliteSignClassifier(
    minimumConfidence: 0.72,
  );
  bool _cameraStarting = false;
  bool _manualMode = false;
  bool _capturing = false;
  bool _processing = false;
  bool _streaming = false;
  bool _modelsReady = false;
  int _frameCounter = 0;
  DateTime _lastInferenceAt = DateTime.fromMillisecondsSinceEpoch(0);

  String _display = '0';
  String? _pendingOperator;
  double? _storedValue;
  bool _replaceDisplay = false;
  List<HandLandmark>? _handLandmarks;
  SignResult? _currentHit;
  String? _stableInput;
  String? _lastRawInput;
  int _stableFrames = 0;

  static const int _processEveryNFrames = 5;
  static const int _stableFramesNeeded = 5;
  static const Duration _minInferenceGap = Duration(milliseconds: 180);
  static const Map<String, String> _commandSigns = {
    'A': 'AC',
    'C': 'AC',
    'D': 'DEL',
    'P': '+',
    'M': '-',
    'X': 'x',
    'Q': '/',
    'E': '=',
  };

  bool get _cameraReady =>
      _cameraController != null && _cameraController!.value.isInitialized;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _handLandmarker = mp_hand.HandLandmarkerPlugin.create(
      numHands: 1,
      minHandDetectionConfidence: 0.55,
      delegate: mp_hand.HandLandmarkerDelegate.cpu,
    );
    unawaited(_loadModels());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_stopImageStream());
    _cameraController?.dispose();
    _handLandmarker.dispose();
    _tfliteClassifier.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_cameraReady) return;
    if (state == AppLifecycleState.inactive) {
      _stopCamera();
    }
  }

  Future<void> _loadModels() async {
    await _tfliteClassifier.load();
    if (!mounted) return;
    setState(() => _modelsReady = true);
  }

  Future<void> _startCamera() async {
    if (_cameraStarting) return;
    setState(() {
      _cameraStarting = true;
      _manualMode = false;
    });

    final permission = await Permission.camera.request();
    if (!permission.isGranted) {
      if (!mounted) return;
      setState(() => _cameraStarting = false);
      _showMessage('Camera permission is needed to detect signs.');
      return;
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) _showMessage('No camera found on this device.');
        return;
      }

      final camera = cameras.firstWhere(
        (item) => item.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await controller.initialize();
      await _stopImageStream();
      await _cameraController?.dispose();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _cameraController = controller;
        _handLandmarks = null;
        _currentHit = null;
        _stableInput = null;
      });
      await _startImageStream();
    } catch (error) {
      if (mounted) _showMessage('Camera error: $error');
    } finally {
      if (mounted) setState(() => _cameraStarting = false);
    }
  }

  Future<void> _stopCamera() async {
    final controller = _cameraController;
    await _stopImageStream();
    _cameraController = null;
    _handLandmarks = null;
    _currentHit = null;
    _stableInput = null;
    if (mounted) setState(() {});
    await controller?.dispose();
  }

  Future<void> _captureFrame() async {
    if (!_cameraReady || _capturing) {
      _showMessage('Start the camera first.');
      return;
    }
    final input = _stableInput;
    if (input == null) {
      _showMessage('Hold a clear calculator sign first.');
      return;
    }
    setState(() => _capturing = true);
    try {
      setState(() => _applyDetectedInput(input));
      _showMessage('Detected $input');
    } catch (error) {
      if (mounted) _showMessage('Sign input failed: $error');
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<void> _enableManualMode() async {
    await _stopCamera();
    if (!mounted) return;
    setState(() => _manualMode = true);
    _showMessage('Manual input enabled.');
  }

  Future<void> _startImageStream() async {
    final controller = _cameraController;
    if (controller == null || _streaming || !controller.value.isInitialized) {
      return;
    }
    await controller.startImageStream(_onCameraFrame);
    _streaming = true;
  }

  Future<void> _stopImageStream() async {
    final controller = _cameraController;
    if (controller == null || !_streaming) return;
    try {
      await controller.stopImageStream();
    } catch (_) {
      // The camera plugin can throw if the stream is already stopping.
    } finally {
      _streaming = false;
      _processing = false;
    }
  }

  void _onCameraFrame(CameraImage image) {
    if (_processing || !_cameraReady) return;
    _frameCounter++;
    if (_frameCounter % _processEveryNFrames != 0) return;

    final now = DateTime.now();
    if (now.difference(_lastInferenceAt) < _minInferenceGap) return;
    _lastInferenceAt = now;
    unawaited(_processFrame(image));
  }

  Future<void> _processFrame(CameraImage image) async {
    _processing = true;
    try {
      final controller = _cameraController;
      if (controller == null || image.planes.length < 3) return;

      final detectedHands = _handLandmarker.detect(
        image,
        controller.description.sensorOrientation,
      );
      final landmarks = detectedHands.isEmpty
          ? null
          : _mapHandLandmarks(detectedHands.first.landmarks);
      final hit = landmarks == null ? null : _classifyCalculatorSign(landmarks);
      final input = hit == null ? null : _calculatorInputFor(hit);

      if (!mounted) return;
      setState(() {
        _handLandmarks = landmarks;
        _currentHit = hit;
        _updateStableInput(input);
      });
    } catch (error) {
      debugPrint('Calculator hand detection error: $error');
    } finally {
      _processing = false;
    }
  }

  List<HandLandmark> _mapHandLandmarks(List<mp_hand.Landmark> landmarks) {
    return landmarks
        .map((landmark) => HandLandmark(landmark.x, landmark.y, landmark.z))
        .toList(growable: false);
  }

  SignResult? _classifyCalculatorSign(List<HandLandmark> landmarks) {
    final numberHit = _tfliteClassifier.classifyNumber(landmarks) ??
        _classifier.classifyNumber(landmarks);
    if (numberHit != null && _calculatorInputFor(numberHit) != null) {
      return numberHit;
    }

    final alphabetHit = _tfliteClassifier.classifyAlphabet(landmarks) ??
        _classifier.classifyAlphabet(landmarks);
    if (alphabetHit != null && _calculatorInputFor(alphabetHit) != null) {
      return alphabetHit;
    }

    return null;
  }

  String? _calculatorInputFor(SignResult hit) {
    final label = hit.label.toUpperCase();
    if (RegExp(r'^\d$').hasMatch(label)) return label;
    return _commandSigns[label];
  }

  void _updateStableInput(String? input) {
    if (input == null) {
      _lastRawInput = null;
      _stableFrames = 0;
      _stableInput = null;
      return;
    }

    if (input == _lastRawInput) {
      _stableFrames++;
    } else {
      _lastRawInput = input;
      _stableFrames = 1;
    }

    _stableInput = _stableFrames >= _stableFramesNeeded ? input : null;
  }

  void _applyDetectedInput(String value) {
    if (RegExp(r'^\d$').hasMatch(value)) {
      _inputDigit(value);
    } else if (value == 'AC') {
      _clearCalculator();
    } else if (value == 'DEL') {
      _deleteLast();
    } else if (value == '=') {
      _resolveOperation();
    } else {
      _chooseOperator(value);
    }
    _stableInput = null;
    _lastRawInput = null;
    _stableFrames = 0;
    _classifier.reset();
    _tfliteClassifier.resetSequenceBuffer();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  void _onCalculatorTap(String value) {
    if (!_manualMode) {
      _showMessage('Tap Manual to use the keypad.');
      return;
    }

    setState(() {
      if (RegExp(r'^\d$').hasMatch(value)) {
        _inputDigit(value);
      } else if (value == '.') {
        _inputDecimal();
      } else if (value == 'AC') {
        _clearCalculator();
      } else if (value == 'DEL') {
        _deleteLast();
      } else if (value == '%') {
        _display = _formatNumber(_currentValue() / 100);
      } else if (value == '=') {
        _resolveOperation();
      } else {
        _chooseOperator(value);
      }
    });
  }

  void _inputDigit(String digit) {
    if (_replaceDisplay || _display == '0') {
      _display = digit;
      _replaceDisplay = false;
      return;
    }
    if (_display.length < 10) _display += digit;
  }

  void _inputDecimal() {
    if (_replaceDisplay) {
      _display = '0.';
      _replaceDisplay = false;
      return;
    }
    if (!_display.contains('.')) _display += '.';
  }

  void _clearCalculator() {
    _display = '0';
    _storedValue = null;
    _pendingOperator = null;
    _replaceDisplay = false;
  }

  void _deleteLast() {
    if (_replaceDisplay || _display.length <= 1) {
      _display = '0';
      _replaceDisplay = false;
      return;
    }
    _display = _display.substring(0, _display.length - 1);
  }

  void _chooseOperator(String operator) {
    if (_pendingOperator != null && !_replaceDisplay) {
      _resolveOperation();
    }
    _storedValue = _currentValue();
    _pendingOperator = operator;
    _replaceDisplay = true;
  }

  void _resolveOperation() {
    final operator = _pendingOperator;
    final left = _storedValue;
    if (operator == null || left == null) return;

    final right = _currentValue();
    final result = switch (operator) {
      '+' => left + right,
      '-' => left - right,
      'x' => left * right,
      '/' => right == 0 ? double.nan : left / right,
      _ => right,
    };

    _display = result.isNaN ? 'Error' : _formatNumber(result);
    _storedValue = null;
    _pendingOperator = null;
    _replaceDisplay = true;
  }

  double _currentValue() => double.tryParse(_display) ?? 0;

  String _formatNumber(double value) {
    if (value.isInfinite || value.isNaN) return 'Error';
    if (value % 1 == 0) return value.toInt().toString();
    return value
        .toStringAsFixed(6)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final canvasWidth = constraints.maxWidth.clamp(0.0, 430.0).toDouble();
          final canvasHeight = constraints.maxHeight;
          return Center(
            child: SizedBox(
              width: canvasWidth,
              height: canvasHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      '$_assetRoot/cal-bg.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                  SafeArea(
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight:
                              canvasHeight - MediaQuery.of(context).padding.top,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                          child: Column(
                            children: [
                              _buildTopBar(context),
                              const SizedBox(height: 8),
                              _buildHeroIcon(),
                              const SizedBox(height: 14),
                              _buildGameStage(),
                              const SizedBox(height: 12),
                              _buildActionButtons(),
                              const SizedBox(height: 10),
                              _buildCalculator(),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const _DecorativeAsset(
                    asset: 'peace.png',
                    left: 26,
                    top: 174,
                    width: 48,
                    rotation: -0.18,
                  ),
                  const _DecorativeAsset(
                    asset: 'wssun.png',
                    right: 20,
                    top: 78,
                    width: 76,
                  ),
                  const _DecorativeAsset(
                    asset: 'cloud.png',
                    left: 77,
                    top: 78,
                    width: 48,
                  ),
                  const _DecorativeAsset(
                    asset: 'clouds.png',
                    right: 39,
                    top: 146,
                    width: 48,
                  ),
                  const _DecorativeAsset(
                    asset: 'sign.png',
                    right: 19,
                    top: 274,
                    width: 78,
                    rotation: 0.13,
                  ),
                  const _DecorativeAsset(
                    asset: 'bulb.png',
                    right: 18,
                    top: 386,
                    width: 46,
                    rotation: 0.16,
                  ),
                  const _DecorativeAsset(
                    asset: 'rainbow.png',
                    left: -6,
                    bottom: 248,
                    width: 83,
                  ),
                  const _DecorativeAsset(
                    asset: 'avatar.png',
                    right: 6,
                    bottom: 31,
                    width: 103,
                  ),
                  const _DecorativeAsset(
                    asset: 'flowers.png',
                    left: 4,
                    bottom: 0,
                    width: 72,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _CircleIconButton(
          color: const Color(0xFFF3382E),
          icon: Icons.arrow_back_rounded,
          onTap: () => Navigator.of(context).maybePop(),
        ),
        _CircleIconButton(
          color: const Color(0xFFFFA000),
          icon: Icons.menu_rounded,
          onTap: () => _showMessage('Menu'),
        ),
      ],
    );
  }

  Widget _buildHeroIcon() {
    return Image.asset(
      '$_assetRoot/calculator_icon.png',
      width: 116,
      fit: BoxFit.contain,
    );
  }

  Widget _buildGameStage() {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Container(
          width: 224,
          height: 191,
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: const Color(0xFFFFA000),
            borderRadius: BorderRadius.circular(21),
            border: Border.all(color: const Color(0xFFFFD54F), width: 3),
            boxShadow: const [
              BoxShadow(
                color: Color(0x8800528C),
                blurRadius: 0,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: CustomPaint(
            painter: const _DashedFramePainter(),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Container(
                color: const Color(0xFF666666),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildCameraPreview(),
                    if (_cameraReady && _handLandmarks != null)
                      CustomPaint(
                        painter: LandmarkPainter(
                          handLandmarks: _handLandmarks,
                          previewSize:
                              _cameraController!.value.previewSize ?? Size.zero,
                          lensDirection:
                              _cameraController!.description.lensDirection,
                          sensorOrientation:
                              _cameraController!.description.sensorOrientation,
                        ),
                      ),
                    _buildDetectionBadge(),
                  ],
                ),
              ),
            ),
          ),
        ),
        const Positioned(
          left: -48,
          top: 52,
          child: _MotionMarks(color: Color(0xFFFFD43B)),
        ),
        const Positioned(
          right: -44,
          top: 75,
          child: _MotionMarks(color: Color(0xFFFF3EA5), flipped: true),
        ),
      ],
    );
  }

  Widget _buildDetectionBadge() {
    final text = _stableInput != null
        ? 'Ready: $_stableInput'
        : _currentHit != null
            ? 'Hold ${_calculatorInputFor(_currentHit!)}'
            : _cameraReady
                ? (_modelsReady ? 'Show sign' : 'Loading model')
                : 'Start camera';

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xCC000000),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white, width: 1),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (_cameraReady) {
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _cameraController!.value.previewSize?.height ?? 1,
            height: _cameraController!.value.previewSize?.width ?? 1,
            child: CameraPreview(_cameraController!),
          ),
        ),
      );
    }

    return Center(
      child: AnimatedOpacity(
        opacity: _cameraStarting ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        child: const SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 3,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _GameActionButton(
          icon: Icons.camera_alt_rounded,
          label: 'Start Camera',
          color: const Color(0xFF1268EA),
          onTap: _startCamera,
        ),
        const SizedBox(width: 8),
        _GameActionButton(
          icon: Icons.center_focus_strong_rounded,
          label: 'Capture',
          color: const Color(0xFF35C84A),
          onTap: _captureFrame,
        ),
        const SizedBox(width: 8),
        _GameActionButton(
          icon: Icons.front_hand_rounded,
          label: 'Manual',
          color: const Color(0xFFFF7900),
          onTap: _enableManualMode,
        ),
      ],
    );
  }

  Widget _buildCalculator() {
    const rows = [
      ['AC', 'DEL', '%', '/'],
      ['7', '8', '9', 'x'],
      ['4', '5', '6', '-'],
      ['3', '2', '1', '+'],
      ['0', '.', '='],
    ];

    return Container(
      width: 196,
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0xFF1E1E1E), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 8,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 51,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 3),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFF242424), width: 1),
              ),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                _display,
                maxLines: 1,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          for (final row in rows) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final value in row) ...[
                  _CalcButton(
                    label: value,
                    wide: value == '=',
                    onTap: () => _onCalculatorTap(value),
                  ),
                  if (value != row.last) const SizedBox(width: 9),
                ],
              ],
            ),
            if (row != rows.last) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _DecorativeAsset extends StatelessWidget {
  final String asset;
  final double? left;
  final double? right;
  final double? top;
  final double? bottom;
  final double width;
  final double rotation;

  const _DecorativeAsset({
    required this.asset,
    this.left,
    this.right,
    this.top,
    this.bottom,
    required this.width,
    this.rotation = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      right: right,
      top: top,
      bottom: bottom,
      child: IgnorePointer(
        child: Transform.rotate(
          angle: rotation,
          child: Image.asset(
            'assets/calcuavatars/$asset',
            width: width,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _CircleIconButton({
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Icon(icon, color: Colors.white, size: 31),
        ),
      ),
    );
  }
}

class _GameActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _GameActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(14),
      elevation: 4,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          height: 39,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalcButton extends StatelessWidget {
  final String label;
  final bool wide;
  final VoidCallback onTap;

  const _CalcButton({
    required this.label,
    required this.onTap,
    this.wide = false,
  });

  bool get _filled =>
      const {'AC', 'DEL', '%', '/', 'x', '-', '+', '='}.contains(label);

  @override
  Widget build(BuildContext context) {
    final width = wide ? 85.0 : 38.0;
    return Material(
      color: _filled ? const Color(0xFFFFB20D) : Colors.black,
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: onTap,
        child: Container(
          width: width,
          height: 35,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: const Color(0xFFFFB20D), width: 2),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: _filled ? Colors.black : Colors.white,
              fontSize: label.length > 1 ? 14 : 19,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _MotionMarks extends StatelessWidget {
  final Color color;
  final bool flipped;

  const _MotionMarks({
    required this.color,
    this.flipped = false,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scaleX: flipped ? -1 : 1,
      child: CustomPaint(
        size: const Size(31, 40),
        painter: _MotionMarksPainter(color),
      ),
    );
  }
}

class _MotionMarksPainter extends CustomPainter {
  final Color color;

  const _MotionMarksPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.80, size.height * 0.16),
      Offset(size.width * 0.40, size.height * 0.35),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.90, size.height * 0.50),
      Offset(size.width * 0.42, size.height * 0.50),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.80, size.height * 0.84),
      Offset(size.width * 0.40, size.height * 0.65),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DashedFramePainter extends CustomPainter {
  const _DashedFramePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(3),
      const Radius.circular(16),
    );
    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    for (final metric in metrics) {
      var distance = 0.0;
      const dash = 3.0;
      const gap = 3.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + dash),
          paint,
        );
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
