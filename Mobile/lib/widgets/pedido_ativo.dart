import 'package:flutter/material.dart';

import '../api/notificacoes.dart';
import '../models/oferta.dart';
import '../models/pedido.dart';
import '../screens/acompanhamento_screen.dart';
import '../screens/pagamento_screen.dart';
import '../theme.dart';
import 'oferta_widgets.dart';

/// Abre a tela certa de um pedido: pagamento enquanto não pago, acompanhamento depois.
Future<void> abrirPedido(BuildContext context, Pedido p) => Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => p.status == StatusPedido.aguardandoPagamento
          ? PagamentoScreen(pedido: p)
          : AcompanhamentoScreen(pedidoId: p.id),
    ));

/// Barra fixa acima do menu com o pedido em andamento mais recente (e quantos outros existem).
class BarraPedidoAtivo extends StatelessWidget {
  const BarraPedidoAtivo({super.key, required this.onAbrir});

  /// Quem abre o pedido é o shell, na navegação da aba atual (o menu de baixo continua visível).
  final Future<void> Function(Pedido) onAbrir;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<Pedido>>(
      valueListenable: PedidosAtivos.instance.pedidos,
      builder: (context, pedidos, _) {
        if (pedidos.isEmpty) return const SizedBox.shrink();
        final p = pedidos.first;
        final etapa = _etapa(p);
        return Material(
          color: Colors.white,
          child: InkWell(
            onTap: () => onAbrir(p),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: XepaCores.borda))),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox.square(dimension: 40, child: _Pulsante(ativo: etapa.$2, child: Icon(p.status.icone, color: Colors.white, size: 20))),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.status.rotuloPara(entrega: p.entrega),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                            ),
                            Text(
                              [
                                '#${p.id} · ${p.loja}',
                                if (pedidos.length > 1) '+${pedidos.length - 1} em andamento',
                              ].join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: XepaCores.textoSecundario, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      if (p.status == StatusPedido.aguardandoPagamento)
                        const _Chip(texto: 'Pagar', cor: XepaCores.tomate)
                      else if (p.codigoRetirada != null &&
                          ((!p.entrega && p.status == StatusPedido.prontoParaRetirada) || p.status == StatusPedido.saiuParaEntrega))
                        _Chip(texto: p.codigoRetirada!, cor: XepaCores.verde)
                      else
                        const Icon(Icons.chevron_right_rounded, color: XepaCores.textoSecundario),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(XepaRaios.pilula),
                    child: LinearProgressIndicator(
                      value: etapa.$1,
                      minHeight: 4,
                      backgroundColor: XepaCores.borda,
                      color: XepaCores.tomate,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Progresso (0 a 1) e se a etapa está "acontecendo" (para o ícone pulsar).
  static (double, bool) _etapa(Pedido p) => switch (p.status) {
        StatusPedido.aguardandoPagamento => (0.08, false),
        StatusPedido.pendente => (0.25, true),
        StatusPedido.confirmado => (0.45, false),
        StatusPedido.emPreparo => (0.65, true),
        StatusPedido.prontoParaRetirada => (p.entrega ? 0.75 : 0.85, true),
        StatusPedido.saiuParaEntrega => (0.9, true),
        _ => (1, false),
      };
}

class _Chip extends StatelessWidget {
  const _Chip({required this.texto, required this.cor});

  final String texto;
  final Color cor;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: cor, borderRadius: BorderRadius.circular(XepaRaios.pilula)),
        child: Text(texto, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 1)),
      );
}

/// Fundo vermelho que pulsa devagar enquanto a etapa está em andamento.
class _Pulsante extends StatefulWidget {
  const _Pulsante({required this.ativo, required this.child});

  final bool ativo;
  final Widget child;

  @override
  State<_Pulsante> createState() => _PulsanteState();
}

class _PulsanteState extends State<_Pulsante> with SingleTickerProviderStateMixin {
  late final _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void initState() {
    super.initState();
    if (widget.ativo) _anim.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_Pulsante antigo) {
    super.didUpdateWidget(antigo);
    if (widget.ativo && !_anim.isAnimating) {
      _anim.repeat(reverse: true);
    } else if (!widget.ativo) {
      _anim.stop();
      _anim.value = 0;
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _anim,
        builder: (_, filho) => ColoredBox(
          color: Color.lerp(XepaCores.tomate, XepaCores.tomateEscuro, _anim.value)!,
          child: Center(child: filho),
        ),
        child: widget.child,
      );
}

/// Aviso que desce do topo quando chega uma notificação com o app aberto.
class AvisoNoTopo {
  static OverlayEntry? _atual;

  static void mostrar(BuildContext context, Notificacao n, {VoidCallback? onTap}) {
    _atual?.remove();
    final overlay = Overlay.of(context);
    late OverlayEntry entrada;
    entrada = OverlayEntry(
      builder: (_) => _Aviso(
        notificacao: n,
        onTap: () {
          entrada.remove();
          if (_atual == entrada) _atual = null;
          onTap?.call();
        },
        onFim: () {
          if (entrada.mounted) entrada.remove();
          if (_atual == entrada) _atual = null;
        },
      ),
    );
    _atual = entrada;
    overlay.insert(entrada);
  }
}

class _Aviso extends StatefulWidget {
  const _Aviso({required this.notificacao, required this.onTap, required this.onFim});

  final Notificacao notificacao;
  final VoidCallback onTap;
  final VoidCallback onFim;

  @override
  State<_Aviso> createState() => _AvisoState();
}

class _AvisoState extends State<_Aviso> with SingleTickerProviderStateMixin {
  late final _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 280));

  @override
  void initState() {
    super.initState();
    _anim.forward();
    Future.delayed(const Duration(seconds: 5), () async {
      if (!mounted) return;
      await _anim.reverse();
      widget.onFim();
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.notificacao;
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 8,
      left: 12,
      right: 12,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, -1.4), end: Offset.zero)
            .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutBack)),
        child: Material(
          color: Colors.white,
          elevation: 8,
          shadowColor: Colors.black26,
          borderRadius: BorderRadius.circular(XepaRaios.cartao),
          child: InkWell(
            borderRadius: BorderRadius.circular(XepaRaios.cartao),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  IconeNotificacao(notificacao: n),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(n.titulo, style: const TextStyle(fontWeight: FontWeight.w800)),
                        Text(n.texto,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: XepaCores.textoSecundario, fontSize: 12.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ícone redondo de cada notificação (status do pedido, denúncia ou oferta de favorita).
class IconeNotificacao extends StatelessWidget {
  const IconeNotificacao({super.key, required this.notificacao, this.tamanho = 42});

  final Notificacao notificacao;
  final double tamanho;

  @override
  Widget build(BuildContext context) {
    final n = notificacao;
    final (icone, cor, fundo) = switch (n.tipo) {
      TipoNotificacao.denuncia => (Icons.flag_rounded, XepaCores.paoEscuro, XepaCores.pao),
      TipoNotificacao.ofertaFavorita => (Icons.favorite_rounded, XepaCores.tomate, XepaCores.tomateClaro),
      TipoNotificacao.pedido => switch (n.status) {
          StatusPedido.entregue => (Icons.check_rounded, XepaCores.verde, XepaCores.verdeClaro),
          StatusPedido.cancelado => (Icons.close_rounded, XepaCores.textoSecundario, XepaCores.bege),
          final s? => (s.icone, XepaCores.tomate, XepaCores.tomateClaro),
          null => (Icons.shopping_bag_outlined, XepaCores.tomate, XepaCores.tomateClaro),
        },
    };
    return Container(
      width: tamanho,
      height: tamanho,
      decoration: BoxDecoration(color: fundo, shape: BoxShape.circle),
      child: Icon(icone, color: cor, size: tamanho * 0.5),
    );
  }
}

/// Foto pequena e quadrada do pedido (usada nas listas).
class MiniaturaPedido extends StatelessWidget {
  const MiniaturaPedido({super.key, required this.pedido, this.tamanho = 52});

  final Pedido pedido;
  final double tamanho;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox.square(
          dimension: tamanho,
          child: FotoOferta(url: pedido.fotoUrl, categoria: Categoria.padaria, tamanhoIcone: tamanho * 0.45),
        ),
      );
}
