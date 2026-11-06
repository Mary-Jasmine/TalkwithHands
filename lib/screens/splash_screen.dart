import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/background_music_service.dart';
import '../ui/background_music_region.dart';
import 'admin_analytics_screen.dart';
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
  late final Animation<double> _logoJump;
  Future<void>? _routeFuture;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _logoJump = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0, end: -12)
            .chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -12, end: 0)
            .chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 50,
      ),
    ]).animate(_controller);

    _routeFuture = _goToFirstScreen();
  }

  Future<void> _goToFirstScreen() async {
    final hasSessionFuture = AuthService.hasStoredSession();
    final cachedProfileFuture = AuthService.cachedProfile();
    final meFuture = AuthService().me();
    await Future<void>.delayed(const Duration(milliseconds: 850));
    if (!mounted) return;

    final hasSession = await hasSessionFuture;
    final cachedProfile = await cachedProfileFuture;
    final me = await meFuture.timeout(
      const Duration(seconds: 8),
      onTimeout: () => cachedProfile,
    );
    if (!mounted) return;

    final profile = me ?? cachedProfile;
    final isAdmin =
        profile?.email?.trim().toLowerCase() == 'talkwithhands06@gmail.com';

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => !hasSession && profile == null
            ? const LandingScreen()
            : isAdmin
                ? AdminAnalyticsScreen(userName: profile?.username ?? 'Admin')
                : WelcomeScreen(userName: profile?.username ?? 'Student'),
      ),
    );
  }

  @override
  void dispose() {
    _routeFuture?.ignore();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BackgroundMusicRegion(
        track: BackgroundMusicTrack.page,
        showToggle: false,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Colors.black),
            _buildSplashContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildSplashContent() {
    return Center(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = math.min(constraints.maxWidth * 0.88, 420.0);
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => Transform.translate(
              offset: Offset(0, _logoJump.value),
              child: Image.asset(
                'assets/images/app_logo.png',
                width: width,
                fit: BoxFit.contain,
              ),
            ),
          );
        },
      ),
    );
  }
}
