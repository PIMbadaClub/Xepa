import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api.dart';
import '../api/tempo_real.dart';
import '../models/auth.dart';
import '../models/pedido.dart';
import '../theme.dart';
import 'acompanhamento_screen.dart';
import 'login_screen.dart';
import 'pagamento_screen.dart';

/// Aba Pedidos: histórico do cliente, atualizado em tempo real.
class PedidosScreen extends StatefulWidget {
  const PedidosScreen({super.key});

  @override
  State<PedidosScreen> createState() => PedidosScreenState();
}

class PedidosScreenState extends State<PedidosScreen> {
  List<Pedido>? _pedidos;
  String? _erro;
  StreamSubscription<Map<String, dynamic>>? _avisos;

  @override
  void initState() {
    super.initState();
    _avisos = TempoReal.instance.pedidoAlterado.listen((_) => carregar());
    carregar();
  }

  @override
  void dispose() {
    _avisos?.cancel();
    super.dispose();
  }

  Future<void> carregar() async {
    try {
      final lista = await Api.instance.get<List<dynamic>>('/api/pedidos');
      if (mounted) {
        setState(() {
          _pedidos = lista.map((j) => Pedido.fromJson(j as Map<String, dynamic>)).toList();
          _erro = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    }
  }

  Future<void> _abrir(Pedido p) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => p.status == StatusPedido.aguardandoPagamento
          ? PagamentoScreen(pedido: p)
          : AcompanhamentoScreen(pedidoId: p.id),
    ));
    carregar();
  }

  @override
  Widget build(BuildContext context) {
    final pedidos = _pedidos;
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: carregar,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Meus pedidos', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            if (_erro != null)
              Text(_erro!, style: const TextStyle(color: XepaCores.tomateEscuro))
            else if (pedidos == null)
              const Center(child: CircularProgressIndicator())
            else if (pedidos.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Text('Você ainda não fez pedidos. Que tal salvar uma sacola hoje?',
                    textAlign: TextAlign.center, style: TextStyle(color: XepaCores.textoSecundario)),
              )
            else
              for (final p in pedidos)
                Card(
                  color: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: XepaCores.borda)),
                  child: ListTile(
                    onTap: () => _abrir(p),
                    leading: Icon(p.status.icone, color: p.status.cor),
                    title: Text('${p.quantidade}x ${p.oferta}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('${p.loja} · ${p.status.rotulo}'),
                    trailing: Text(formatarPreco(p.valorTotal), style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

/// Aba Perfil: dados da conta e sair.
class PerfilScreen extends StatelessWidget {
  const PerfilScreen({super.key});

  Future<void> _sair(BuildContext context) async {
    await AuthService.instance.sair();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = AuthService.instance.usuario;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Perfil', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          ListTile(leading: const Icon(Icons.person_outline), title: Text(u?.nome ?? ''), subtitle: Text(u?.email ?? '')),
          if (u?.telefone != null) ListTile(leading: const Icon(Icons.phone_outlined), title: Text(u!.telefone!)),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: XepaCores.tomateEscuro),
            title: const Text('Sair', style: TextStyle(color: XepaCores.tomateEscuro, fontWeight: FontWeight.w700)),
            onTap: () => _sair(context),
          ),
        ],
      ),
    );
  }
}
