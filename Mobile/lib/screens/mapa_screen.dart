import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../api/api.dart';
import '../api/cidade.dart';
import '../api/localizacao.dart';
import '../models/oferta.dart';
import '../theme.dart';
import '../widgets/mapa_entrega.dart';
import '../widgets/oferta_widgets.dart';
import '../widgets/xepa_logo.dart';
import 'detalhe_screen.dart';

/// Aba Mapa: as ofertas de agora no mapa, com um cartão deslizante embaixo que acompanha o pino selecionado.
class MapaScreen extends StatefulWidget {
  const MapaScreen({super.key});

  @override
  State<MapaScreen> createState() => _MapaScreenState();
}

class _MapaScreenState extends State<MapaScreen> {
  /// Centro de Limeira: usado quando não há GPS, endereço nem ofertas.
  static const _centroPadrao = LatLng(-22.5647, -47.4017);

  final _mapa = MapController();
  final _paginas = PageController(viewportFraction: 0.88);

  ConfigMapa? _config;
  LatLng? _eu;
  String? _cidade;

  /// Endereço principal: centro do mapa quando não há GPS.
  LatLng? _casa;
  List<Oferta>? _ofertas;
  String? _erro;
  int _selecionada = 0;

  @override
  void initState() {
    super.initState();
    ConfigMapa.obter().then((c) {
      if (mounted) setState(() => _config = c);
    });
    _carregar();
    // O mapa abre sem esperar o GPS; com a posição, recarrega para marcar "você está aqui" e ordenar por distância.
    Localizacao.atual().then((p) {
      if (p != null && mounted) _carregar();
    });
  }

  @override
  void dispose() {
    _paginas.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    final posicao = Localizacao.ultima;
    final cidade = await CidadeCliente.instance.cidade();
    final casa = await CidadeCliente.instance.ponto();
    try {
      final pagina = await Api.instance.get<Map<String, dynamic>>('/api/ofertas', query: {
        if (cidade != null) 'cidade': cidade,
        if (posicao != null) 'latitude': posicao.latitude,
        if (posicao != null) 'longitude': posicao.longitude,
        'tamanhoPagina': 50,
      });
      final ofertas = (pagina['itens'] as List)
          .map((j) => Oferta.fromJson(j as Map<String, dynamic>))
          .where((o) => o.latitude != null && o.longitude != null)
          .toList();
      if (!mounted) return;
      setState(() {
        _eu = posicao == null ? null : LatLng(posicao.latitude, posicao.longitude);
        _cidade = cidade;
        _casa = casa;
        _ofertas = ofertas;
        _selecionada = 0;
        _erro = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    }
  }

  LatLng _ponto(Oferta o) => LatLng(o.latitude!, o.longitude!);

  void _selecionar(int indice, {bool rolarCartoes = true}) {
    final ofertas = _ofertas;
    if (ofertas == null || indice >= ofertas.length) return;
    final anterior = _selecionada;
    setState(() => _selecionada = indice);
    _mapa.move(_ponto(ofertas[indice]), _mapa.camera.zoom < 14 ? 15 : _mapa.camera.zoom);
    if (rolarCartoes && _paginas.hasClients) {
      // Animar até um cartão distante passava por todos os do meio, e cada um movia o mapa: pula direto.
      if ((indice - anterior).abs() == 1) {
        _paginas.animateToPage(indice, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      } else {
        _paginas.jumpToPage(indice);
      }
    }
  }

  void _centralizarEmMim() {
    if (_eu != null || _casa != null) {
      _mapa.move(_eu ?? _casa!, 15);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ative a localização para ver as ofertas perto de você.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = _config;
    final ofertas = _ofertas;

    if (_erro != null) {
      return SafeArea(
        child: Center(
          child: EstadoVazio(titulo: 'Não deu para carregar o mapa', texto: _erro, acao: 'Tentar de novo', onAcao: _carregar),
        ),
      );
    }
    if (config == null || ofertas == null) {
      return const Center(child: TomateCarregando(texto: 'Abrindo o mapa...'));
    }

    // Enquadra as lojas e a pessoa (GPS ou, sem ele, o endereço principal).
    final referencia = _eu ?? _casa;
    final pontos = [...ofertas.map(_ponto), if (referencia != null) referencia];

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapa,
          options: MapOptions(
            initialCenter: referencia ?? (ofertas.isNotEmpty ? _ponto(ofertas.first) : _centroPadrao),
            initialZoom: 14,
            initialCameraFit: pontos.length > 1
                ? CameraFit.coordinates(
                    coordinates: pontos,
                    padding: const EdgeInsets.fromLTRB(48, 140, 48, 220),
                    maxZoom: 16,
                  )
                : null,
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
          ),
          children: [
            TileLayer(urlTemplate: config.urlTiles, userAgentPackageName: 'app.xepa'),
            MarkerLayer(markers: [
              if (_eu == null && _casa != null)
                Marker(
                  point: _casa!,
                  width: 34,
                  height: 34,
                  child: Container(
                    decoration: BoxDecoration(
                      color: XepaCores.verde,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: const Icon(Icons.home_rounded, color: Colors.white, size: 16),
                  ),
                ),
              if (_eu != null)
                Marker(
                  point: _eu!,
                  width: 26,
                  height: 26,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF2F6FED),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: const [BoxShadow(color: Color(0x552F6FED), blurRadius: 12, spreadRadius: 4)],
                    ),
                  ),
                ),
              for (var i = 0; i < ofertas.length; i++)
                Marker(
                  point: _ponto(ofertas[i]),
                  width: 96,
                  height: 46,
                  alignment: Alignment.topCenter,
                  child: _Pino(
                    preco: ofertas[i].preco,
                    selecionado: i == _selecionada,
                    onTap: () => _selecionar(i),
                  ),
                ),
            ]),
            RichAttributionWidget(attributions: [TextSourceAttribution(config.atribuicao)]),
          ],
        ),

        // Cabeçalho flutuante.
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(XepaRaios.pilula),
                      boxShadow: sombraCartao,
                    ),
                    child: Row(
                      children: [
                        const XepaLogo(tamanho: 24),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            ofertas.isEmpty
                                ? 'Nenhuma oferta no mapa agora'
                                : '${ofertas.length} ${ofertas.length == 1 ? 'oferta' : 'ofertas'} ${_cidade != null ? 'em $_cidade' : (_eu == null ? 'disponíveis' : 'perto de você')}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _BotaoMapa(icone: Icons.refresh_rounded, dica: 'Atualizar', onTap: _carregar),
              ],
            ),
          ),
        ),

        Positioned(
          right: 16,
          bottom: ofertas.isEmpty ? 24 : 168,
          child: _BotaoMapa(icone: Icons.my_location_rounded, dica: 'Minha localização', onTap: _centralizarEmMim),
        ),

        if (ofertas.isEmpty)
          const Positioned(
            left: 16,
            right: 16,
            bottom: 80,
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'As lojas publicam as sobras perto do fechamento. Volte no fim da tarde!',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          )
        else
          Positioned(
            left: 0,
            right: 0,
            bottom: 16,
            height: 136,
            child: PageView.builder(
              controller: _paginas,
              itemCount: ofertas.length,
              onPageChanged: (i) => _selecionar(i, rolarCartoes: false),
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _CartaoMapa(
                  oferta: ofertas[i],
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => DetalheScreen(oferta: ofertas[i])))
                      .then((_) => _carregar()),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Pino com o preço; o selecionado fica vermelho e maior.
class _Pino extends StatelessWidget {
  const _Pino({required this.preco, required this.selecionado, required this.onTap});

  final double preco;
  final bool selecionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fundo = selecionado ? XepaCores.tomate : Colors.white;
    final texto = selecionado ? Colors.white : XepaCores.texto;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedScale(
            scale: selecionado ? 1.12 : 1,
            duration: const Duration(milliseconds: 180),
            child: Container(
              padding: const EdgeInsets.fromLTRB(6, 5, 10, 5),
              decoration: BoxDecoration(
                color: fundo,
                borderRadius: BorderRadius.circular(XepaRaios.pilula),
                boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 2))],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  XepaLogo(tamanho: 18),
                  const SizedBox(width: 4),
                  Text(formatarPreco(preco), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: texto)),
                ],
              ),
            ),
          ),
          CustomPaint(size: const Size(12, 7), painter: _Ponta(fundo)),
        ],
      ),
    );
  }
}

class _Ponta extends CustomPainter {
  _Ponta(this.cor);

  final Color cor;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = cor);
  }

  @override
  bool shouldRepaint(_Ponta antigo) => antigo.cor != cor;
}

class _BotaoMapa extends StatelessWidget {
  const _BotaoMapa({required this.icone, required this.dica, required this.onTap});

  final IconData icone;
  final String dica;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 3,
        shadowColor: Colors.black26,
        child: IconButton(tooltip: dica, onPressed: onTap, icon: Icon(icone, color: XepaCores.texto)),
      );
}

/// Cartão horizontal compacto da oferta no mapa.
class _CartaoMapa extends StatelessWidget {
  const _CartaoMapa({required this.oferta, required this.onTap});

  final Oferta oferta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final o = oferta;
    return Material(
      color: Colors.white,
      elevation: 4,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(XepaRaios.cartao),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            SizedBox(
              width: 112,
              height: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  FotoOferta(url: o.fotoUrl, categoria: o.categoria),
                  Positioned(top: 8, left: 8, child: SeloRestantes(restantes: o.restantes)),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(o.loja, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: XepaCores.textoSecundario, fontSize: 12, fontWeight: FontWeight.w700)),
                    Text(o.titulo, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(
                      [o.retirada, if (o.distanciaKm != null) formatarDistancia(o.distanciaKm!)].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: XepaCores.textoSecundario, fontSize: 12),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Text(formatarPreco(o.preco),
                            style: const TextStyle(color: XepaCores.tomate, fontWeight: FontWeight.w800, fontSize: 17)),
                        const SizedBox(width: 6),
                        Text(formatarPreco(o.precoOriginal),
                            style: const TextStyle(
                                color: XepaCores.textoSecundario, fontSize: 12, decoration: TextDecoration.lineThrough)),
                        const Spacer(),
                        SeloDesconto(percentual: o.descontoPercentual),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
