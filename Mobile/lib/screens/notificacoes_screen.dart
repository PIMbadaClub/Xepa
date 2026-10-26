import 'package:flutter/material.dart';

import '../api/api.dart';
import '../api/notificacoes.dart';
import '../models/oferta.dart';
import '../models/pedido.dart';
import '../theme.dart';
import '../widgets/oferta_widgets.dart';
import '../widgets/pedido_ativo.dart';
import '../widgets/xepa_logo.dart';
import 'detalhe_screen.dart';

/// Abre o que a notificação aponta: o pedido (pagamento ou acompanhamento) ou a oferta da loja favorita.
Future<void> abrirNotificacao(BuildContext context, Notificacao n) async {
  final navegador = Navigator.of(context);
  final mensagens = ScaffoldMessenger.of(context);
  try {
    if (n.pedidoId != null) {
      final p = Pedido.fromJson(await Api.instance.get<Map<String, dynamic>>('/api/pedidos/${n.pedidoId}'));
      if (context.mounted) await abrirPedido(context, p);
    } else if (n.ofertaId != null) {
      final o = Oferta.fromJson(await Api.instance.get<Map<String, dynamic>>('/api/ofertas/${n.ofertaId}'));
      await navegador.push(MaterialPageRoute(builder: (_) => DetalheScreen(oferta: o)));
    }
  } on ApiException catch (e) {
    mensagens.showSnackBar(SnackBar(content: Text(e.status == 404 ? 'Essa oferta já saiu do ar.' : e.mensagem)));
  }
}

class NotificacoesScreen extends StatefulWidget {
  const NotificacoesScreen({super.key});

  @override
  State<NotificacoesScreen> createState() => _NotificacoesScreenState();
}

class _NotificacoesScreenState extends State<NotificacoesScreen> {
  /// Ids não lidos quando a tela abriu: continuam destacados até sair, mesmo depois de marcar como lidas.
  Set<String> _destacadas = {};
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _abrir();
  }

  Future<void> _abrir() async {
    await Notificacoes.instance.carregar();
    if (!mounted) return;
    setState(() {
      _destacadas = Notificacoes.instance.itens.value.where((n) => !n.lida).map((n) => n.id).toSet();
      _carregando = false;
    });
    Notificacoes.instance.marcarLidas();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notificações')),
      body: ValueListenableBuilder<List<Notificacao>>(
        valueListenable: Notificacoes.instance.itens,
        builder: (context, itens, _) {
          if (_carregando && itens.isEmpty) {
            return const Center(child: TomateCarregando());
          }
          if (itens.isEmpty) {
            return const Center(
              child: EstadoVazio(
                titulo: 'Tudo tranquilo por aqui',
                texto: 'Os avisos dos seus pedidos, as respostas de denúncia e as ofertas das lojas favoritas aparecem aqui.',
              ),
            );
          }

          final hoje = DateTime.now();
          bool ehHoje(DateTime d) => d.year == hoje.year && d.month == hoje.month && d.day == hoje.day;
          final deHoje = itens.where((n) => ehHoje(n.em)).toList();
          final antes = itens.where((n) => !ehHoje(n.em)).toList();

          return RefreshIndicator(
            color: XepaCores.tomate,
            onRefresh: Notificacoes.instance.carregar,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                if (deHoje.isNotEmpty) ...[
                  const _Secao('Hoje'),
                  for (final n in deHoje) _Item(notificacao: n, destacada: _destacadas.contains(n.id)),
                ],
                if (antes.isNotEmpty) ...[
                  const _Secao('Anteriores'),
                  for (final n in antes) _Item(notificacao: n, destacada: _destacadas.contains(n.id)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Secao extends StatelessWidget {
  const _Secao(this.titulo);

  final String titulo;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
        child: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w800, color: XepaCores.textoSecundario)),
      );
}

class _Item extends StatelessWidget {
  const _Item({required this.notificacao, required this.destacada});

  final Notificacao notificacao;
  final bool destacada;

  @override
  Widget build(BuildContext context) {
    final n = notificacao;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: destacada ? XepaCores.tomateClaro.withAlpha(140) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: destacada ? XepaCores.tomate.withAlpha(60) : XepaCores.borda),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => abrirNotificacao(context, n),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconeNotificacao(notificacao: n),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(n.titulo, style: const TextStyle(fontWeight: FontWeight.w800))),
                          Text(_quando(n.em), style: const TextStyle(color: XepaCores.textoSecundario, fontSize: 11.5)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(n.texto, style: const TextStyle(color: XepaCores.textoSecundario, fontSize: 13, height: 1.35)),
                    ],
                  ),
                ),
                if (destacada)
                  Container(
                    margin: const EdgeInsets.only(left: 8, top: 6),
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(color: XepaCores.tomate, shape: BoxShape.circle),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _quando(DateTime d) {
    final diferenca = DateTime.now().difference(d);
    if (diferenca.inMinutes < 1) return 'agora';
    if (diferenca.inMinutes < 60) return 'há ${diferenca.inMinutes} min';
    if (diferenca.inHours < 24) return 'há ${diferenca.inHours} h';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
  }
}
