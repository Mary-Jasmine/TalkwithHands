import 'dart:async';

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../ui/app_shell.dart';
import 'landing_screen.dart';
import 'welcome_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoScale;
  late final Animation<Offset> _textOffset;
  late final Animation<double> _textOpacity;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..forward();

    _logoScale = Tween<double>(begin: 0.72, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _textOffset = Tween<Offset>(
      begin: const Offset(-0.4, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.42, 1, curve: Curves.easeOutCubic),
      ),
    );
    _textOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.5, 1, curve: Curves.easeOut),
    );

    _timer = Timer(const Duration(milliseconds: 2600), () async {
      if (!mounted) return;
      final me = await AuthService().me();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => me == null
              ? const LandingScreen()
              : WelcomeScreen(userName: me.username ?? 'Student'),
        ),
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 500;
              final logoSize = constraints.maxWidth < 360 ? 92.0 : 110.0;
              final textSize = constraints.maxWidth < 360 ? 30.0 : 40.0;

              return AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final logo = Transform.scale(
                    scale: _logoScale.value,
                    child: AppLogo(size: logoSize),
                  );
                  final title = FadeTransition(
                    opacity: _textOpacity,
                    child: SlideTransition(
                      position: _textOffset,
                      child: Text(
                        'Talk with Hands',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: textSize,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Georgia',
                          shadows: const [
                            Shadow(
                              color: Color(0x77000000),
                              offset: Offset(0, 6),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );

                  if (stacked) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        logo,
                        const SizedBox(height: 16),
                        title,
                      ],
                    );
                  }

                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      logo,
                      const SizedBox(width: 18),
                      title,
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}