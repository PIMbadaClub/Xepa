import 'endereco_pagina_stub.dart' if (dart.library.js_interop) 'endereco_pagina_web.dart' as impl;

/// Endereço da página do app web (para o Google devolver o login) e limpeza dos parâmetros que voltaram nele.
/// Fora da web não há página: o login com Google é só na versão web por enquanto.
class EnderecoPagina {
  /// Endereço atual sem query nem rota (#), ex.: https://app.xepa/ ; nulo fora da web.
  static String? get base => impl.base();

  /// Tira ?google=... e ?google_erro=... da barra de endereço, para um F5 não repetir o login.
  static void limparParametros() => impl.limparParametros();
}
