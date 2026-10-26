import 'package:flutter/material.dart';

import '../models/auth.dart';
import '../theme.dart';
import '../widgets/xepa_logo.dart';
import 'entregador_screen.dart';
import 'home_shell.dart';
import 'login_screen.dart';

/// Tela inicial de cada perfil depois do login.
Widget telaInicialPara(Usuario usuario) =>
    usuario.perfil == PerfilUsuario.entregador ? const EntregadorScreen() : const HomeShell();

/// Abertura: com sessão salva vai direto para o app; sem sessão, para o login.
class AberturaScreen extends StatefulWidget {
  const AberturaScreen({super.key});

  @override
  State<AberturaScreen> createState() => _AberturaScreenState();
}

class _AberturaScreenState extends State<AberturaScreen> {
  @override
  void initState() {
    super.initState();
    AuthService.instance.restaurarSessao().then((usuario) {
      if (!mounted) return;
      final destino = usuario == null || usuario.perfil == PerfilUsuario.estabelecimento || usuario.perfil == PerfilUsuario.administrador
          ? const LoginScreen()
          : telaInicialPara(usuario);
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => destino));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const XepaLogo(tamanho: 84),
            const SizedBox(height: 14),
            const NomeXepa(altura: 58),
            const SizedBox(height: 4),
            const Text('Comida boa não vai pro lixo', style: TextStyle(color: XepaCores.textoSecundario)),
          ],
        ),
      ),
    );
  }
}
