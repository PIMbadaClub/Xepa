import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../api/api.dart';
import '../api/tempo_real.dart';
import '../models/pedido.dart';
import '../theme.dart';
import '../widgets/mapa_entrega.dart';

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
      appBar: AppBar(title: Text('Pedido #${widget.pedidoId}'), backgroundColor: XepaCores.fundo),
      body: p == null
          ? Center(child: _erro == null ? const CircularProgressIndicator() : Text(_erro!))
          : RefreshIndicator(
              onRefresh: _carregar,
              child: ListView(
                children: [
                  if (p.entrega && p.status != StatusPedido.cancelado)
                    MapaEntrega(loja: _loja, destino: _destino, entregador: _entregador),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          liveRegion: true,
                          child: Text(p.status.rotulo,
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: p.status.cor)),
                        ),
                        Text('${p.quantidade}x ${p.oferta} · ${p.loja}', style: const TextStyle(color: XepaCores.textoSecundario)),
                        const SizedBox(height: 16),
                        if (!p.entrega && p.codigoRetirada != null && p.status.emAndamento && p.status != StatusPedido.aguardandoPagamento)
                          _CodigoRetirada(codigo: p.codigoRetirada!, janela: '${_hora(p.retiradaInicio)}–${_hora(p.retiradaFim)}'),
                        if (p.entrega && p.endereco != null)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.home_outlined),
                            title: const Text('Entregar em'),
                            subtitle: Text(p.endereco!.resumo),
                          ),
                        _LinhaDoTempo(pedido: p),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Text('Total pago', style: TextStyle(fontWeight: FontWeight.w700)),
                            const Spacer(),
                            Text(formatarPreco(p.valorTotal), style: const TextStyle(fontWeight: FontWeight.w800, color: XepaCores.verde)),
                          ],
                        ),
                        if (_erro != null) Text(_erro!, style: const TextStyle(color: XepaCores.tomateEscuro)),
                        if (p.status.cancelavel)
                          TextButton(onPressed: _cancelar, child: const Text('Cancelar pedido')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  static String _hora(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class _CodigoRetirada extends StatelessWidget {
  const _CodigoRetirada({required this.codigo, required this.janela});

  final String codigo;
  final String janela;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: XepaCores.verdeClaro, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          const Text('Mostre este código na loja', style: TextStyle(color: XepaCores.verdeTexto, fontWeight: FontWeight.w700)),
          Semantics(
            label: 'Código de retirada ${codigo.split('').join(' ')}',
            child: Text(codigo,
                style: const TextStyle(fontSize: 42, letterSpacing: 10, fontWeight: FontWeight.w900, color: XepaCores.verdeTexto)),
          ),
          Text('Retirada entre $janela', style: const TextStyle(color: XepaCores.verdeTexto)),
        ],
      ),
    );
  }
}

class _LinhaDoTempo extends StatelessWidget {
  const _LinhaDoTempo({required this.pedido});

  final Pedido pedido;

  @override
  Widget build(BuildContext context) {
    final etapas = [
      StatusPedido.pendente,
      StatusPedido.confirmado,
      StatusPedido.emPreparo,
      pedido.entrega ? StatusPedido.saiuParaEntrega : StatusPedido.prontoParaRetirada,
      StatusPedido.entregue,
    ];
    if (pedido.status == StatusPedido.cancelado) {
      return const ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.cancel_outlined),
        title: Text('Pedido cancelado'),
        subtitle: Text('Se havia pagamento aprovado, o estorno foi solicitado.'),
      );
    }
    final atual = etapas.indexOf(pedido.status);
    return Column(
      children: [
        for (var i = 0; i < etapas.length; i++)
          Row(
            children: [
              Icon(
                i <= atual ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                color: i == atual ? XepaCores.tomate : (i < atual ? XepaCores.verde : XepaCores.borda),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(etapas[i].rotulo,
                    style: TextStyle(fontWeight: i == atual ? FontWeight.w800 : FontWeight.w500,
                        color: i <= atual ? XepaCores.texto : XepaCores.textoSecundario)),
              ),
            ],
          ),
      ],
    );
  }
}
