import 'package:geolocator/geolocator.dart';

class Posicao {
  const Posicao(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}

/// GPS do aparelho. Sem permissão, as telas continuam funcionando sem ordenar por distância.
class Localizacao {
  static Future<Posicao?> atual() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permissao = await Geolocator.checkPermission();
      if (permissao == LocationPermission.denied) permissao = await Geolocator.requestPermission();
      if (permissao == LocationPermission.denied || permissao == LocationPermission.deniedForever) return null;

      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 8)),
      );
      return Posicao(p.latitude, p.longitude);
    } catch (_) {
      return null;
    }
  }
}
