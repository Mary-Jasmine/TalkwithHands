import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../ui/app_shell.dart';

class WelcomeScreen extends StatelessWidget {
  final String userName;

  const WelcomeScreen({
    super.key,
    required this.userName,
  });

  String get _firstName {
    final parts = userName.trim().split(' ');
    return parts.isNotEmpty ? parts.first : userName;
  }

  @override
  Widget build(BuildContext context) {
    final scaffoldKey = GlobalKey<ScaffoldState>();
    final topPad = MediaQuery.paddingOf(context).top;
    final sw = MediaQuery.sizeOf(context).width;
    final sh = MediaQuery.sizeOf(context).height;

    return Scaffold(
      key: scaffoldKey,
      endDrawer: AppMenuDrawer(
        userName: userName,
        onClose: () => Navigator.of(context).pop(),
        activeScreen: 'Home',
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Background ─────────────────────────────────────────────────
          Image.asset(
            'assets/images/home_bg_clean.png',
            fit: BoxFit.cover,
            width: sw,
            height: sh,
          ),

          // ── Logo button (top-left) ─────────────────────────────────────
          Positioned(
            top: topPad + 15,
            left: 14,
            child: _CircleBtn(
              onTap: () {},
              child: Image.asset(
                'assets/images/app_logo.png',
                width: 68,
                height: 68,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.sign_language_rounded,
                  color: Color.fromARGB(255, 1, 1, 1),
                  size: 26,
                  shadows: [
                    Shadow(
                        color: Color.fromARGB(255, 0, 0, 0),
                        offset: Offset(10, 5),
                        blurRadius: 4),
                  ],
                ),
              ),
            ),
          ),

          // ── Menu button (top-right) ────────────────────────────────────
          Positioned(
            top: topPad + 10,
            right: 14,
            child: AppMenuIconButton(
              onTap: () => scaffoldKey.currentState?.openEndDrawer(),
            ),
          ),

          // ── "Kumusta ka," ───────────────────────────────────────────
          Positioned(
            top: sh * 0.11 + topPad,
            left: 22,
            right: 22,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Kumusta ka, ',
                  style: GoogleFonts.poetsenOne(
                    color: Colors.white,
                    fontSize: sw * 0.068,
                    shadows: const [
                      Shadow(
                          color: Colors.black26,
                          offset: Offset(1, 2),
                          blurRadius: 4),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── "[Name]!" pink bold italic ─────────────────────────────────
          Positioned(
            top: sh * 0.14 + topPad,
            left: 50,
            right: 22,
            child: Text(
              '$_firstName!',
              style: GoogleFonts.poetsenOne(
                color: const Color.fromARGB(255, 240, 237, 239),
                fontSize: sw * 0.110,
                fontStyle: FontStyle.italic,
                shadows: const [
                  Shadow(
                      color: Color(0x66000000),
                      offset: Offset(2, 3),
                      blurRadius: 6),
                  Shadow(
                      color: Color.fromARGB(253, 246, 109, 237),
                      offset: Offset(-1, -1),
                      blurRadius: 3),
                ],
              ),
            ),
          ),

          // ── Speech bubble ──────────────────────────────────────────────
          Positioned(
            top: sh * 0.24 + topPad,
            left: sw * 0.10,
            right: sw * 0.04,
            child: Transform.rotate(
              angle: -5 * 3.14159265 / 180,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: sw * 0.045,
                      vertical: sh * 0.018,
                    ),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(235, 250, 250, 250),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 15,
                          offset: const Offset(4, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      'Handa ka na bang matuto\nng bagong Senyas ngayong\naraw?',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF1A2A5E),
                        fontSize: sw * 0.030,
                        fontWeight: FontWeight.w500,
                        height: 1.55,
                      ),
                    ),
                  ),
                  // bubble tail — bottom-left pointing to character
                  Positioned(
                    bottom: -13,
                    left: 26,
                    child: CustomPaint(
                      size: const Size(24, 14),
                      painter: _BubbleTailPainter(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Character avatar inside heart ──────────────────────────────
          Positioned(
            top: sh * 0.34,
            left: sw * 0.08,
            right: sw * 0.09,
            bottom: sh * 0.17,
            child: const _WavingCharacter(),
          ),

          // ── Start button ───────────────────────────────────────────────
          Positioned(
            bottom: sh * 0.095,
            left: sw * 0.12,
            right: sw * 0.12,
            child: _StartButton(
              onTap: () => scaffoldKey.currentState?.openEndDrawer(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Waving character ──────────────────────────────────────────────────────────
class _WavingCharacter extends StatefulWidget {
  const _WavingCharacter();
  @override
  State<_WavingCharacter> createState() => _WavingCharacterState();
}

class _WavingCharacterState extends State<_WavingCharacter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _wave;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _wave = Tween<double>(begin: -1.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _wave,
      builder: (context, child) {
        return Stack(
          children: [
            // Character image with slow gentle sway
            Positioned.fill(
              child: Transform.rotate(
                angle: _wave.value * 0.022,
                alignment: Alignment.bottomCenter,
                child: child,
              ),
            ),
            Positioned.fill(
                child: CustomPaint(
              painter: _HandWavePainter(
                  wave: _wave.value, relX: 0.22, relY: 0.80, direction: 1),
            )),
            Positioned.fill(
                child: CustomPaint(
              painter: _HandWavePainter(
                  wave: _wave.value, relX: 0.80, relY: 0.56, direction: -1),
            )),
          ],
        );
      },
      child: Image.asset(
        'assets/images/charwavenobg.png',
        fit: BoxFit.contain,
        alignment: Alignment.bottomCenter,
        errorBuilder: (_, __, ___) => const Center(
          child: Text('👨‍👩‍👦', style: TextStyle(fontSize: 80)),
        ),
      ),
    );
  }
}

class _HandWavePainter extends CustomPainter {
  final double wave;
  final double relX;
  final double relY;
  final int direction;
  const _HandWavePainter({
    required this.wave,
    required this.relX,
    required this.relY,
    required this.direction,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * relX;
    final cy = size.height * relY;
    final r = size.width * 0.10;
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(wave * direction * 0.32);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(0, -r * 0.3), width: r, height: r * 1.4),
      Paint()
        ..color = const Color(0x33FFFFFF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HandWavePainter old) => old.wave != wave;
}

// ── Bubble tail ───────────────────────────────────────────────────────────────
class _BubbleTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height)
        ..close(),
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ── Circle button ─────────────────────────────────────────────────────────────
class _CircleBtn extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;
  const _CircleBtn({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: Colors.black26,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: 50, height: 50, child: Center(child: child)),
      ),
    );
  }
}

// ── Start button ──────────────────────────────────────────────────────────────
class _StartButton extends StatelessWidget {
  final VoidCallback onTap;
  const _StartButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.sizeOf(context).width;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        splashColor: Colors.white24,
        child: Container(
          height: 62,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF90EEFF), Color(0xFF2EC8F2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.85),
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2EC8F2).withValues(alpha: 0.65),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.3),
                blurRadius: 6,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Text(
            'Start',
            style: GoogleFonts.nunito(
              color: const Color(0xFF0D2D7A),
              fontSize: sw * 0.072,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
              letterSpacing: 0.5,
              shadows: const [
                Shadow(
                  color: Colors.white54,
                  offset: Offset(0, 1),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
