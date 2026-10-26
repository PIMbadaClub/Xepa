import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api.dart';
import '../api/tempo_real.dart';
import '../models/oferta.dart';
import '../models/pedido.dart';
import '../theme.dart';
import '../widgets/oferta_widgets.dart';
import '../widgets/xepa_logo.dart';
import 'acompanhamento_screen.dart';

/// Pagamento do pedido: Pix (QR Code e copia e cola) ou cartão no checkout do Mercado Pago.
/// A confirmação chega pelo SignalR quando o gateway avisa a API; a tela também consulta a cada 5 s.
class PagamentoScreen extends StatefulWidget {
  const PagamentoScreen({super.key, required this.pedido});

  final Pedido pedido;

  @override
  State<PagamentoScreen> createState() => _PagamentoScreenState();
}

class _PagamentoScreenState extends State<PagamentoScreen> {
  bool _pix = true;
  Pagamento? _pagamento;
  bool _carregando = false;
  String? _erro;
  StreamSubscription<Map<String, dynamic>>? _avisos;
  Timer? _consulta;
  Timer? _relogio;
  bool _concluido = false;

  Pedido get _pedido => widget.pedido;

  @override
  void initState() {
    super.initState();
    _avisos = TempoReal.instance.pedidoAlterado
        .where((e) => e['pedidoId'] == _pedido.id)
        .listen((_) => _verificar());
    TempoReal.instance.acompanharPedido(_pedido.id);
    _consulta = Timer.periodic(const Duration(seconds: 5), (_) => _verificar());
    _relogio = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _gerar();
  }

  @override
  void dispose() {
    _avisos?.cancel();
    _consulta?.cancel();
    _relogio?.cancel();
    super.dispose();
  }

  Future<void> _gerar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final json = await Api.instance.post<Map<String, dynamic>>(
        '/api/pedidos/${_pedido.id}/pagamento', {'metodo': _pix ? 'Pix' : 'Cartao'});
      if (mounted) setState(() => _pagamento = Pagamento.fromJson(json));
    } on ApiException catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _verificar() async {
    if (_concluido) return;
    try {
      final p = Pedido.fromJson(await Api.instance.get<Map<String, dynamic>>('/api/pedidos/${_pedido.id}'));
      if (p.status == StatusPedido.aguardandoPagamento || !mounted) return;
      _concluido = true;
      // Ao voltar do acompanhamento, o cliente cai no início (e não no detalhe da oferta).
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => AcompanhamentoScreen(pedidoId: p.id)),
        (rota) => rota.isFirst,
      );
    } on ApiException {
      // tenta de novo na próxima consulta
    }
  }

  Future<void> _copiar() async {
    await Clipboard.setData(ClipboardData(text: _pagamento!.qrCodePix!));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Código Pix copiado. Cole no app do seu banco.')));
    }
  }

  /// Só com o gateway simulado (desenvolvimento e homologação): aprova como se o banco tivesse pagado.
  Future<void> _simularAprovacao() async {
    try {
      await Api.instance.post<void>('/api/pagamentos/simulado/${_pagamento!.idExterno}/aprovar');
      await _verificar();
    } on ApiException catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    }
  }

  Future<void> _cancelar() async {
    try {
      await Api.instance.post<Map<String, dynamic>>('/api/pedidos/${_pedido.id}/cancelar');
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    }
  }

  String get _tempoRestante {
    final expira = _pagamento?.expiraEm;
    if (expira == null) return '';
    final resta = expira.difference(DateTime.now());
    if (resta.isNegative) return 'Prazo encerrado';
    return 'Pague em ${resta.inMinutes}:${(resta.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final pg = _pagamento;
    return Scaffold(
      appBar: AppBar(title: const Text('Pagamento')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(XepaRaios.cartao),
              border: Border.all(color: XepaCores.borda),
              boxShadow: sombraCartao,
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox.square(
                    dimension: 52,
                    child: FotoOferta(url: _pedido.fotoUrl, categoria: Categoria.padaria, tamanhoIcone: 24),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${_pedido.quantidade}x ${_pedido.oferta}', style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text(_pedido.loja, style: const TextStyle(color: XepaCores.textoSecundario, fontSize: 13)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(formatarPreco(_pedido.valorTotal),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: XepaCores.tomate)),
                    if (_pedido.taxaEntrega > 0)
                      Text('com entrega de ${formatarPreco(_pedido.taxaEntrega)}',
                          style: const TextStyle(color: XepaCores.textoSecundario, fontSize: 11.5)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _AlternarMetodo(
            pix: _pix,
            onChanged: (pix) {
              if (pix == _pix) return;
              setState(() => _pix = pix);
              _gerar();
            },
          ),
          const SizedBox(height: 20),
          if (_carregando)
            const Padding(
              padding: EdgeInsets.all(40),
              child: TomateCarregando(texto: 'Gerando a cobrança...'),
            )
          else if (pg != null && pg.pix && pg.qrCodePix != null) ...[
            Center(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: XepaCores.borda),
                  boxShadow: sombraCartao,
                ),
                child: QrImageView(
                  data: pg.qrCodePix!,
                  size: 210,
                  eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: XepaCores.texto),
                  dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: XepaCores.texto),
                  semanticsLabel: 'QR Code do Pix de ${formatarPreco(pg.valor)}',
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: XepaCores.tomateClaro, borderRadius: BorderRadius.circular(XepaRaios.pilula)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer_outlined, size: 16, color: XepaCores.tomateEscuro),
                    const SizedBox(width: 4),
                    Text(_tempoRestante, style: const TextStyle(fontWeight: FontWeight.w800, color: XepaCores.tomateEscuro)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _copiar,
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copiar código Pix (copia e cola)'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Assim que o banco confirmar, a loja recebe o pedido e esta tela avança sozinha.',
              textAlign: TextAlign.center,
              style: TextStyle(color: XepaCores.textoSecundario),
            ),
          ] else if (pg != null && !pg.pix) ...[
            const Text(
              'O cartão é digitado na página segura do Mercado Pago. Os dados não passam pelo XEPA.',
              style: TextStyle(color: XepaCores.textoSecundario),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: pg.urlCheckout == null
                  ? null
                  : () => launchUrl(Uri.parse(pg.urlCheckout!), mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Pagar com cartão'),
            ),
            if (pg.urlCheckout == null)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('No ambiente de testes sem Mercado Pago, use o botão de simulação abaixo.',
                    style: TextStyle(color: XepaCores.textoSecundario, fontSize: 13)),
              ),
          ],
          if (pg != null && pg.simulado) ...[
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _simularAprovacao,
              icon: const Icon(Icons.science_outlined),
              label: const Text('Simular pagamento aprovado (teste)'),
            ),
          ],
          if (_erro != null) ...[
            const SizedBox(height: 12),
            Text(_erro!, style: const TextStyle(color: XepaCores.tomateEscuro, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 24),
          TextButton(
            onPressed: _cancelar,
            style: TextButton.styleFrom(foregroundColor: XepaCores.textoSecundario),
            child: const Text('Cancelar pedido'),
          ),
        ],
      ),
    );
  }
}

/// Pix ou cartão, em pílulas.
class _AlternarMetodo extends StatelessWidget {
  const _AlternarMetodo({required this.pix, required this.onChanged});

  final bool pix;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget opcao(bool valor, IconData icone, String rotulo) {
      final ativo = pix == valor;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(valor),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 44,
            decoration: BoxDecoration(
              color: ativo ? XepaCores.tomate : Colors.transparent,
              borderRadius: BorderRadius.circular(XepaRaios.pilula),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icone, size: 18, color: ativo ? Colors.white : XepaCores.textoSecundario),
                const SizedBox(width: 6),
                Text(
                  rotulo,
                  style: TextStyle(fontWeight: FontWeight.w800, color: ativo ? Colors.white : XepaCores.textoSecundario),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(XepaRaios.pilula),
        border: Border.all(color: XepaCores.borda),
      ),
      child: Row(
        children: [
          opcao(true, Icons.pix, 'Pix'),
          opcao(false, Icons.credit_card_rounded, 'Cartão'),
        ],
      ),
    );
  }
}
