import 'package:latlong2/latlong.dart';

import '../models/pedido.dart';
import 'api.dart';

/// Cidade do cliente, tirada do endereço principal: o mapa e a vitrine mostram só as lojas dela.
class CidadeCliente {
  CidadeCliente._();

  static final CidadeCliente instance = CidadeCliente._();

  EnderecoSalvo? _principal;
  bool _carregado = false;

  /// Cidade do endereço principal (ou do primeiro); null quando o cliente ainda não cadastrou endereço.
  Future<String?> cidade() async => (await _endereco())?.endereco.cidade;

  /// Coordenadas do endereço principal, para centralizar o mapa quando não há GPS.
  Future<LatLng?> ponto() async {
    final e = (await _endereco())?.endereco;
    return e?.latitude == null || e?.longitude == null ? null : LatLng(e!.latitude!, e.longitude!);
  }

  /// Chamar depois de criar ou excluir endereços.
  void limpar() {
    _principal = null;
    _carregado = false;
  }

  Future<EnderecoSalvo?> _endereco() async {
    if (_carregado) return _principal;
    try {
      final lista = (await Api.instance.get<List<dynamic>>('/api/enderecos'))
          .map((e) => EnderecoSalvo.fromJson(e as Map<String, dynamic>))
          .toList();
      _principal = lista.where((e) => e.principal).firstOrNull ?? lista.firstOrNull;
      _carregado = true;
    } on ApiException {
      // Sem endereço carregado, mostra todas as lojas.
    }
    return _principal;
  }
}
