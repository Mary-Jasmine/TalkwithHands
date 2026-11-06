import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/background_music_service.dart';
import '../ui/background_music_region.dart';
import '../widgets/transparent_sign_video_overlay.dart';
import 'progress_screen.dart';

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
    final topPad = MediaQuery.paddingOf(context).top;
    final sw = MediaQuery.sizeOf(context).width;
    final sh = MediaQuery.sizeOf(context).height;

    return Scaffold(
      body: BackgroundMusicRegion(
        track: BackgroundMusicTrack.page,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Background ─────────────────────────────────────────────────
            Image.asset(
              'assets/images/home_bg_clean.png',
              fit: BoxFit.cover,
              width: sw,
              height: sh,
            ),

            // ── Brand logo centered at the top ────────────────────────────
            Positioned(
              top: topPad + 4,
              left: 0,
              right: 0,
              child: Center(
                child: Image.asset(
                  'assets/images/app_logo.png',
                  width: 200,
                  height: 108,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.sign_language_rounded,
                    color: Color(0xFF10213A),
                    size: 40,
                  ),
                ),
              ),
            ),

            // ── "Kumusta ka," ───────────────────────────────────────────
            Positioned(
              top: sh * 0.15 + topPad,
              left: 22,
              right: 22,
              child: Center(
                child: Text(
                  'Kumusta ka,',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poetsenOne(
                    color:const Color(0xFFFFE45E),
                    fontSize: sw * 0.090,
                    shadows: const [
                      Shadow(
                        color: Color(0xAA061B36),
                        offset: Offset(-1, -1),
                        blurRadius: 9,
                      ),
                      Shadow(
                        color: Color(0xEE061B36),
                        offset: Offset(2, 3),
                        blurRadius: 5,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── "[Name]!" ──────────────────────────────────────────────────
            Positioned(
              top: sh * 0.195 + topPad,
              left: 22,
              right: 22,
              child: Center(
                child: Text(
                  '$_firstName!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poetsenOne(
                    color: const Color.fromARGB(255, 121, 246, 255),
                    fontSize: sw * 0.120,
                    fontStyle: FontStyle.italic,
                    shadows: const [
                      Shadow(
                        color: Color.fromARGB(235, 2, 2, 2),
                        offset: Offset(-1, -1),
                        blurRadius: 9,
                      ),
                      Shadow(
                        color: Color.fromARGB(237, 56, 56, 56),
                        offset: Offset(2, 3),
                        blurRadius: 5,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Speech bubble ──────────────────────────────────────────────
            Positioned(
              top: sh * 0.32 + topPad,
              left: 0,
              right: 2,
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: sw * 0.84),
                  child: Transform.rotate(
                    angle: -5 * 3.14159265 / 180,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: sw * 0.09,
                            vertical: sh * 0.015,
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
                              fontSize: sw * 0.034,
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
              ),
            ),

            // ── Transparent sign video overlay ─────────────────────────────
            Positioned(
              top: sh * 0.48,
              left: 0,
              right: 0,
              bottom: sh * 0.165,
              child: const TransparentSignVideoOverlay(
                fit: BoxFit.cover,
                edgeCrop: 0.04,
                verticalCrop: 0.18,
              ),
            ),

            // ── Start button ───────────────────────────────────────────────
            Positioned(
              bottom: sh * 0.095,
              left: 0,
              right: 0,
              child: Center(
                child: _StartButton(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ProgressScreen(userName: userName),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
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

// ── Start button ──────────────────────────────────────────────────────────────
class _StartButton extends StatelessWidget {
  final VoidCallback onTap;
  const _StartButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        splashColor: Colors.white38,
        child: Image.asset(
          'assets/images/star.png',
          width: 132,
          height: 132,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}