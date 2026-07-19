import 'package:flutter/material.dart';

class CalculatorGamePage extends StatefulWidget {
  const CalculatorGamePage({super.key});

  @override
  State<CalculatorGamePage> createState() => _CalculatorGamePageState();
}

class _CalculatorGamePageState extends State<CalculatorGamePage> {
  static const _assetRoot = 'assets/calcuavatars';

  String _display = '0';
  String? _pendingOperator;
  double? _storedValue;
  bool _replaceDisplay = false;

  void _onCalculatorTap(String value) {
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
                              Image.asset(
                                '$_assetRoot/calculator_icon.png',
                                width: 116,
                                fit: BoxFit.contain,
                              ),
                              const SizedBox(height: 14),
                              _buildWebStage(),
                              const SizedBox(height: 12),
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
          onTap: () {},
        ),
      ],
    );
  }

  Widget _buildWebStage() {
    return Container(
      width: 224,
      height: 191,
      padding: const EdgeInsets.all(10),
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
      child: const Center(
        child: Text(
          'Manual keypad is available on web.\nCamera sign input runs in the Android app.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w900,
            height: 1.2,
          ),
        ),
      ),
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
