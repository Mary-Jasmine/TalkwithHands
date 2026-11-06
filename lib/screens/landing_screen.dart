import 'package:flutter/material.dart';

import '../services/background_music_service.dart';
import '../ui/background_music_region.dart';
import '../ui/app_shell.dart';
import 'auth_screen.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BackgroundMusicRegion(
        track: BackgroundMusicTrack.page,
        child: AppBackground(
          imageAsset: 'assets/images/home_bg_clean.png',
          child: SafeArea(
          top: false,
          bottom: false,
          left: false,
          right: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact =
                  constraints.maxWidth < 420 || constraints.maxHeight < 650; // Adjust compact threshold as needed
              final titleWidth = constraints.maxWidth.clamp(240.0, 320.0); // Adjust title width for compact mode

              return Container(
                width: double.infinity,
                height: constraints.maxHeight,
                decoration: BoxDecoration(
                  color: const Color.fromARGB(179, 4, 18, 35),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.38),
                    width: 2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x55061B36),
                      blurRadius: 24,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: 0,
                    vertical: compact ? 75 : 35,
                  ),
                  child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - (compact ? 39 : 41), // Adjust for vertical padding
                  ),
                  child: Column( // Main column for logo, title, and button
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(compact ? 14 : 7),
                        child: Image.asset(
                          'assets/images/app_logo.png',
                          width: titleWidth,
                          height: titleWidth * 0.76,
                          fit: BoxFit.contain,
                        ),
                      ),
                      SizedBox(height: compact ? 48 : 40),
                      // Transform.translate moves ONLY the buttons down
                      // (title box and logo stay in place). Change 40 to adjust.
                      Transform.translate(
                        offset: Offset(0, compact ? 30 : 40),
                        child:
                        Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _LandingPillButton(
                            label: 'Login',
                            gradientColors: const [
                              Color(0xFF087FEA),
                              Color(0xFF073AA8),
                            ],
                            borderColor: const Color(0xFF36C9FF),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const AuthScreen(
                                      initialTab: AuthTab.login),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 30),
                          _LandingPillButton(
                            label: 'Sign in',
                            gradientColors: const [
                              Color.fromARGB(255, 247, 45, 139),
                              Color.fromARGB(255, 161, 1, 75),
                            ],
                            borderColor: const Color.fromARGB(255, 239, 139, 187),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const AuthScreen(
                                      initialTab: AuthTab.register),
                                ),
                              );
                            },
                          ),
                        ],
                        ),
                      ),
                      SizedBox(height: compact ? 68 : 120),
                    ],
                  ),
                ),
                ),
              );
            },
          ),
          ),
        ),
      ),
    );
  }
}

class _LandingPillButton extends StatelessWidget {
  final String label;
  final List<Color> gradientColors;
  final Color? borderColor;
  final VoidCallback onTap;

  const _LandingPillButton({
    required this.label,
    required this.gradientColors,
    required this.onTap,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors,
            ),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              if (borderColor != null)
                BoxShadow(
                  color: borderColor!.withValues(alpha: 0.9),
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              const BoxShadow(
                color: Color(0xDD00102E),
                blurRadius: 14,
                spreadRadius: 1,
                offset: Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              shadows: [
                Shadow(
                  color: Color(0xCC001B36),
                  blurRadius: 5,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
