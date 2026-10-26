import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api.dart';
import '../api/tempo_real.dart';
import '../models/oferta.dart';
import '../models/pedido.dart';
import '../theme.dart';
import '../widgets/oferta_widgets.dart';
import '../widgets/xepa_logo.dart';
import 'acompanhamento_screen.dart';
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
