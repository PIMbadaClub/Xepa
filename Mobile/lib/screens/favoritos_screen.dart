import 'package:flutter/material.dart';

import '../api/api.dart';
import '../api/favoritos.dart';
import '../models/oferta.dart';
import '../theme.dart';
import '../widgets/oferta_widgets.dart';
import '../widgets/xepa_logo.dart';
import 'detalhe_screen.dart';

/// Loja favorita como a API devolve em GET /api/favoritos.
class LojaFavorita {
  LojaFavorita.fromJson(Map<String, dynamic> j)
      : id = j['id'] as int,
        nome = j['nome'] as String,
        categoria = Categoria.values.byName((j['categoria'] as String).toLowerCase()),
        logoUrl = j['logoUrl'] as String?,
        bairro = j['bairro'] as String,
        ofertasAgora = j['ofertasAgora'] as int,
        precoMinimo = (j['precoMinimo'] as num?)?.toDouble();

  final int id;
  final String nome;
  final Categoria categoria;
  final String? logoUrl;
  final String bairro;
  final int ofertasAgora;
  final double? precoMinimo;
}

/// Aba Favoritos: as lojas que o cliente acompanha, com quantas sacolas cada uma tem agora.
class FavoritosScreen extends StatefulWidget {
  const FavoritosScreen({super.key});

  @override
  State<FavoritosScreen> createState() => _FavoritosScreenState();
}

class _FavoritosScreenState extends State<FavoritosScreen> {
  List<LojaFavorita>? _lojas;
  String? _erro;

  @override
  void initState() {
    super.initState();
    Favoritos.instance.ids.addListener(_carregar);
    _carregar();
  }

  @override
  void dispose() {
    Favoritos.instance.ids.removeListener(_carregar);
    super.dispose();
  }

  Future<void> _carregar() async {
    try {
      final lista = await Api.instance.get<List<dynamic>>('/api/favoritos');
      if (!mounted) return;
      setState(() {
        _lojas = lista.map((j) => LojaFavorita.fromJson(j as Map<String, dynamic>)).toList();
        _erro = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lojas = _lojas;
    return SafeArea(
      child: RefreshIndicator(
        color: XepaCores.tomate,
        onRefresh: _carregar,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            const Text('Favoritos', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.6)),
            const Text('Suas lojas do coração e o que elas têm agora',
                style: TextStyle(color: XepaCores.textoSecundario)),
            const SizedBox(height: 16),
            if (_erro != null)
              EstadoVazio(titulo: 'Não deu para carregar', texto: _erro, acao: 'Tentar de novo', onAcao: _carregar)
            else if (lojas == null)
              const Padding(padding: EdgeInsets.all(40), child: TomateCarregando())
            else if (lojas.isEmpty)
              const EstadoVazio(
                titulo: 'Nenhuma loja favorita ainda',
                texto: 'Toque no coração de uma oferta para acompanhar a loja e não perder a próxima xepa.',
              )
            else
              for (final l in lojas) _CartaoLoja(loja: l),
          ],
        ),
      ),
    );
  }
}

class _CartaoLoja extends StatelessWidget {
  const _CartaoLoja({required this.loja});

  final LojaFavorita loja;

  @override
  Widget build(BuildContext context) {
    final l = loja;
    final temOferta = l.ofertasAgora > 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(XepaRaios.cartao),
        border: Border.all(color: XepaCores.borda),
        boxShadow: sombraCartao,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(XepaRaios.cartao),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => OfertasDaLojaScreen(loja: l))),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                AvatarLoja(nome: l.nome, categoria: l.categoria, logoUrl: l.logoUrl, tamanho: 52, borda: false),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.nome, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      Text('${l.categoria.singular} · ${l.bairro}',
                          style: const TextStyle(color: XepaCores.textoSecundario, fontSize: 12.5)),
                      const SizedBox(height: 6),
                      Text(
                        temOferta
                            ? '${l.ofertasAgora} ${l.ofertasAgora == 1 ? 'oferta' : 'ofertas'} agora · a partir de ${formatarPreco(l.precoMinimo!)}'
                            : 'Sem ofertas no momento',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: temOferta ? XepaCores.verde : XepaCores.textoSecundario,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Tirar dos favoritos',
                  onPressed: () => Favoritos.instance.alternar(l.id),
                  icon: const Icon(Icons.favorite_rounded, color: XepaCores.tomate),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ofertas disponíveis de uma loja favorita.
class OfertasDaLojaScreen extends StatefulWidget {
  const OfertasDaLojaScreen({super.key, required this.loja});

  final LojaFavorita loja;

  @override
  State<OfertasDaLojaScreen> createState() => _OfertasDaLojaScreenState();
}

class _OfertasDaLojaScreenState extends State<OfertasDaLojaScreen> {
  List<Oferta>? _ofertas;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final pagina = await Api.instance.get<Map<String, dynamic>>('/api/ofertas',
          query: {'estabelecimentoId': widget.loja.id, 'tamanhoPagina': 50});
      if (!mounted) return;
      setState(() {
        _ofertas = (pagina['itens'] as List).map((j) => Oferta.fromJson(j as Map<String, dynamic>)).toList();
        _erro = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ofertas = _ofertas;
    return Scaffold(
      appBar: AppBar(title: Text(widget.loja.nome)),
      body: RefreshIndicator(
        color: XepaCores.tomate,
        onRefresh: _carregar,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            if (_erro != null)
              EstadoVazio(titulo: 'Não deu para carregar', texto: _erro, acao: 'Tentar de novo', onAcao: _carregar)
            else if (ofertas == null)
              const Padding(padding: EdgeInsets.all(40), child: TomateCarregando())
            else if (ofertas.isEmpty)
              const EstadoVazio(
                titulo: 'Nada por aqui agora',
                texto: 'Essa loja ainda não publicou sobras hoje. Volte perto do fechamento!',
              )
            else
              for (final o in ofertas)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: OfertaCard(
                    oferta: o,
                    onTap: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => DetalheScreen(oferta: o)))
                        .then((_) => _carregar()),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
