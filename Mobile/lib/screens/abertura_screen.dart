import 'package:flutter/material.dart';

import '../api/api.dart';
import '../api/endereco_pagina.dart';
import '../api/modo.dart';
import '../api/notificacoes.dart';
import '../api/retorno_google.dart';
import '../models/auth.dart';
import '../theme.dart';
import '../widgets/xepa_logo.dart';
import 'entregador_screen.dart';
import 'home_shell.dart';
import 'login_screen.dart';

/// Tela inicial de cada perfil depois do login. O entregador abre no modo em que estava (entregar ou pedir comida).
Widget telaInicialPara(Usuario usuario) =>
    usuario.perfil == PerfilUsuario.entregador && !ModoApp.cliente ? const EntregadorScreen() : const HomeShell();

/// Entregador troca entre entregar corridas e pedir comida, com a mesma conta.
Future<void> trocarModoEntregador(BuildContext context, {required bool cliente}) async {
  final navegador = Navigator.of(context, rootNavigator: true);
  if (cliente) {
    // Quem vai pedir comida para de receber corridas; a corrida já aceita continua com ele.
    try {
      await Api.instance.put<Map<String, dynamic>>('/api/entregador/online', {'online': false});
    } on ApiException {
      // Troca de modo mesmo assim.
    }
  } else {
    Notificacoes.instance.parar();
    PedidosAtivos.instance.parar();
  }
  await ModoApp.definir(cliente: cliente);
  navegador.pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => cliente ? const HomeShell() : const EntregadorScreen()),
    (_) => false,
  );
}

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
    _iniciar();
  }

  Future<void> _iniciar() async {
    await ModoApp.carregar();
    final parametros = await RetornoGoogle.parametrosIniciais();
    final codigoGoogle = parametros['google'];
    final erroGoogle = parametros['google_erro'];
    if (codigoGoogle != null || erroGoogle != null) EnderecoPagina.limparParametros();

    Usuario? usuario;
    String? erro = erroGoogle;
    if (codigoGoogle != null) {
      try {
        usuario = await AuthService.instance.entrarComGoogle(codigoGoogle);
      } on AuthException catch (e) {
        erro = e.mensagem;
      }
    }
    usuario ??= await AuthService.instance.restaurarSessao();
    if (!mounted) return;
    if (usuario == null && erro != null) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => LoginScreen(erroInicial: erro)));
      return;
    }
    final destino = usuario == null || usuario.perfil == PerfilUsuario.estabelecimento || usuario.perfil == PerfilUsuario.administrador
        ? const LoginScreen()
        : telaInicialPara(usuario);
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => destino));
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
