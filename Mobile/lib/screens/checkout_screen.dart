import 'package:flutter/material.dart';

import '../api/api.dart';
import '../models/oferta.dart';
import '../models/pedido.dart';
import '../theme.dart';
import '../widgets/oferta_widgets.dart';
import '../widgets/endereco_form.dart';
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
      builder: (_) => const FormEndereco(),
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
      appBar: AppBar(title: const Text('Finalizar pedido')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        children: [
          _Cartao(
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox.square(
                    dimension: 60,
                    child: FotoOferta(url: o.fotoUrl, categoria: o.categoria, tamanhoIcone: 26),
                  ),
                ),
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
                Text(formatarPreco(_subtotal), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: XepaCores.tomate)),
              ],
            ),
          ),
          const _Titulo('Como você quer receber?'),
          Row(
            children: [
              Expanded(
                child: _Opcao(
                  icone: Icons.storefront_rounded,
                  titulo: 'Retirar na loja',
                  detalhe: 'Grátis',
                  selecionada: !_entrega,
                  onTap: () => setState(() => _entrega = false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Opcao(
                  icone: Icons.delivery_dining_rounded,
                  titulo: 'Receber em casa',
                  detalhe: 'Até 5 km · taxa pela rota',
                  selecionada: _entrega,
                  onTap: () => setState(() => _entrega = true),
                ),
              ),
            ],
          ),
          if (_entrega) ...[
            const _Titulo('Entregar em'),
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
          const _Titulo('Alguma observação?'),
          TextField(
            controller: _observacao,
            maxLength: 500,
            maxLines: 2,
            decoration: const InputDecoration(hintText: 'Ex.: sem glúten, se possível (opcional)'),
          ),
          if (_erro != null) ...[
            const SizedBox(height: 8),
            Text(_erro!, style: const TextStyle(color: XepaCores.tomateEscuro, fontWeight: FontWeight.w600)),
          ],
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: XepaCores.borda)),
        ),
        child: SafeArea(
          minimum: const EdgeInsets.fromLTRB(20, 12, 20, 14),
          child: Row(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_entrega ? 'Subtotal (+ entrega)' : 'Total', style: const TextStyle(color: XepaCores.textoSecundario, fontSize: 12)),
                  Text(formatarPreco(_subtotal), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton(
                  onPressed: _enviando ? null : _confirmar,
                  child: _enviando
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Pagar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Titulo extends StatelessWidget {
  const _Titulo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 10),
        child: Text(texto, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      );
}

class _Opcao extends StatelessWidget {
  const _Opcao({
    required this.icone,
    required this.titulo,
    required this.detalhe,
    required this.selecionada,
    required this.onTap,
  });

  final IconData icone;
  final String titulo;
  final String detalhe;
  final bool selecionada;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selecionada ? XepaCores.tomateClaro : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: selecionada ? XepaCores.tomate : XepaCores.borda, width: selecionada ? 1.6 : 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icone, color: selecionada ? XepaCores.tomate : XepaCores.textoSecundario),
              const SizedBox(height: 8),
              Text(titulo, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              const SizedBox(height: 2),
              Text(detalhe, style: const TextStyle(color: XepaCores.textoSecundario, fontSize: 12)),
            ],
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
          borderRadius: BorderRadius.circular(XepaRaios.cartao),
          border: Border.all(color: XepaCores.borda),
          boxShadow: sombraCartao,
        ),
        child: child,
      );
}
