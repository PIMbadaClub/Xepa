import 'package:flutter/material.dart';

import '../models/oferta.dart';
import '../theme.dart';

class DetalheScreen extends StatefulWidget {
  const DetalheScreen({super.key, required this.oferta});

  final Oferta oferta;

  @override
  State<DetalheScreen> createState() => _DetalheScreenState();
}

class _DetalheScreenState extends State<DetalheScreen> {
  int _quantidade = 1;
  bool _favorito = false;

  Oferta get _oferta => widget.oferta;

  void _reservar() {
    final texto = _quantidade == 1
        ? 'Sacola reservada'
        : '$_quantidade sacolas reservadas';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: XepaCores.verde,
        content: Text('$texto. Retirada: ${_oferta.retirada}.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topo = MediaQuery.paddingOf(context).top;
    final o = _oferta;

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  height: 220 + topo,
                  width: double.infinity,
                  color: o.categoria.fundo,
                  padding: EdgeInsets.only(top: topo),
                  alignment: Alignment.center,
                  child: Icon(o.categoria.icone, size: 90, color: o.categoria.cor),
                ),
                Positioned(
                  top: topo + 8,
                  left: 12,
                  child: _BotaoRedondo(
                    icone: Icons.arrow_back_rounded,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
                Positioned(
                  top: topo + 8,
                  right: 12,
                  child: _BotaoRedondo(
                    icone: _favorito ? Icons.favorite : Icons.favorite_border,
                    cor: XepaCores.tomateEscuro,
                    onTap: () => setState(() => _favorito = !_favorito),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    o.titulo,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '${o.loja} · ${formatarDistancia(o.distanciaKm)} · ',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: XepaCores.textoSecundario, fontSize: 13),
                        ),
                      ),
                      const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF2A900)),
                      Text(
                        formatarDecimal(o.avaliacao),
                        style: const TextStyle(color: XepaCores.textoSecundario, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: _InfoBox(rotulo: 'Retirada', valor: o.retirada)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _InfoBox(
                          rotulo: 'Restam',
                          valor: '${o.restantes} ${o.restantes == 1 ? 'sacola' : 'sacolas'}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'O que pode vir',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    o.descricao,
                    style: const TextStyle(
                      color: XepaCores.textoSecundario,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: XepaCores.verdeClaro,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.eco, color: XepaCores.verdeTexto, size: 26),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Com ${_quantidade == 1 ? 'essa sacola' : 'essas sacolas'} você salva cerca de '
                            '${formatarDecimal(o.kgSalvos * _quantidade)} kg de comida do lixo',
                            style: const TextStyle(color: XepaCores.verdeTexto, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      _Quantidade(
                        valor: _quantidade,
                        podeDiminuir: _quantidade > 1,
                        podeAumentar: _quantidade < o.restantes,
                        onDiminuir: () => setState(() => _quantidade--),
                        onAumentar: () => setState(() => _quantidade++),
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            formatarPreco(o.precoOriginal * _quantidade),
                            style: const TextStyle(
                              color: XepaCores.textoSecundario,
                              fontSize: 13,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          Text(
                            formatarPreco(o.preco * _quantidade),
                            style: const TextStyle(
                              color: XepaCores.verde,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: SizedBox(
          height: 54,
          child: FilledButton(
            onPressed: o.restantes == 0 ? null : _reservar,
            style: FilledButton.styleFrom(
              backgroundColor: XepaCores.tomate,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            child: Text('Reservar · ${formatarPreco(o.preco * _quantidade)}'),
          ),
        ),
      ),
    );
  }
}

class _BotaoRedondo extends StatelessWidget {
  const _BotaoRedondo({required this.icone, required this.onTap, this.cor = XepaCores.texto});

  final IconData icone;
  final VoidCallback onTap;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icone, size: 20, color: cor),
        ),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.rotulo, required this.valor});

  final String rotulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(rotulo, style: const TextStyle(color: XepaCores.textoSecundario, fontSize: 12)),
          const SizedBox(height: 2),
          Text(valor, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        ],
      ),
    );
  }
}

class _Quantidade extends StatelessWidget {
  const _Quantidade({
    required this.valor,
    required this.podeDiminuir,
    required this.podeAumentar,
    required this.onDiminuir,
    required this.onAumentar,
  });

  final int valor;
  final bool podeDiminuir;
  final bool podeAumentar;
  final VoidCallback onDiminuir;
  final VoidCallback onAumentar;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: podeDiminuir ? onDiminuir : null,
            icon: const Icon(Icons.remove_rounded),
            color: XepaCores.textoSecundario,
          ),
          Text('$valor', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          IconButton(
            onPressed: podeAumentar ? onAumentar : null,
            icon: const Icon(Icons.add_rounded),
            color: XepaCores.tomateEscuro,
          ),
        ],
      ),
    );
  }
}
