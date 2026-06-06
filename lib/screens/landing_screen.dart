import 'package:flutter/material.dart';

import '../ui/app_shell.dart';
import 'auth_screen.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        imageAsset: 'assets/images/home_bg_clean.png',
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact =
                  constraints.maxWidth < 420 || constraints.maxHeight < 650; // Adjust compact threshold as needed
              final logoSize = compact ? 75.0 : 92.0; // Adjust logo size for compact mode
              final titleWidth = constraints.maxWidth.clamp(240.0, 320.0); // Adjust title width for compact mode

              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 20 : 34,// Adjust horizontal padding for compact mode
                  vertical: compact ? 25 : 35,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - (compact ? 34 : 36), // Adjust for vertical padding
                  ),
                  child: Column( // Main column for logo, title, and button
                    children: [
                      Wrap(
                        spacing: 15,
                        runSpacing: 22,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        alignment: WrapAlignment.spaceBetween,
                        children: [
                          AppLogo(size: logoSize), // Use adjusted logo size
                          Row( // Row for title and subtitle
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GlassButton(
                                label: 'Log In',
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const AuthScreen( 
                                          initialTab: AuthTab.login),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 12),
                              GlassButton(
                                label: 'Sign Up',
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
                        ],
                      ),
                      SizedBox(height: compact ? 160 : 196),
                      Transform.rotate(
                        angle: -0.08,
                        child: Container(
                          width: titleWidth,
                          padding: EdgeInsets.symmetric(
                            horizontal: compact ? 20 : 28,
                            vertical: compact ? 34 : 46,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: Colors.black, width: 2.2),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black54,
                                offset: Offset(10, 10),
                                blurRadius: 0,
                              ),
                              BoxShadow(
                                color: Color(0x8839D8E8),
                                spreadRadius: 2,
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: Transform.rotate(
                            angle: 0.08,
                            child: Text(
                              'Talk with\nHands',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: compact ? 34 : 42,
                                height: 1.02,
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w900,
                                color: Colors.black,
                                shadows: const [
                                  Shadow(
                                    color: Color(0x55000000),
                                    offset: Offset(0, 6),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: compact ? 68 : 120),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
