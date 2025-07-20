import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:tools/auth/login_screen.dart';
import 'package:tools/splash_screen.dart'; // Tambahkan ini

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  try {
    await Firebase.initializeApp();
  } catch (e) {
    print("Error initializing Firebase: $e");
    return;
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Define your blue accent color scheme here
        colorScheme: ColorScheme.light(
          primary: Colors.blueAccent, // Primary color (blue accent)
          onPrimary: Colors.white, // Text/icons on primary color
          secondary: Colors.greenAccent, // Secondary color
          onSecondary: Colors.white, // Text/icons on secondary color
          error: Colors.red, // Error color
          onError: Colors.white, // Text/icons on error color
          surface: Colors.white, // Surface color (like cards)
          onSurface: Colors.black, // Text/icons on surface color
        ),
      ),
      home: const SplashScreen(), // <-- Splash screen first
    );
  }
}
