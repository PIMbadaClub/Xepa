import 'package:geolocator/geolocator.dart';

class Posicao {
  const Posicao(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}

/// GPS do aparelho. Sem permissão, as telas continuam funcionando sem ordenar por distância.
///
/// Nenhuma tela deve esperar o GPS para mostrar dados: o pedido de permissão pode ficar sem resposta
/// (aviso ignorado, navegador que não mostra o aviso). Carregue com [ultima] e recarregue quando [atual] chegar.
class Localizacao {
  static const _limite = Duration(seconds: 10);

  static Posicao? _ultima;
  static Future<Posicao?>? _emAndamento;

  /// Última posição conhecida, sem esperar nada.
  static Posicao? get ultima => _ultima;

  /// Posição atual, em no máximo 10 segundos (null sem permissão, sem GPS ou no tempo esgotado).
  /// Chamadas simultâneas aproveitam a mesma consulta, para não empilhar pedidos de permissão.
  static Future<Posicao?> atual() => _emAndamento ??= _buscar()
      .timeout(_limite, onTimeout: () => null)
      .whenComplete(() => _emAndamento = null);

  static Future<Posicao?> _buscar() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permissao = await Geolocator.checkPermission();
      if (permissao == LocationPermission.denied) permissao = await Geolocator.requestPermission();
      if (permissao == LocationPermission.denied || permissao == LocationPermission.deniedForever) return null;

      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 8)),
      );
      return _ultima = Posicao(p.latitude, p.longitude);
    } catch (_) {
      return null;
    }
  }
}
