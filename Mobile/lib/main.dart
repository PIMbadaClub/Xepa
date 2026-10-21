import 'package:flutter/material.dart';

import 'screens/login_screen.dart';
import 'theme.dart';

void main() {
  runApp(const XepaApp());
}

class XepaApp extends StatelessWidget {
  const XepaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Xepa',
      debugShowCheckedModeBanner: false,
      theme: xepaTema(),
      // Depois que o JWT estiver integrado, troque por uma tela que decide:
      // token válido -> HomeShell, sem token -> LoginScreen.
      home: const LoginScreen(),
    );
  }
}