import 'package:flutter/material.dart';

import '../api/api.dart';
import '../api/cep.dart';
import '../api/localizacao.dart';
import '../models/pedido.dart';
import '../theme.dart';

/// Cadastro rápido de endereço; usa o GPS do aparelho para as coordenadas da entrega.
class FormEndereco extends StatefulWidget {
  const FormEndereco({super.key});

  @override
  State<FormEndereco> createState() => _FormEnderecoState();
}

class _FormEnderecoState extends State<FormEndereco> {
  final _form = GlobalKey<FormState>();
  final _c = {
    for (final k in ['apelido', 'cep', 'logradouro', 'numero', 'complemento', 'bairro', 'cidade', 'uf'])
      k: TextEditingController(text: k == 'apelido' ? 'Casa' : ''),
  };
  Posicao? _gps;
  bool _salvando = false;
  bool _buscandoCep = false;
  String? _cepBuscado;
  String? _erroCep;
  String? _erro;

  @override
  void initState() {
    super.initState();
    Localizacao.atual().then((p) {
      if (mounted) setState(() => _gps = p);
    });
    _c['cep']!.addListener(_cepAlterado);
  }

  /// Ao completar os 8 dígitos, preenche rua, bairro, cidade e UF pelo ViaCEP.
  Future<void> _cepAlterado() async {
    final digitos = _c['cep']!.text.replaceAll(RegExp(r'\D'), '');
    if (digitos.length != 8 || digitos == _cepBuscado) return;
    _cepBuscado = digitos;
    setState(() {
      _buscandoCep = true;
      _erroCep = null;
    });
    final e = await Cep.buscar(digitos);
    if (!mounted || _cepBuscado != digitos) return;
    setState(() {
      _buscandoCep = false;
      if (e == null) {
        _erroCep = 'CEP não encontrado. Preencha o endereço.';
        return;
      }
      if (e.logradouro.isNotEmpty) _c['logradouro']!.text = e.logradouro;
      if (e.bairro.isNotEmpty) _c['bairro']!.text = e.bairro;
      _c['cidade']!.text = e.cidade;
      _c['uf']!.text = e.uf;
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

  Widget _campo(String chave, String rotulo,
          {TextInputType? teclado, int? max, bool obrigatorio = true, Widget? sufixo, String? ajuda}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextFormField(
          controller: _c[chave],
          keyboardType: teclado,
          maxLength: max,
          decoration: InputDecoration(labelText: rotulo, counterText: '', suffixIcon: sufixo, helperText: ajuda),
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
                'O ponto de entrega vem do endereço digitado. Se você estiver nele, o GPS deixa o ponto mais preciso.',
                style: const TextStyle(color: XepaCores.textoSecundario, fontSize: 13),
              ),
              const SizedBox(height: 12),
              _campo('apelido', 'Apelido (ex.: Casa)'),
              _campo(
                'cep',
                'CEP',
                teclado: TextInputType.number,
                max: 9,
                ajuda: _erroCep,
                sufixo: _buscandoCep
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : null,
              ),
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
                child: const Text('Salvar endereço'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
