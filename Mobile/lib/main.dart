import 'package:flutter/material.dart';

import 'screens/home_shell.dart';
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
      home: const HomeShell(),
    );
  }
}
