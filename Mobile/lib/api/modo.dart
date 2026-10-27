import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// O entregador usa a mesma conta para pedir comida: o app lembra em qual modo ele estava
/// (entregar corridas ou pedir como cliente). Quem é só cliente nunca usa isso.
class ModoApp {
  static const _cofre = FlutterSecureStorage();
  static const _chave = 'xepa_modo_cliente';

  static bool _cliente = false;

  /// Entregador navegando como cliente.
  static bool get cliente => _cliente;

  static Future<void> carregar() async {
    try {
      _cliente = await _cofre.read(key: _chave) == '1';
    } catch (_) {
      _cliente = false;
    }
  }

  static Future<void> definir({required bool cliente}) async {
    _cliente = cliente;
    try {
      cliente ? await _cofre.write(key: _chave, value: '1') : await _cofre.delete(key: _chave);
    } catch (_) {
      // Sem armazenamento, vale só nesta sessão.
    }
  }
}
