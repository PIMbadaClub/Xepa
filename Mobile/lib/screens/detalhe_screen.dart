import 'package:flutter/material.dart';

import '../api/api.dart';
import '../api/favoritos.dart';
import '../models/oferta.dart';
import '../theme.dart';
import '../widgets/oferta_widgets.dart';
import '../widgets/xepa_logo.dart';
import 'checkout_screen.dart';

class DetalheScreen extends StatefulWidget {
  const DetalheScreen({super.key, required this.oferta});

  final Oferta oferta;

  @override
  State<DetalheScreen> createState() => _DetalheScreenState();
}

class _DetalheScreenState extends State<DetalheScreen> {
  int _quantidade = 1;

  Oferta get _oferta => widget.oferta;

  Future<void> _alternarFavorito() async {
    final id = _oferta.estabelecimentoId;
    if (id == null) return;
    final era = Favoritos.instance.contem(id);
    try {
      await Favoritos.instance.alternar(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(era ? '${_oferta.loja} saiu dos favoritos' : '${_oferta.loja} está nos seus favoritos 🍅'),
        ));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensagem)));
    }
  }

  void _reservar() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CheckoutScreen(oferta: _oferta, quantidade: _quantidade)),
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
                SizedBox(
                  height: 260 + topo,
                  width: double.infinity,
                  child: Hero(
                    tag: 'foto-${o.id}',
                    child: FotoOferta(url: o.fotoUrl, categoria: o.categoria, tamanhoIcone: 90),
                  ),
                ),
                // Folha creme que sobe por cima da foto.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: -1,
                  child: Container(
                    height: 24,
                    decoration: const BoxDecoration(
                      color: XepaCores.fundo,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                  ),
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
                  child: ValueListenableBuilder(
                    valueListenable: Favoritos.instance.ids,
                    builder: (_, ids, __) {
                      final favorito = o.estabelecimentoId != null && ids.contains(o.estabelecimentoId);
                      return _BotaoRedondo(
                        icone: favorito ? Icons.favorite : Icons.favorite_border,
                        cor: XepaCores.tomate,
                        onTap: _alternarFavorito,
                      );
                    },
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AvatarLoja(nome: o.loja, categoria: o.categoria, logoUrl: o.logoUrl, tamanho: 40, borda: false),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(o.loja, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                            Text(
                              [
                                o.categoria.singular,
                                if (o.avaliacao != null) '★ ${formatarDecimal(o.avaliacao!)} (${o.avaliacoes})',
                                if (o.distanciaKm != null) formatarDistancia(o.distanciaKm!),
                              ].join(' · '),
                              style: const TextStyle(color: XepaCores.textoSecundario, fontSize: 12.5),
                            ),
                          ],
                        ),
                      ),
                      SeloRestantes(restantes: o.restantes, sobreFoto: false),
                    ],
                  ),
                  if (o.funcionamento != null) ...[
                    const SizedBox(height: 8),
                    _Funcionamento(oferta: o),
                  ],
                  const SizedBox(height: 14),
                  Text(
                    o.titulo,
                    style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800, letterSpacing: -0.6, height: 1.15),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: _InfoBox(rotulo: 'Retirada', valor: o.retirada)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _InfoBox(
                          rotulo: 'Você economiza',
                          valor: formatarPreco((o.precoOriginal - o.preco) * _quantidade),
                        ),
                      ),
                    ],
                  ),
                  if (o.descricao.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Text(
                      o.sacolaSurpresa ? 'O que pode vir' : 'Descrição',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
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
                  ],
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
                              color: XepaCores.tomate,
                              fontSize: 22,
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
            child: Text(o.restantes == 0 ? 'Esgotado' : 'Reservar · ${formatarPreco(o.preco * _quantidade)}'),
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
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: XepaCores.borda),
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
        borderRadius: BorderRadius.circular(XepaRaios.pilula),
        border: Border.all(color: XepaCores.borda),
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

/// "● Aberta · fecha às 20:00" com o horário da semana num toque (busca o detalhe da oferta na API).
class _Funcionamento extends StatelessWidget {
  const _Funcionamento({required this.oferta});

  final Oferta oferta;

  void _abrirHorarios(BuildContext context) {
    // Criada uma vez só: dentro do builder, cada redesenho da folha (o hover do mouse, por exemplo) refazia a chamada e piscava.
    final detalhe = Api.instance.get<Map<String, dynamic>>('/api/ofertas/${oferta.id}');
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => FutureBuilder<Map<String, dynamic>>(
        future: detalhe,
        builder: (context, snap) {
          final horarios = ((snap.data?['estabelecimento'] as Map<String, dynamic>?)?['horarios'] as List?)
              ?.cast<Map<String, dynamic>>();
          final hoje = const ['domingo', 'segunda', 'terça', 'quarta', 'quinta', 'sexta', 'sábado'][DateTime.now().weekday % 7];
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Horário da ${oferta.loja}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  if (snap.connectionState != ConnectionState.done)
                    const Center(child: Padding(padding: EdgeInsets.all(16), child: TomateCarregando()))
                  else if (horarios == null)
                    const Text('Não foi possível carregar o horário agora.', style: TextStyle(color: XepaCores.textoSecundario))
                  else
                    // Segunda primeiro, domingo por último.
                    for (final h in [...horarios.skip(1), horarios.first])
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${(h['dia'] as String)[0].toUpperCase()}${(h['dia'] as String).substring(1)}',
                                style: TextStyle(fontWeight: h['dia'] == hoje ? FontWeight.w800 : FontWeight.w500),
                              ),
                            ),
                            Text(
                              h['abre'] == null ? 'Fechada' : '${h['abre']} – ${h['fecha']}',
                              style: TextStyle(
                                fontWeight: h['dia'] == hoje ? FontWeight.w800 : FontWeight.w500,
                                color: h['abre'] == null ? XepaCores.textoSecundario : XepaCores.texto,
                              ),
                            ),
                          ],
                        ),
                      ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final aberta = oferta.aberta ?? false;
    final cor = aberta ? XepaCores.verde : XepaCores.textoSecundario;
    return InkWell(
      onTap: () => _abrirHorarios(context),
      borderRadius: BorderRadius.circular(XepaRaios.pilula),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(Icons.circle, size: 9, color: cor),
            const SizedBox(width: 6),
            Flexible(
              child: Text(oferta.funcionamento!, style: TextStyle(color: cor, fontWeight: FontWeight.w700, fontSize: 13)),
            ),
            const SizedBox(width: 4),
            const Text('· ver horários', style: TextStyle(color: XepaCores.tomateEscuro, fontWeight: FontWeight.w700, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
