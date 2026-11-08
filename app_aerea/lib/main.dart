import 'package:flutter/material.dart';
import 'config/app_theme.dart';
import 'pages/login_page.dart';

void main() {
  runApp(const AeroTechApp());
}

class AeroTechApp extends StatelessWidget {
  const AeroTechApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AeroTech Reservas',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const LoginPage(),
    );
  }
}
