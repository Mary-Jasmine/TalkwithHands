import 'package:flutter/material.dart';

class SignDetectorScreen extends StatelessWidget {
  const SignDetectorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1387C9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D567E),
        foregroundColor: Colors.white,
        title: const Text('Sign to Text'),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Sign detection uses the device camera and is available in the Android app.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
