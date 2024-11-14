import 'dart:ffi';
import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'libgpod_bridge.dart';

void main() {
  // Initialize Flutter app
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'iTunes Clone',
      theme: ThemeData.dark(),
      home: HomeScreen(),
    );
  }
}
