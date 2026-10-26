import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../api/api.dart';
import '../theme.dart';

/// Configuração das imagens do mapa vinda da API: Azure Maps em produção, OpenStreetMap em testes.
class ConfigMapa {
  ConfigMapa._(this.urlTiles, this.atribuicao);

  final String urlTiles;
  final String atribuicao;

  static ConfigMapa? _cache;

  static Future<ConfigMapa> obter() async {
    if (_cache != null) return _cache!;
    try {
      final j = await Api.instance.get<Map<String, dynamic>>('/api/mapas/config');
      return _cache = ConfigMapa._(j['urlTiles'] as String, j['atribuicao'] as String);
    } on ApiException {
      return ConfigMapa._('https://tile.openstreetmap.org/{z}/{x}/{y}.png', '© colaboradores do OpenStreetMap');
    }
  }
}

/// Mapa com a loja, o destino e o entregador (que se move conforme as posições chegam).
class MapaEntrega extends StatefulWidget {
  const MapaEntrega({super.key, this.loja, this.destino, this.entregador, this.altura = 260});

  final LatLng? loja;
  final LatLng? destino;
  final LatLng? entregador;
  final double altura;

  @override
  State<MapaEntrega> createState() => _MapaEntregaState();
}

class _MapaEntregaState extends State<MapaEntrega> {
  ConfigMapa? _config;
  final _controle = MapController();

  @override
  void initState() {
    super.initState();
    ConfigMapa.obter().then((c) {
      if (mounted) setState(() => _config = c);
    });
  }

  @override
  void didUpdateWidget(MapaEntrega antigo) {
    super.didUpdateWidget(antigo);
    final e = widget.entregador;
    if (e != null && e != antigo.entregador && _config != null) {
      _controle.move(e, _controle.camera.zoom);
    }
  }

  List<LatLng> get _pontos => [widget.loja, widget.destino, widget.entregador].whereType<LatLng>().toList();

  @override
  Widget build(BuildContext context) {
    final config = _config;
    final pontos = _pontos;
    if (config == null || pontos.isEmpty) {
      return SizedBox(height: widget.altura, child: const ColoredBox(color: XepaCores.bege));
    }

    return SizedBox(
      height: widget.altura,
      child: Semantics(
        label: 'Mapa da entrega',
        child: FlutterMap(
          mapController: _controle,
          options: MapOptions(
            initialCameraFit: pontos.length > 1
                ? CameraFit.coordinates(coordinates: pontos, padding: const EdgeInsets.all(48))
                : null,
            initialCenter: pontos.first,
            initialZoom: 15,
          ),
          children: [
            TileLayer(urlTemplate: config.urlTiles, userAgentPackageName: 'app.xepa'),
            if (widget.loja != null && widget.destino != null)
              PolylineLayer(polylines: [
                Polyline(
                  points: [widget.loja!, if (widget.entregador != null) widget.entregador!, widget.destino!],
                  color: XepaCores.tomate.withValues(alpha: 0.7),
                  strokeWidth: 4,
                ),
              ]),
            MarkerLayer(markers: [
              if (widget.loja != null) _marcador(widget.loja!, Icons.storefront, XepaCores.paoEscuro, 'Loja'),
              if (widget.destino != null) _marcador(widget.destino!, Icons.home_rounded, XepaCores.verde, 'Destino'),
              if (widget.entregador != null)
                _marcador(widget.entregador!, Icons.delivery_dining, XepaCores.tomate, 'Entregador'),
            ]),
            RichAttributionWidget(attributions: [TextSourceAttribution(config.atribuicao)]),
          ],
        ),
      ),
    );
  }

  Marker _marcador(LatLng ponto, IconData icone, Color cor, String rotulo) => Marker(
        point: ponto,
        width: 40,
        height: 40,
        child: Semantics(
          label: rotulo,
          child: Container(
            decoration: BoxDecoration(color: cor, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
            child: Icon(icone, color: Colors.white, size: 20),
          ),
        ),
      );
}
