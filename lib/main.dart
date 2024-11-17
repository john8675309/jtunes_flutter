import 'dart:ffi';
import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'libgpod_bridge.dart';

void main() {
  // Initialize Flutter app
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'iTunes Clone',
      theme: ThemeData.dark(),
      home: const HomeScreen(),
    );
  }
}
