import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../api/api.dart';
import '../api/tempo_real.dart';
import '../models/oferta.dart';
import '../models/pedido.dart';
import '../theme.dart';
import '../widgets/denuncia_widgets.dart';
import '../widgets/mapa_entrega.dart';
import '../widgets/oferta_widgets.dart';
import '../widgets/xepa_logo.dart';

/// Acompanhamento do pedido: status em tempo real, código de retirada e mapa da entrega.
class AcompanhamentoScreen extends StatefulWidget {
  const AcompanhamentoScreen({super.key, required this.pedidoId});

  final int pedidoId;

  @override
  State<AcompanhamentoScreen> createState() => _AcompanhamentoScreenState();
}

class _AcompanhamentoScreenState extends State<AcompanhamentoScreen> {
  Pedido? _pedido;
  LatLng? _loja, _destino, _entregador;
  List<LatLng> _rota = [];
  String? _nomeEntregador;
  String? _erro;
  final _assinaturas = <StreamSubscription<Map<String, dynamic>>>[];

  @override
  void initState() {
    super.initState();
    _assinaturas
      ..add(TempoReal.instance.pedidoAlterado.where((e) => e['pedidoId'] == widget.pedidoId).listen((_) => _carregar()))
      ..add(TempoReal.instance.posicaoEntregador.where((e) => e['pedidoId'] == widget.pedidoId).listen((e) {
        if (mounted) {
          setState(() => _entregador = LatLng((e['latitude'] as num).toDouble(), (e['longitude'] as num).toDouble()));
        }
      }));
    TempoReal.instance.acompanharPedido(widget.pedidoId);
    _carregar();
  }

  @override
  void dispose() {
    for (final a in _assinaturas) {
      a.cancel();
    }
    super.dispose();
  }

  Future<void> _carregar() async {
    try {
      final pedido = Pedido.fromJson(await Api.instance.get<Map<String, dynamic>>('/api/pedidos/${widget.pedidoId}'));
      final r = await Api.instance.get<Map<String, dynamic>>('/api/pedidos/${widget.pedidoId}/rastreio');
      LatLng? ponto(Object? j) => j is Map ? LatLng((j['latitude'] as num).toDouble(), (j['longitude'] as num).toDouble()) : null;
      if (!mounted) return;
      setState(() {
        _pedido = pedido;
        _loja = ponto(r['loja']);
        _destino = ponto(r['destino']);
        _entregador = ponto(r['entregador']) ?? _entregador;
        _rota = r['rota'] is List ? (r['rota'] as List).map(ponto).whereType<LatLng>().toList() : [];
        _nomeEntregador = r['nomeEntregador'] as String?;
        final placa = r['placaEntregador'] as String?;
        if (_nomeEntregador != null && placa != null) _nomeEntregador = '$_nomeEntregador (moto $placa)';
        _erro = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    }
  }

  Future<void> _cancelar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Cancelar pedido?'),
        content: const Text('Se você já pagou, o valor é estornado.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Voltar')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Cancelar pedido')),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await Api.instance.post<Map<String, dynamic>>('/api/pedidos/${widget.pedidoId}/cancelar');
      await _carregar();
    } on ApiException catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _pedido;
    return Scaffold(
      appBar: AppBar(title: Text('Pedido #${widget.pedidoId}')),
      body: p == null
          ? Center(
              child: _erro == null
                  ? const TomateCarregando(texto: 'Buscando seu pedido...')
                  : EstadoVazio(titulo: 'Não deu para abrir o pedido', texto: _erro, acao: 'Tentar de novo', onAcao: _carregar),
            )
          : RefreshIndicator(
              color: XepaCores.tomate,
              onRefresh: _carregar,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  if (p.entrega && p.status != StatusPedido.cancelado) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(XepaRaios.cartao),
                      child: MapaEntrega(loja: _loja, destino: _destino, entregador: _entregador, rota: _rota, altura: 220),
                    ),
                    const SizedBox(height: 14),
                  ],
                  _CartaoStatus(pedido: p, entregador: _nomeEntregador),
                  if (p.codigoRetirada != null && p.status.emAndamento && p.status != StatusPedido.aguardandoPagamento) ...[
                    const SizedBox(height: 12),
                    _CodigoRetirada(
                      codigo: p.codigoRetirada!,
                      titulo: p.entrega ? 'Informe este código ao entregador' : 'Mostre este código na loja',
                      rodape: p.entrega ? 'Só passe o código quando receber o pedido' : 'Retirada entre ${_hora(p.retiradaInicio)}–${_hora(p.retiradaFim)}',
                    ),
                  ],
                  const SizedBox(height: 12),
                  _Cartao(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox.square(
                                dimension: 52,
                                child: FotoOferta(url: p.fotoUrl, categoria: Categoria.padaria, tamanhoIcone: 24),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.oferta, style: const TextStyle(fontWeight: FontWeight.w800)),
                                  Text('${p.loja} · ${p.quantidade} un.',
                                      style: const TextStyle(color: XepaCores.textoSecundario, fontSize: 13)),
                                ],
                              ),
                            ),
                            Text(formatarPreco(p.valorTotal),
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          ],
                        ),
                        if (p.entrega && p.endereco != null) ...[
                          const Divider(height: 24),
                          Row(
                            children: [
                              const Icon(Icons.home_outlined, size: 20, color: XepaCores.textoSecundario),
                              const SizedBox(width: 10),
                              Expanded(child: Text(p.endereco!.resumo, style: const TextStyle(fontSize: 13))),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _Cartao(child: _LinhaDoTempo(pedido: p)),
                  if (p.status != StatusPedido.aguardandoPagamento) ...[
                    const SizedBox(height: 12),
                    DenunciaDoPedido(pedidoId: p.id),
                  ],
                  if (_erro != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(_erro!, style: const TextStyle(color: XepaCores.tomateEscuro)),
                    ),
                  if (p.status.cancelavel)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: TextButton(
                        onPressed: _cancelar,
                        style: TextButton.styleFrom(foregroundColor: XepaCores.textoSecundario),
                        child: const Text('Cancelar pedido'),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  static String _hora(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

/// Etapas mostradas na barra e na linha do tempo, conforme o tipo de pedido.
List<StatusPedido> _etapas(Pedido p) => [
      StatusPedido.pendente,
      StatusPedido.confirmado,
      StatusPedido.emPreparo,
      StatusPedido.prontoParaRetirada,
      if (p.entrega) StatusPedido.saiuParaEntrega,
      StatusPedido.entregue,
    ];

class _Cartao extends StatelessWidget {
  const _Cartao({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(XepaRaios.cartao),
          border: Border.all(color: XepaCores.borda),
          boxShadow: sombraCartao,
        ),
        child: child,
      );
}

class _CartaoStatus extends StatelessWidget {
  const _CartaoStatus({required this.pedido, this.entregador});

  final Pedido pedido;
  final String? entregador;

  @override
  Widget build(BuildContext context) {
    final p = pedido;
    final etapas = _etapas(p);
    final atual = etapas.indexOf(p.status);
    final subtitulo = switch (p.status) {
      StatusPedido.aguardandoPagamento => 'Falta só confirmar o pagamento',
      StatusPedido.cancelado => 'Se havia pagamento aprovado, o estorno foi solicitado',
      StatusPedido.entregue => p.entrega ? 'Bom apetite! Obrigado por salvar essa comida' : 'Retirado. Obrigado por salvar essa comida',
      StatusPedido.saiuParaEntrega when entregador != null => '$entregador está a caminho com seu pedido',
      _ when p.entrega && entregador != null => '$entregador vai buscar seu pedido na loja',
      _ => p.entrega ? 'Entrega por entregador parceiro XEPA' : 'Retirada na loja',
    };
    return _Cartao(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitulo, style: const TextStyle(color: XepaCores.textoSecundario, fontSize: 12.5)),
          const SizedBox(height: 2),
          Semantics(
            liveRegion: true,
            child: Text(p.status.rotuloPara(entrega: p.entrega),
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: p.status.cor)),
          ),
          if (p.status != StatusPedido.cancelado) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                for (var i = 0; i < etapas.length; i++) ...[
                  if (i > 0) const SizedBox(width: 5),
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      height: 6,
                      decoration: BoxDecoration(
                        color: i <= atual ? XepaCores.tomate : XepaCores.borda,
                        borderRadius: BorderRadius.circular(XepaRaios.pilula),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CodigoRetirada extends StatelessWidget {
  const _CodigoRetirada({required this.codigo, required this.titulo, required this.rodape});

  final String codigo;
  final String titulo;
  final String rodape;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(XepaRaios.cartao),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: XepaCores.tomateClaro,
          borderRadius: BorderRadius.circular(XepaRaios.cartao),
          border: Border.all(color: XepaCores.tomate.withAlpha(70)),
        ),
        child: Stack(
          children: [
            // Tomatinho escondido atrás do código.
            const Positioned(left: -14, bottom: -18, child: TomateMarcaDagua(tamanho: 74, opacidade: 0.12, angulo: 0.4)),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              child: Column(
                children: [
                  Text(titulo, style: const TextStyle(color: XepaCores.tomateEscuro, fontWeight: FontWeight.w700)),
                  Semantics(
                    label: 'Código de retirada ${codigo.split('').join(' ')}',
                    child: Text(codigo,
                        style: const TextStyle(fontSize: 40, letterSpacing: 10, fontWeight: FontWeight.w800, color: XepaCores.tomateEscuro)),
                  ),
                  Text(rodape, style: const TextStyle(color: XepaCores.tomateEscuro, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinhaDoTempo extends StatelessWidget {
  const _LinhaDoTempo({required this.pedido});

  final Pedido pedido;

  @override
  Widget build(BuildContext context) {
    if (pedido.status == StatusPedido.cancelado) {
      return const Row(
        children: [
          Icon(Icons.cancel_outlined, color: XepaCores.textoSecundario),
          SizedBox(width: 10),
          Text('Pedido cancelado', style: TextStyle(fontWeight: FontWeight.w700)),
        ],
      );
    }
    final etapas = _etapas(pedido);
    // Entregue: todas as etapas ficam concluídas (verdes), sem etapa "atual".
    final concluido = pedido.status == StatusPedido.entregue;
    final atual = concluido ? etapas.length : etapas.indexOf(pedido.status);
    return Column(
      children: [
        for (var i = 0; i < etapas.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 24,
                  child: Column(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i < atual ? XepaCores.verde : (i == atual ? XepaCores.tomate : Colors.white),
                          border: Border.all(color: i <= atual ? Colors.transparent : XepaCores.borda, width: 2),
                        ),
                        child: i <= atual ? Icon(i < atual ? Icons.check_rounded : etapas[i].icone, size: 13, color: Colors.white) : null,
                      ),
                      if (i < etapas.length - 1)
                        Expanded(
                          child: Container(width: 2, color: i < atual ? XepaCores.verde : XepaCores.borda),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: 16),
                  child: Text(
                    etapas[i] == StatusPedido.prontoParaRetirada && pedido.entrega ? 'Pronto para coleta' : etapas[i].rotulo,
                    style: TextStyle(
                      fontWeight: i == atual ? FontWeight.w800 : FontWeight.w600,
                      color: i <= atual ? XepaCores.texto : XepaCores.textoSecundario,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
