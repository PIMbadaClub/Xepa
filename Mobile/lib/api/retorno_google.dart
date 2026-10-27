import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

/// Volta do "Continuar com Google". Na web a API devolve para a própria página do app (?google=código); no Android
/// o navegador abre xepa://login?google=código e o sistema entrega o link ao app.
class RetornoGoogle {
  static const enderecoApp = 'xepa://login';

  static final _links = AppLinks();

  /// Parâmetros com que o app abriu: a query da página (web) ou do link xepa://login (Android, app fechado).
  static Future<Map<String, String>> parametrosIniciais() async {
    if (kIsWeb) return Uri.base.queryParameters;
    final uri = await _links.getInitialLink();
    return uri != null && uri.scheme == 'xepa' ? uri.queryParameters : const {};
  }

  /// Links que chegam com o app já aberto (Android): o usuário voltou do Google.
  static Stream<Map<String, String>> get chegadas => kIsWeb
      ? const Stream.empty()
      : _links.uriLinkStream.where((u) => u.scheme == 'xepa').map((u) => u.queryParameters);
}
