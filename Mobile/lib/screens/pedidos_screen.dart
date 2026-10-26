import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api.dart';
import '../api/tempo_real.dart';
import '../models/auth.dart';
import '../models/oferta.dart';
import '../models/pedido.dart';
import '../theme.dart';
import '../widgets/oferta_widgets.dart';
import '../widgets/xepa_logo.dart';
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
    final andamento = pedidos?.where((p) => p.status.emAndamento).toList() ?? [];
    final anteriores = pedidos?.where((p) => !p.status.emAndamento).toList() ?? [];
    return SafeArea(
      child: RefreshIndicator(
        color: XepaCores.tomate,
        onRefresh: carregar,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            const Text('Meus pedidos', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.6)),
            const SizedBox(height: 8),
            if (_erro != null)
              EstadoVazio(titulo: 'Não deu para carregar', texto: _erro, acao: 'Tentar de novo', onAcao: carregar)
            else if (pedidos == null)
              const Padding(padding: EdgeInsets.all(40), child: TomateCarregando())
            else if (pedidos.isEmpty)
              const EstadoVazio(
                titulo: 'Nenhum pedido ainda',
                texto: 'Que tal salvar uma sacola hoje? Tem comida boa esperando perto de você.',
              )
            else ...[
              if (andamento.isNotEmpty) ...[
                const _Secao('Em andamento'),
                for (final p in andamento) _CartaoPedido(pedido: p, onTap: () => _abrir(p)),
              ],
              if (anteriores.isNotEmpty) ...[
                const _Secao('Anteriores'),
                for (final p in anteriores) _CartaoPedido(pedido: p, onTap: () => _abrir(p)),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _Secao extends StatelessWidget {
  const _Secao(this.titulo);

  final String titulo;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 10),
        child: Text(titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      );
}

class _CartaoPedido extends StatelessWidget {
  const _CartaoPedido({required this.pedido, required this.onTap});

  final Pedido pedido;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = pedido;
    final d = p.criadoEm;
    final data = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(XepaRaios.cartao),
        border: Border.all(color: XepaCores.borda),
        boxShadow: sombraCartao,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(XepaRaios.cartao),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox.square(
                    dimension: 60,
                    child: FotoOferta(url: p.fotoUrl, categoria: Categoria.padaria, tamanhoIcone: 26),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.loja, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                      Text('${p.quantidade}x ${p.oferta} · $data',
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: XepaCores.textoSecundario, fontSize: 12.5)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: p.status.cor.withAlpha(24),
                          borderRadius: BorderRadius.circular(XepaRaios.pilula),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(p.status.icone, size: 13, color: p.status.cor),
                            const SizedBox(width: 4),
                            Text(p.status.rotulo,
                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: p.status.cor)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(formatarPreco(p.valorTotal), style: const TextStyle(fontWeight: FontWeight.w800)),
              ],
            ),
          ),
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
    final nome = u?.nome ?? '';
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          const Text('Perfil', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.6)),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(XepaRaios.cartao),
            child: Container(
              color: XepaCores.tomate,
              child: Stack(
                children: [
                  const Positioned(
                    right: -20,
                    top: -24,
                    child: TomateMarcaDagua(tamanho: 120, opacidade: 0.15, angulo: 0.3, cor: Colors.white),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.white,
                          child: Text(nome.isEmpty ? '?' : nome[0].toUpperCase(),
                              style: const TextStyle(color: XepaCores.tomate, fontSize: 22, fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(nome, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                              Text(u?.email ?? '', style: TextStyle(color: Colors.white.withAlpha(220), fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(XepaRaios.cartao),
              border: Border.all(color: XepaCores.borda),
            ),
            child: Column(
              children: [
                if (u?.telefone != null)
                  ListTile(leading: const Icon(Icons.phone_outlined), title: Text(u!.telefone!)),
                ListTile(
                  leading: const Icon(Icons.logout_rounded, color: XepaCores.tomateEscuro),
                  title: const Text('Sair', style: TextStyle(color: XepaCores.tomateEscuro, fontWeight: FontWeight.w800)),
                  onTap: () => _sair(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const Center(child: XepaMarca(tamanho: 20)),
          const SizedBox(height: 4),
          const Center(
            child: Text('Comida boa não vai pro lixo', style: TextStyle(color: XepaCores.textoSecundario, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
