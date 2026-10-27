import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api.dart';
import '../api/suporte.dart';
import '../theme.dart';
import '../widgets/xepa_logo.dart';

/// Chat com a equipe da XEPA, no estilo do atendimento dos marketplaces: assuntos rápidos, pedido anexado e
/// resposta automática na abertura. A equipe responde pelo portal; a tela busca as novas a cada 4 segundos.
class SuporteScreen extends StatefulWidget {
  const SuporteScreen({super.key, this.pedidoId});

  /// Abre já com este pedido anexado (vindo da tela do pedido).
  final int? pedidoId;

  @override
  State<SuporteScreen> createState() => _SuporteScreenState();
}

class _SuporteScreenState extends State<SuporteScreen> {
  static const _assuntos = [
    'Meu pedido não chegou',
    'A sacola veio diferente do anunciado',
    'Problema com o pagamento',
    'Quero cancelar um pedido',
    'Não consigo entrar na conta',
  ];

  final _texto = TextEditingController();
  final _rolagem = ScrollController();
  final _mensagens = <MensagemSuporte>[];
  Timer? _timer;
  bool _carregando = true;
  bool _enviando = false;
  bool _atendimentoAgora = true;
  String? _erro;
  PedidoAnexo? _anexo;

  @override
  void initState() {
    super.initState();
    _carregar();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _buscarNovas());
    if (widget.pedidoId != null) _anexarPorId(widget.pedidoId!);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _texto.dispose();
    _rolagem.dispose();
    Suporte.instance.naoLidas.value = 0;
    super.dispose();
  }

  Future<void> _carregar() async {
    try {
      final c = await Suporte.instance.conversa();
      if (!mounted) return;
      setState(() {
        _mensagens
          ..clear()
          ..addAll(c.mensagens);
        _atendimentoAgora = c.atendimentoAgora;
        _carregando = false;
      });
      _rolarParaFim();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _erro = e.mensagem;
          _carregando = false;
        });
      }
    }
  }

  Future<void> _buscarNovas() async {
    if (_carregando || _enviando) return;
    try {
      final c = await Suporte.instance.conversa(depois: _mensagens.isEmpty ? null : _mensagens.last.id);
      final novas = c.mensagens.where((m) => _mensagens.isEmpty || m.id > _mensagens.last.id).toList();
      if (!mounted || novas.isEmpty) return;
      setState(() => _mensagens.addAll(novas));
      _rolarParaFim();
    } on ApiException {
      // Sem rede: tenta de novo no próximo ciclo.
    }
  }

  Future<void> _anexarPorId(int id) async {
    try {
      final pedido = (await Suporte.instance.pedidos()).where((p) => p.id == id).firstOrNull;
      if (mounted && pedido != null) setState(() => _anexo = pedido);
    } on ApiException {
      // Segue sem o anexo.
    }
  }

  Future<void> _enviar([String? textoPronto]) async {
    final texto = (textoPronto ?? _texto.text).trim();
    if (texto.isEmpty || _enviando) return;
    setState(() {
      _enviando = true;
      _erro = null;
    });
    try {
      final c = await Suporte.instance.enviar(texto, pedidoId: _anexo?.id);
      if (!mounted) return;
      setState(() {
        _mensagens
          ..clear()
          ..addAll(c.mensagens);
        _anexo = null;
        if (textoPronto == null) _texto.clear();
      });
      _rolarParaFim();
    } on ApiException catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _rolarParaFim() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_rolagem.hasClients) {
        _rolagem.animateTo(_rolagem.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _escolherPedido() async {
    final escolhido = await showModalBottomSheet<PedidoAnexo>(
      context: context,
      useRootNavigator: true, // por cima da barra de abas
      isScrollControlled: true,
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
      showDragHandle: true,
      backgroundColor: XepaCores.fundo,
      builder: (_) => const _EscolherPedido(),
    );
    if (escolhido != null && mounted) setState(() => _anexo = escolhido);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            const XepaLogo(tamanho: 34),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Suporte XEPA', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                Text(
                  _atendimentoAgora ? 'Online · responde em minutos' : 'Atendimento das 8h às 22h',
                  style: TextStyle(
                    fontSize: 12,
                    color: _atendimentoAgora ? XepaCores.verde : XepaCores.textoSecundario,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: _carregando
                  ? const Center(child: TomateCarregando())
                  : ListView(
                      controller: _rolagem,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      children: [
                        if (_mensagens.isEmpty) _Boasvindas(assuntos: _assuntos, aoEscolher: _enviar, desabilitado: _enviando),
                        for (final m in _mensagens) _Balao(mensagem: m),
                      ],
                    ),
            ),
            if (_erro != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: Text(_erro!, style: const TextStyle(color: XepaCores.tomateEscuro, fontWeight: FontWeight.w600)),
              ),
            if (_anexo != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                child: _CartaoPedido(pedido: _anexo!, aoRemover: () => setState(() => _anexo = null)),
              ),
            _BarraEnvio(
              controller: _texto,
              enviando: _enviando,
              aoEnviar: _enviar,
              aoAnexar: _escolherPedido,
            ),
          ],
        ),
      ),
    );
  }
}

class _Boasvindas extends StatelessWidget {
  const _Boasvindas({required this.assuntos, required this.aoEscolher, required this.desabilitado});

  final List<String> assuntos;
  final ValueChanged<String> aoEscolher;
  final bool desabilitado;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: XepaCores.tomateClaro, borderRadius: BorderRadius.circular(XepaRaios.cartao)),
          child: const Text(
            'Oi! Como podemos ajudar? Escolha um assunto ou escreva sua dúvida. '
            'Se for sobre um pedido, toque no clipe para anexar.',
            style: TextStyle(height: 1.4, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final a in assuntos)
              ActionChip(
                label: Text(a),
                onPressed: desabilitado ? null : () => aoEscolher(a),
                backgroundColor: Colors.white,
                side: const BorderSide(color: XepaCores.borda),
                labelStyle: const TextStyle(fontWeight: FontWeight.w700, color: XepaCores.tomateEscuro),
              ),
          ],
        ),
      ],
    );
  }
}

class _Balao extends StatelessWidget {
  const _Balao({required this.mensagem});

  final MensagemSuporte mensagem;

  @override
  Widget build(BuildContext context) {
    final m = mensagem;
    final hora = '${m.em.day.toString().padLeft(2, '0')}/${m.em.month.toString().padLeft(2, '0')} '
        '${m.em.hour.toString().padLeft(2, '0')}:${m.em.minute.toString().padLeft(2, '0')}';

    if (m.automatica) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: XepaCores.bege, borderRadius: BorderRadius.circular(14)),
          child: Column(
            children: [
              Text(m.texto, textAlign: TextAlign.center, style: const TextStyle(color: XepaCores.textoSecundario, height: 1.35)),
              const SizedBox(height: 4),
              Text(hora, style: const TextStyle(fontSize: 11, color: XepaCores.textoSecundario)),
            ],
          ),
        ),
      );
    }

    final minha = !m.doSuporte;
    return Align(
      alignment: minha ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        decoration: BoxDecoration(
          color: minha ? XepaCores.tomateClaro : Colors.white,
          border: minha ? null : Border.all(color: XepaCores.borda),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(minha ? 18 : 6),
            bottomRight: Radius.circular(minha ? 6 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!minha)
              Text(m.autor, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: XepaCores.tomateEscuro)),
            if (m.pedido != null) ...[
              const SizedBox(height: 4),
              _CartaoPedido(pedido: m.pedido!),
              const SizedBox(height: 6),
            ],
            Text(m.texto, style: const TextStyle(height: 1.35)),
            const SizedBox(height: 2),
            Align(
              alignment: Alignment.centerRight,
              child: Text(hora, style: const TextStyle(fontSize: 11, color: XepaCores.textoSecundario)),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartaoPedido extends StatelessWidget {
  const _CartaoPedido({required this.pedido, this.aoRemover});

  final PedidoAnexo pedido;
  final VoidCallback? aoRemover;

  @override
  Widget build(BuildContext context) {
    final p = pedido;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: XepaCores.borda),
      ),
      child: Row(
        children: [
          Icon(p.status.icone, color: p.status.cor, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pedido #${p.id} · ${p.loja}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                Text('${p.oferta} · ${formatarPreco(p.valorTotal)}',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5)),
                Text(p.status.rotuloPara(entrega: p.entrega),
                    style: TextStyle(fontSize: 12, color: p.status.cor, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          if (aoRemover != null)
            IconButton(tooltip: 'Tirar o pedido', onPressed: aoRemover, icon: const Icon(Icons.close_rounded, size: 20)),
        ],
      ),
    );
  }
}

class _BarraEnvio extends StatelessWidget {
  const _BarraEnvio({required this.controller, required this.enviando, required this.aoEnviar, required this.aoAnexar});

  final TextEditingController controller;
  final bool enviando;
  final VoidCallback aoEnviar;
  final VoidCallback aoAnexar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: XepaCores.borda)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            tooltip: 'Anexar um pedido',
            onPressed: enviando ? null : aoAnexar,
            icon: const Icon(Icons.attach_file_rounded),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 5,
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Escreva uma mensagem', counterText: '', isDense: true),
            ),
          ),
          const SizedBox(width: 6),
          IconButton.filled(
            tooltip: 'Enviar',
            onPressed: enviando ? null : aoEnviar,
            style: IconButton.styleFrom(backgroundColor: XepaCores.tomate),
            icon: enviando
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _EscolherPedido extends StatelessWidget {
  const _EscolherPedido();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FutureBuilder<List<PedidoAnexo>>(
        future: Suporte.instance.pedidos(),
        builder: (context, snap) {
          final pedidos = snap.data;
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Sobre qual pedido?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                if (snap.connectionState != ConnectionState.done)
                  const Center(child: Padding(padding: EdgeInsets.all(16), child: TomateCarregando()))
                else if (pedidos == null || pedidos.isEmpty)
                  const Text('Você ainda não tem pedidos para anexar.', style: TextStyle(color: XepaCores.textoSecundario))
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: pedidos.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => Navigator.pop(context, pedidos[i]),
                        child: _CartaoPedido(pedido: pedidos[i]),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
