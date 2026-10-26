import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api/api.dart';
import '../theme.dart';
import 'oferta_widgets.dart';

enum MotivoDenuncia {
  comidaImpropria('Comida imprópria', Icons.no_food_outlined),
  pedidoNaoEntregue('Não recebi o pedido', Icons.inventory_2_outlined),
  diferenteDoAnunciado('Diferente do anunciado', Icons.compare_arrows_rounded),
  mauAtendimento('Mau atendimento', Icons.sentiment_dissatisfied_outlined),
  discriminacao('Discriminação', Icons.front_hand_outlined),
  outro('Outro', Icons.more_horiz_rounded);

  const MotivoDenuncia(this.rotulo, this.icone);

  final String rotulo;
  final IconData icone;

  /// Nome do enum na API (MotivoDenuncia).
  String get nomeApi => name[0].toUpperCase() + name.substring(1);

  static MotivoDenuncia daApi(String valor) => values.byName(valor[0].toLowerCase() + valor.substring(1));
}

enum StatusDenuncia { aberta, procedente, improcedente }

/// Denúncia como a API devolve em /api/pedidos/{id}/denuncias e /api/usuarios/me/denuncias.
class Denuncia {
  Denuncia.fromJson(Map<String, dynamic> j)
      : id = j['id'] as int,
        pedidoId = j['pedidoId'] as int,
        loja = j['loja'] as String,
        motivo = MotivoDenuncia.daApi(j['motivo'] as String),
        descricao = j['descricao'] as String,
        fotoUrl = j['fotoUrl'] as String?,
        status = StatusDenuncia.values.byName((j['status'] as String).toLowerCase()),
        resposta = j['resposta'] as String?,
        criadoEm = DateTime.parse(j['criadoEm'] as String).toLocal(),
        tratadaEm = j['tratadaEm'] == null ? null : DateTime.parse(j['tratadaEm'] as String).toLocal();

  final int id;
  final int pedidoId;
  final String loja;
  final MotivoDenuncia motivo;
  final String descricao;
  final String? fotoUrl;
  final StatusDenuncia status;
  final String? resposta;
  final DateTime criadoEm;
  final DateTime? tratadaEm;

  bool get emAnalise => status == StatusDenuncia.aberta;
}

String _data(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} às ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// Cartão da denúncia: motivo, relato, foto, andamento (enviada → em análise → respondida) e resposta da XEPA.
class CartaoDenuncia extends StatelessWidget {
  const CartaoDenuncia({super.key, required this.denuncia, this.mostrarPedido = false});

  final Denuncia denuncia;
  final bool mostrarPedido;

  @override
  Widget build(BuildContext context) {
    final d = denuncia;
    final (corStatus, fundoStatus, rotuloStatus) = switch (d.status) {
      StatusDenuncia.aberta => (XepaCores.paoEscuro, XepaCores.pao, 'Em análise'),
      StatusDenuncia.procedente => (XepaCores.verdeTexto, XepaCores.verdeClaro, 'Procedente'),
      StatusDenuncia.improcedente => (XepaCores.textoSecundario, XepaCores.bege, 'Analisada'),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(XepaRaios.cartao),
        border: Border.all(color: XepaCores.borda),
        boxShadow: sombraCartao,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: fundoStatus, shape: BoxShape.circle),
                child: Icon(d.motivo.icone, size: 18, color: corStatus),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.motivo.rotulo, style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text(
                      mostrarPedido ? 'Pedido #${d.pedidoId} · ${d.loja}' : 'Enviada em ${_data(d.criadoEm)}',
                      style: const TextStyle(color: XepaCores.textoSecundario, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: fundoStatus, borderRadius: BorderRadius.circular(XepaRaios.pilula)),
                child: Text(rotuloStatus, style: TextStyle(color: corStatus, fontWeight: FontWeight.w800, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text('"${d.descricao}"',
                    style: const TextStyle(color: XepaCores.texto, height: 1.4, fontStyle: FontStyle.italic)),
              ),
              if (d.fotoUrl != null) ...[
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (_) => Dialog(
                      clipBehavior: Clip.antiAlias,
                      child: InteractiveViewer(child: Image.network(urlFoto(d.fotoUrl)!)),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(urlFoto(d.fotoUrl)!, width: 64, height: 64, fit: BoxFit.cover),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          _Andamento(denuncia: d),
          if (d.resposta != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: XepaCores.verdeClaro, borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Resposta da XEPA', style: TextStyle(fontWeight: FontWeight.w800, color: XepaCores.verdeTexto)),
                  const SizedBox(height: 4),
                  Text(d.resposta!, style: const TextStyle(color: XepaCores.verdeTexto, height: 1.4)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Três passos: enviada → em análise → respondida.
class _Andamento extends StatelessWidget {
  const _Andamento({required this.denuncia});

  final Denuncia denuncia;

  @override
  Widget build(BuildContext context) {
    final respondida = !denuncia.emAnalise;
    final passos = [
      ('Enviada', _data(denuncia.criadoEm), true),
      ('Em análise', 'pela equipe XEPA', true),
      ('Respondida', denuncia.tratadaEm == null ? 'em até 2 dias úteis' : _data(denuncia.tratadaEm!), respondida),
    ];
    return Row(
      children: [
        for (var i = 0; i < passos.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.only(bottom: 30),
                color: passos[i].$3 ? XepaCores.verde : XepaCores.borda,
              ),
            ),
          Column(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: passos[i].$3 ? XepaCores.verde : Colors.white,
                  border: Border.all(color: passos[i].$3 ? XepaCores.verde : XepaCores.borda, width: 2),
                ),
                child: passos[i].$3 ? const Icon(Icons.check_rounded, size: 12, color: Colors.white) : null,
              ),
              const SizedBox(height: 4),
              Text(passos[i].$1, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
              Text(passos[i].$2, style: const TextStyle(fontSize: 10, color: XepaCores.textoSecundario)),
            ],
          ),
        ],
      ],
    );
  }
}

/// Canal de denúncia dentro do pedido: mostra as denúncias feitas e o botão para abrir uma nova.
class DenunciaDoPedido extends StatefulWidget {
  const DenunciaDoPedido({super.key, required this.pedidoId});

  final int pedidoId;

  @override
  State<DenunciaDoPedido> createState() => _DenunciaDoPedidoState();
}

class _DenunciaDoPedidoState extends State<DenunciaDoPedido> {
  List<Denuncia>? _denuncias;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final lista = await Api.instance.get<List<dynamic>>('/api/pedidos/${widget.pedidoId}/denuncias');
      if (mounted) setState(() => _denuncias = lista.map((j) => Denuncia.fromJson(j as Map<String, dynamic>)).toList());
    } on ApiException {
      if (mounted) setState(() => _denuncias = []);
    }
  }

  Future<void> _abrir() async {
    final enviada = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _FormDenuncia(pedidoId: widget.pedidoId),
    );
    if (enviada == true) {
      await _carregar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Denúncia enviada. A equipe da XEPA responde por aqui e nas notificações.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final denuncias = _denuncias;
    if (denuncias == null) return const SizedBox.shrink();
    final temAberta = denuncias.any((d) => d.emAnalise);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final d in denuncias) CartaoDenuncia(denuncia: d),
        if (!temAberta)
          TextButton.icon(
            onPressed: _abrir,
            style: TextButton.styleFrom(foregroundColor: XepaCores.textoSecundario),
            icon: const Icon(Icons.flag_outlined, size: 18),
            label: const Text('Algo deu errado? Denunciar'),
          ),
      ],
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
  XFile? _foto;
  Uint8List? _previa;
  bool _enviando = false;
  String? _erro;

  @override
  void dispose() {
    _descricao.dispose();
    super.dispose();
  }

  Future<void> _escolherFoto(ImageSource origem) async {
    try {
      final foto = await ImagePicker().pickImage(source: origem, maxWidth: 1600, imageQuality: 80);
      if (foto == null) return;
      final bytes = await foto.readAsBytes();
      setState(() {
        _foto = foto;
        _previa = bytes;
      });
    } catch (_) {
      setState(() => _erro = 'Não deu para abrir a foto. Tente outra.');
    }
  }

  Future<void> _enviar() async {
    if (_motivo == null) {
      setState(() => _erro = 'Escolha o que aconteceu.');
      return;
    }
    if (_descricao.text.trim().length < 10) {
      setState(() => _erro = 'Conte um pouco mais (mínimo de 10 caracteres).');
      return;
    }
    setState(() {
      _enviando = true;
      _erro = null;
    });
    try {
      final dados = FormData.fromMap({
        'motivo': _motivo!.nomeApi,
        'descricao': _descricao.text.trim(),
        if (_foto != null)
          'foto': MultipartFile.fromBytes(_previa!, filename: _nomeArquivo(_foto!)),
      });
      await Api.instance.post<Map<String, dynamic>>('/api/pedidos/${widget.pedidoId}/denuncias', dados);
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

  /// No navegador o nome pode vir sem extensão; a API usa a extensão para validar o tipo.
  static String _nomeArquivo(XFile f) {
    final nome = f.name;
    if (nome.contains('.')) return nome;
    final tipo = f.mimeType ?? 'image/jpeg';
    return '$nome.${tipo.endsWith('png') ? 'png' : tipo.endsWith('webp') ? 'webp' : 'jpg'}';
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
              'A equipe da XEPA analisa cada caso e responde no pedido. Discriminação tem prioridade.',
              style: TextStyle(color: XepaCores.textoSecundario, height: 1.35),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.05,
              children: [
                for (final m in MotivoDenuncia.values)
                  _OpcaoMotivo(motivo: m, selecionado: _motivo == m, onTap: () => setState(() => _motivo = m)),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _descricao,
              maxLines: 4,
              maxLength: 1000,
              decoration: const InputDecoration(hintText: 'Conte com detalhes: o que veio, o que faltou, como foi o atendimento...'),
            ),
            if (_previa != null)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.memory(_previa!, height: 160, width: double.infinity, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: IconButton.filledTonal(
                      tooltip: 'Tirar a foto',
                      onPressed: () => setState(() {
                        _foto = null;
                        _previa = null;
                      }),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  if (!kIsWeb) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _escolherFoto(ImageSource.camera),
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: const Text('Tirar foto'),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _escolherFoto(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: Text(kIsWeb ? 'Anexar foto (opcional)' : 'Da galeria'),
                    ),
                  ),
                ],
              ),
            if (_erro != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(_erro!, style: const TextStyle(color: XepaCores.tomateEscuro, fontWeight: FontWeight.w600)),
              ),
            const SizedBox(height: 16),
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

class _OpcaoMotivo extends StatelessWidget {
  const _OpcaoMotivo({required this.motivo, required this.selecionado, required this.onTap});

  final MotivoDenuncia motivo;
  final bool selecionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: selecionado ? XepaCores.tomateClaro : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: selecionado ? XepaCores.tomate : XepaCores.borda, width: selecionado ? 1.6 : 1),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(motivo.icone, color: selecionado ? XepaCores.tomate : XepaCores.textoSecundario),
                const SizedBox(height: 6),
                Text(
                  motivo.rotulo,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: selecionado ? XepaCores.tomateEscuro : XepaCores.texto,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
