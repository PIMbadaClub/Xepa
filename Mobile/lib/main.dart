import 'package:flutter/material.dart';

import 'api/api.dart';
import 'screens/abertura_screen.dart';
import 'screens/login_screen.dart';
import 'theme.dart';

final navegador = GlobalKey<NavigatorState>();

void main() {
  // Se a renovação do token falhar (sessão de mais de 7 dias), volta para o login.
  Api.instance.aoExpirarSessao = () => navegador.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
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
      navigatorKey: navegador,
      home: const AberturaScreen(),
    );
  }
}