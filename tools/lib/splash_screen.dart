import 'dart:async';
import 'package:flutter/material.dart';
import 'package:tools/auth/login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _displayedText = '';
  final String _fullText = 'Audit Tools';
  int _textIndex = 0;
  bool _showCursor = true; // Cursor blinking effect

  @override
  void initState() {
    super.initState();
    _startTypingEffect();

    // Pindah ke Login setelah 3 detik
    Timer(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    });
  }

  void _startTypingEffect() {
    Timer.periodic(const Duration(milliseconds: 150), (timer) {
      if (_textIndex < _fullText.length) {
        setState(() {
          _displayedText += _fullText[_textIndex];
          _textIndex++;
        });
      } else {
        timer.cancel();
      }
    });

    // Blink cursor effect
    Timer.periodic(const Duration(milliseconds: 500), (timer) {
      setState(() {
        _showCursor = !_showCursor;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(color: Colors.white),
        child: Center(
          child: TweenAnimationBuilder(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(seconds: 1),
            builder: (context, double opacity, child) {
              return Opacity(
                opacity: opacity,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      _displayedText,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueAccent,
                        letterSpacing: 2,
                        shadows: [
                          Shadow(
                            blurRadius: 10.0,
                            color: Color.fromARGB(255, 106, 191, 255),
                            offset: Offset(2.0, 2.0),
                          ),
                        ],
                      ),
                    ),
                    // Cursor blinking effect
                    if (_showCursor)
                      Positioned(
                        right: -10,
                        child: const Text(
                          '|',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Color.fromARGB(255, 82, 76, 76),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
