import 'package:flutter/material.dart';
import 'screens/auth_screen.dart';
import 'theme/app_theme.dart';

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
      theme: AppTheme.lightTheme,
      home: const AuthScreen(),
    );
  }
}
