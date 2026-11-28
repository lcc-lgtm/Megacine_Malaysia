import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/auth_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF121110),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const MegacineApp());
}

class MegacineApp extends StatelessWidget {
  const MegacineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Megacine Malaysia',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const AuthScreen(),
    );
  }
}
