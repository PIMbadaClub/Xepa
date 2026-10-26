import 'package:flutter/material.dart';

import '../api/api.dart';
import '../api/localizacao.dart';
import '../models/oferta.dart';
import '../models/pedido.dart';
import '../theme.dart';
import 'pagamento_screen.dart';

/// Escolha entre retirar na loja ou receber em casa, endereço e confirmação do pedido.
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key, required this.oferta, required this.quantidade});

  final Oferta oferta;
  final int quantidade;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  bool _entrega = false;
  List<EnderecoSalvo>? _enderecos;
  int? _enderecoId;
  final _observacao = TextEditingController();
  bool _enviando = false;
  String? _erro;

  double get _subtotal => widget.oferta.preco * widget.quantidade;

  @override
  void initState() {
    super.initState();
    _carregarEnderecos();
  }

  @override
  void dispose() {
    _observacao.dispose();
    super.dispose();
  }

  Future<void> _carregarEnderecos() async {
    try {
      final lista = await Api.instance.get<List<dynamic>>('/api/enderecos');
      final enderecos = lista.map((e) => EnderecoSalvo.fromJson(e as Map<String, dynamic>)).toList();
      if (!mounted) return;
      setState(() {
        _enderecos = enderecos;
        _enderecoId ??= enderecos.where((e) => e.principal).firstOrNull?.id ?? enderecos.firstOrNull?.id;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    }
  }

  Future<void> _novoEndereco() async {
    final criado = await showModalBottomSheet<EnderecoSalvo>(
      context: context,
      isScrollControlled: true,
      backgroundColor: XepaCores.fundo,
      builder: (_) => const _FormEndereco(),
    );
    if (criado != null) {
      setState(() => _enderecoId = criado.id);
      await _carregarEnderecos();
    }
  }

  Future<void> _confirmar() async {
    if (_entrega && _enderecoId == null) {
      setState(() => _erro = 'Escolha ou cadastre o endereço de entrega.');
      return;
    }
    setState(() {
      _enviando = true;
      _erro = null;
    });
    try {
      final json = await Api.instance.post<Map<String, dynamic>>('/api/pedidos', {
        'ofertaId': widget.oferta.idApi,
        'quantidade': widget.quantidade,
        'tipoEntrega': _entrega ? 'Entrega' : 'Retirada',
        if (_entrega) 'enderecoId': _enderecoId,
        if (_observacao.text.trim().isNotEmpty) 'observacao': _observacao.text.trim(),
      });
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => PagamentoScreen(pedido: Pedido.fromJson(json))),
      );
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
    final o = widget.oferta;
    return Scaffold(
      appBar: AppBar(title: const Text('Finalizar pedido'), backgroundColor: XepaCores.fundo),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Cartao(
            child: Row(
              children: [
                Icon(o.categoria.icone, color: o.categoria.cor, size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${widget.quantidade}x ${o.titulo}', style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text(o.loja, style: const TextStyle(color: XepaCores.textoSecundario)),
                      Text('Retirada: ${o.retirada}', style: const TextStyle(color: XepaCores.textoSecundario, fontSize: 13)),
                    ],
                  ),
                ),
                Text(formatarPreco(_subtotal), style: const TextStyle(fontWeight: FontWeight.w800, color: XepaCores.verde)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('Como você quer receber?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, icon: Icon(Icons.storefront_outlined), label: Text('Retirar na loja')),
              ButtonSegment(value: true, icon: Icon(Icons.delivery_dining_outlined), label: Text('Entrega')),
            ],
            selected: {_entrega},
            onSelectionChanged: (s) => setState(() => _entrega = s.first),
          ),
          if (_entrega) ...[
            const SizedBox(height: 16),
            const Text('Entregar em', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            if (_enderecos == null)
              const LinearProgressIndicator()
            else ...[
              RadioGroup<int>(
                groupValue: _enderecoId,
                onChanged: (v) => setState(() => _enderecoId = v),
                child: Column(
                  children: [
                    for (final e in _enderecos!)
                      RadioListTile<int>(
                        value: e.id,
                        title: Text(e.apelido),
                        subtitle: Text(e.endereco.resumo),
                        contentPadding: EdgeInsets.zero,
                      ),
                  ],
                ),
              ),
              TextButton.icon(onPressed: _novoEndereco, icon: const Icon(Icons.add), label: const Text('Novo endereço')),
            ],
            const Text(
              'A taxa é calculada pela distância da rota (até 5 km) e aparece na próxima tela.',
              style: TextStyle(color: XepaCores.textoSecundario, fontSize: 13),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _observacao,
            maxLength: 500,
            decoration: const InputDecoration(labelText: 'Observação para a loja (opcional)', border: OutlineInputBorder()),
          ),
          if (_erro != null) ...[
            const SizedBox(height: 8),
            Text(_erro!, style: const TextStyle(color: XepaCores.tomateEscuro, fontWeight: FontWeight.w600)),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _enviando ? null : _confirmar,
            style: FilledButton.styleFrom(
              backgroundColor: XepaCores.tomate,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _enviando
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Confirmar e pagar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ),
        ),
      ),
    );
  }
}

class _Cartao extends StatelessWidget {
  const _Cartao({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: XepaCores.borda),
        ),
        child: child,
      );
}

/// Cadastro rápido de endereço; usa o GPS do aparelho para as coordenadas da entrega.
class _FormEndereco extends StatefulWidget {
  const _FormEndereco();

  @override
  State<_FormEndereco> createState() => _FormEnderecoState();
}

class _FormEnderecoState extends State<_FormEndereco> {
  final _form = GlobalKey<FormState>();
  final _c = {
    for (final k in ['apelido', 'cep', 'logradouro', 'numero', 'complemento', 'bairro', 'cidade', 'uf'])
      k: TextEditingController(text: k == 'apelido' ? 'Casa' : ''),
  };
  Posicao? _gps;
  bool _salvando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    Localizacao.atual().then((p) {
      if (mounted) setState(() => _gps = p);
    });
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _salvando = true;
      _erro = null;
    });
    try {
      final json = await Api.instance.post<Map<String, dynamic>>('/api/enderecos', {
        'apelido': _c['apelido']!.text.trim(),
        'cep': _c['cep']!.text.replaceAll(RegExp(r'\D'), ''),
        'logradouro': _c['logradouro']!.text.trim(),
        'numero': _c['numero']!.text.trim(),
        if (_c['complemento']!.text.trim().isNotEmpty) 'complemento': _c['complemento']!.text.trim(),
        'bairro': _c['bairro']!.text.trim(),
        'cidade': _c['cidade']!.text.trim(),
        'uf': _c['uf']!.text.trim().toUpperCase(),
        if (_gps != null) 'latitude': _gps!.latitude,
        if (_gps != null) 'longitude': _gps!.longitude,
      });
      if (mounted) Navigator.of(context).pop(EnderecoSalvo.fromJson(json));
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _erro = e.mensagem;
          _salvando = false;
        });
      }
    }
  }

  Widget _campo(String chave, String rotulo, {TextInputType? teclado, int? max, bool obrigatorio = true}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextFormField(
          controller: _c[chave],
          keyboardType: teclado,
          maxLength: max,
          decoration: InputDecoration(labelText: rotulo, border: const OutlineInputBorder(), counterText: ''),
          validator: (v) => obrigatorio && (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.viewInsetsOf(context).bottom + 16),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Novo endereço', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                _gps == null ? 'Localização do aparelho indisponível.' : 'Localização do aparelho capturada para a entrega.',
                style: const TextStyle(color: XepaCores.textoSecundario, fontSize: 13),
              ),
              const SizedBox(height: 12),
              _campo('apelido', 'Apelido (ex.: Casa)'),
              _campo('cep', 'CEP', teclado: TextInputType.number, max: 9),
              _campo('logradouro', 'Rua'),
              Row(children: [
                Expanded(child: _campo('numero', 'Número')),
                const SizedBox(width: 10),
                Expanded(flex: 2, child: _campo('complemento', 'Complemento', obrigatorio: false)),
              ]),
              _campo('bairro', 'Bairro'),
              Row(children: [
                Expanded(flex: 3, child: _campo('cidade', 'Cidade')),
                const SizedBox(width: 10),
                Expanded(child: _campo('uf', 'UF', max: 2)),
              ]),
              if (_erro != null) Text(_erro!, style: const TextStyle(color: XepaCores.tomateEscuro)),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _salvando ? null : _salvar,
                style: FilledButton.styleFrom(backgroundColor: XepaCores.tomate, minimumSize: const Size.fromHeight(48)),
                child: const Text('Salvar endereço'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
