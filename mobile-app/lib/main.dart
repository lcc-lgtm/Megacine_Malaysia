import 'package:flutter/material.dart';
import 'screens/auth_screen.dart';

void main() {
  runApp(const MegacineApp());
}

class MegacineApp extends StatelessWidget {
  const MegacineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Megacine Malaysia',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent, brightness: Brightness.dark),
      ),
      home: const AuthScreen(),
    );
  }
}
