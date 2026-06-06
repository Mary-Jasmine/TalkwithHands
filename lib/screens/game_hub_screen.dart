import 'package:flutter/material.dart';

import 'package:sign_language_app/games/guess_asl_game.dart' as guess_asl;
import 'package:sign_language_app/games/guess_me_game.dart' as guess_me;
import '../services/progress_service.dart';
import '../ui/app_shell.dart';

class GameHubScreen extends StatefulWidget {
  final String userName;

  const GameHubScreen({
    super.key,
    required this.userName,
  });

  @override
  State<GameHubScreen> createState() => _GameHubScreenState();
}

class _GameHubScreenState extends State<GameHubScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  Future<void> _recordGameFinished() async {
    try {
      await ProgressService().recordActivity(
        category: 'game',
        gameCompleted: true,
      );
    } catch (_) {
      // Progress sync should never interrupt gameplay.
    }
  }

  void _openGuessAsl() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => guess_asl.GameScreen(
          onExit: () => Navigator.of(context).maybePop(),
          onGameFinished: ({
            required won,
            required score,
            required completed,
            required total,
          }) {
            _recordGameFinished();
          },
        ),
      ),
    );
  }

  void _openGuessMe() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const guess_me.GuessMeScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      endDrawer: AppMenuDrawer(
        userName: widget.userName,
        onClose: () => Navigator.of(context).pop(),
        activeScreen: 'Game',
      ),
      body: _GameStageBackground(
        child: SafeArea(
          child: Column(
            children: [
              AppTopBar(
                onBack: () => Navigator.of(context).pop(),
                onMenu: () => _scaffoldKey.currentState?.openEndDrawer(),
              ),
              const SizedBox(height: 14),
              const Text(
                'GAME',
                style: TextStyle(
                  color: Color.fromARGB(255, 255, 255, 255),
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 34),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.65),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth > 520 ? 3 : 2;
                        final spacing = columns == 2 ? 18.0 : 22.0;
                        final itemWidth =
                            (constraints.maxWidth - spacing * (columns - 1)) /
                                columns;

                        return Wrap(
                          spacing: spacing,
                          runSpacing: 22,
                          children: [
                            SizedBox(
                              width: itemWidth,
                              child: _GameTile(
                                label: 'Calculator',
                                subtitle: 'Coming soon',
                                child: const _CalculatorIcon(),
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Calculator game is not available yet.',
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            SizedBox(
                              width: itemWidth,
                              child: _GameTile(
                                label: 'Guess ASL',
                                subtitle: 'Letters & numbers',
                                onTap: _openGuessAsl,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(22),
                                  child: Image.asset(
                                    'assets/images/guess_asl_icon.png',
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: itemWidth,
                              child: _GameTile(
                                label: 'Guess Me',
                                subtitle: 'Video phrase quiz',
                                onTap: _openGuessMe,
                                child: const _GuessMeIcon(),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GameStageBackground extends StatelessWidget {
  final Widget child;

  const _GameStageBackground({required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF004B7C), Color(0xFF008BCC), Color(0xFF04C8F8)],
          stops: [0, 0.48, 1],
        ),
      ),
      child: CustomPaint(
        painter: _GameStagePainter(),
        child: child,
      ),
    );
  }
}

class _GameStagePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final spotlightPaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0x55FFF176), Color(0x00FFF176)],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * 0.18, size.height * 0.24),
        radius: size.width * 0.48,
      ));
    canvas.drawCircle(
      Offset(size.width * 0.18, size.height * 0.24),
      size.width * 0.48,
      spotlightPaint,
    );

    final secondSpotlightPaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0x55FF5DA2), Color(0x00FF5DA2)],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * 0.86, size.height * 0.18),
        radius: size.width * 0.42,
      ));
    canvas.drawCircle(
      Offset(size.width * 0.86, size.height * 0.18),
      size.width * 0.42,
      secondSpotlightPaint,
    );

    final stripePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.045
      ..color = const Color(0x7739D8E8);
    final spacing = size.width / 7;

    for (var i = 0; i < 8; i++) {
      final x = spacing * i + spacing * 0.5;
      final path = Path()
        ..moveTo(x, 0)
        ..lineTo(x, size.height * 0.70)
        ..quadraticBezierTo(
          x,
          size.height * 0.78,
          x - size.width * 0.18,
          size.height,
        );
      canvas.drawPath(path, stripePaint);
    }

    final floorPaint = Paint()..color = const Color(0x22002693);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.91),
        width: size.width * 1.18,
        height: size.height * 0.26,
      ),
      floorPaint,
    );

    final confettiPaint = Paint()..style = PaintingStyle.fill;
    final confetti = [
      (Offset(size.width * 0.12, size.height * 0.17), const Color(0xFFFFD43B)),
      (Offset(size.width * 0.78, size.height * 0.31), const Color(0xFFFF5DA2)),
      (Offset(size.width * 0.24, size.height * 0.63), const Color(0xFF69F0AE)),
      (Offset(size.width * 0.90, size.height * 0.62), const Color(0xFFFFF176)),
      (Offset(size.width * 0.52, size.height * 0.15), const Color(0xFFE040FB)),
    ];

    for (final item in confetti) {
      confettiPaint.color = item.$2.withValues(alpha: 0.78);
      final center = item.$1;
      final rect = Rect.fromCenter(
        center: center,
        width: size.width * 0.035,
        height: size.width * 0.035,
      );
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(center.dx / size.width);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: rect.width,
            height: rect.height,
          ),
          const Radius.circular(3),
        ),
        confettiPaint,
      );
      canvas.restore();
    }

    final outlinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.34);
    _drawGamepad(canvas, Offset(size.width * 0.78, size.height * 0.78),
        size.width * 0.18, outlinePaint);

    final glowPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x00000000), Color(0x77002693)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, glowPaint);
  }

  void _drawGamepad(Canvas canvas, Offset center, double width, Paint paint) {
    final height = width * 0.52;
    final rect = Rect.fromCenter(center: center, width: width, height: height);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(height * 0.38)),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx - width * 0.30, center.dy),
      Offset(center.dx - width * 0.16, center.dy),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx - width * 0.23, center.dy - height * 0.16),
      Offset(center.dx - width * 0.23, center.dy + height * 0.16),
      paint,
    );
    canvas.drawCircle(
        Offset(center.dx + width * 0.20, center.dy - height * 0.08),
        width * 0.025,
        paint);
    canvas.drawCircle(
        Offset(center.dx + width * 0.31, center.dy + height * 0.08),
        width * 0.025,
        paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GameTile extends StatelessWidget {
  final String label;
  final String subtitle;
  final Widget child;
  final VoidCallback onTap;

  const _GameTile({
    required this.label,
    required this.subtitle,
    required this.child,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0x332693FF), width: 1.4),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFFFFF), Color(0xFFEAF8FF)],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF002693).withValues(alpha: 0.18),
                        blurRadius: 14,
                        offset: const Offset(0, 7),
                      ),
                    ],
                  ),
                  child: child,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 21,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF185FA5),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuessMeIcon extends StatelessWidget {
  const _GuessMeIcon();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF27AAEB), Color(0xFF0D6FAB)],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _GuessMeIconPainter()),
            ),
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_circle_fill_rounded,
                      color: Colors.white, size: 46),
                  SizedBox(height: 8),
                  Text(
                    'GUESS\nME?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      height: 0.9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuessMeIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stripePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.13)
      ..strokeWidth = size.width * 0.12;
    for (double x = -size.height; x < size.width + size.height; x += 36) {
      canvas.drawLine(
          Offset(x, 0), Offset(x + size.height, size.height), stripePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CalculatorIcon extends StatelessWidget {
  const _CalculatorIcon();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: GridView.count(
        crossAxisCount: 2,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: const [
          _CalcCell(label: '+', color: Color(0xFFFF9700)),
          _CalcCell(label: '-', color: Color(0xFFFF9700)),
          _CalcCell(label: 'x', color: Color(0xFFFF9700)),
          _CalcCell(label: '=', color: Color(0xFFD8D8D8), dark: true),
        ],
      ),
    );
  }
}

class _CalcCell extends StatelessWidget {
  final String label;
  final Color color;
  final bool dark;

  const _CalcCell({
    required this.label,
    required this.color,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: Colors.black12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: dark ? Colors.black54 : Colors.white,
          fontSize: 38,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
