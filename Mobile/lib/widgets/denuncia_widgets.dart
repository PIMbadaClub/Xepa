import 'package:flutter/material.dart';

import '../api/api.dart';
import '../theme.dart';

enum MotivoDenuncia {
  comidaImpropria('Comida imprópria para consumo'),
  pedidoNaoEntregue('Pedido não entregue'),
  diferenteDoAnunciado('Diferente do anunciado'),
  mauAtendimento('Mau atendimento'),
  discriminacao('Discriminação'),
  outro('Outro');

  const MotivoDenuncia(this.rotulo);

  final String rotulo;

  /// Nome do enum na API (MotivoDenuncia).
  String get nomeApi => name[0].toUpperCase() + name.substring(1);

  static MotivoDenuncia daApi(String valor) => values.byName(valor[0].toLowerCase() + valor.substring(1));
}

/// Canal de denúncia do pedido: mostra a denúncia em andamento (com a resposta da XEPA) ou o botão para abrir uma.
class DenunciaDoPedido extends StatefulWidget {
  const DenunciaDoPedido({super.key, required this.pedidoId});

  final int pedidoId;

  @override
  State<DenunciaDoPedido> createState() => _DenunciaDoPedidoState();
}

class _DenunciaDoPedidoState extends State<DenunciaDoPedido> {
  List<Map<String, dynamic>>? _denuncias;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final lista = await Api.instance.get<List<dynamic>>('/api/pedidos/${widget.pedidoId}/denuncias');
      if (mounted) setState(() => _denuncias = lista.cast<Map<String, dynamic>>());
    } on ApiException {
      if (mounted) setState(() => _denuncias = []);
    }
  }

  Future<void> _abrir() async {
    final enviada = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FormDenuncia(pedidoId: widget.pedidoId),
    );
    if (enviada == true) {
      await _carregar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Denúncia enviada. A equipe da XEPA responde por aqui.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final denuncias = _denuncias;
    if (denuncias == null) return const SizedBox.shrink();

    final aberta = denuncias.where((d) => d['status'] == 'Aberta').firstOrNull;
    final ultima = denuncias.firstOrNull;

    if (ultima == null || (aberta == null && ultima['status'] != 'Aberta' && ultima['resposta'] == null)) {
      return _BotaoDenunciar(onTap: _abrir);
    }

    final d = aberta ?? ultima;
    final status = d['status'] as String;
    final emAnalise = status == 'Aberta';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: emAnalise ? XepaCores.pao : XepaCores.verdeClaro,
            borderRadius: BorderRadius.circular(XepaRaios.cartao),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                emAnalise ? 'Denúncia em análise' : 'Denúncia ${status == 'Procedente' ? 'procedente' : 'analisada'}',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: emAnalise ? XepaCores.paoEscuro : XepaCores.verdeTexto,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                MotivoDenuncia.daApi(d['motivo'] as String).rotulo,
                style: const TextStyle(fontSize: 12.5, color: XepaCores.textoSecundario),
              ),
              const SizedBox(height: 6),
              Text(
                emAnalise
                    ? 'A equipe da XEPA vai olhar o caso e responder aqui.'
                    : (d['resposta'] as String? ?? ''),
                style: TextStyle(color: emAnalise ? XepaCores.paoEscuro : XepaCores.verdeTexto, height: 1.35),
              ),
            ],
          ),
        ),
        if (!emAnalise) _BotaoDenunciar(onTap: _abrir),
      ],
    );
  }
}

class _BotaoDenunciar extends StatelessWidget {
  const _BotaoDenunciar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(foregroundColor: XepaCores.textoSecundario),
      icon: const Icon(Icons.flag_outlined, size: 18),
      label: const Text('Algo deu errado? Denunciar'),
    );
  }
}

class _FormDenuncia extends StatefulWidget {
  const _FormDenuncia({required this.pedidoId});

  final int pedidoId;

  @override
  State<_FormDenuncia> createState() => _FormDenunciaState();
}

class _FormDenunciaState extends State<_FormDenuncia> {
  MotivoDenuncia? _motivo;
  final _descricao = TextEditingController();
  bool _enviando = false;
  String? _erro;

  @override
  void dispose() {
    _descricao.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (_motivo == null) {
      setState(() => _erro = 'Escolha o motivo.');
      return;
    }
    if (_descricao.text.trim().length < 10) {
      setState(() => _erro = 'Conte um pouco mais do que aconteceu (mínimo de 10 caracteres).');
      return;
    }
    setState(() {
      _enviando = true;
      _erro = null;
    });
    try {
      await Api.instance.post<Map<String, dynamic>>('/api/pedidos/${widget.pedidoId}/denuncias', {
        'motivo': _motivo!.nomeApi,
        'descricao': _descricao.text.trim(),
      });
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _erro = e.mensagem;
          _enviando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('O que aconteceu?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text(
              'A equipe da XEPA analisa cada denúncia e responde aqui no pedido. Discriminação é tratada com prioridade.',
              style: TextStyle(color: XepaCores.textoSecundario, height: 1.35),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in MotivoDenuncia.values)
                  ChoiceChip(
                    label: Text(m.rotulo),
                    selected: _motivo == m,
                    onSelected: (_) => setState(() => _motivo = m),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _descricao,
              maxLines: 4,
              maxLength: 1000,
              decoration: const InputDecoration(hintText: 'Conte com detalhes: o que veio, o que faltou, como foi o atendimento...'),
            ),
            if (_erro != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_erro!, style: const TextStyle(color: XepaCores.tomateEscuro, fontWeight: FontWeight.w600)),
              ),
            FilledButton(
              onPressed: _enviando ? null : _enviar,
              child: _enviando
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Enviar denúncia'),
            ),
          ],
        ),
      ),
    );
  }
}
