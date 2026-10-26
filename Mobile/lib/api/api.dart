import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Endereço da API. Troque com --dart-define=API_URL=https://xepa-api.azurewebsites.net
/// No emulador Android, 10.0.2.2 é o localhost do computador.
const String apiUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: kIsWeb ? 'http://localhost:5000' : 'http://10.0.2.2:5000',
);

/// Endereço do portal do estabelecimento (cadastro de lojas). Troque com --dart-define=PORTAL_URL=...
const String portalUrl = String.fromEnvironment('PORTAL_URL', defaultValue: 'http://localhost:5148');

/// Erro com mensagem pronta para mostrar ao usuário (vem do ProblemDetails da API).
class ApiException implements Exception {
  ApiException(this.mensagem, {this.status});

  final String mensagem;
  final int? status;

  @override
  String toString() => mensagem;
}

/// Cliente HTTP do app. Guarda os tokens no armazenamento seguro (Keychain/Keystore)
/// e renova o token de acesso sozinho quando a API responde 401.
class Api {
  Api._() {
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await tokenAcesso();
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
      onError: (erro, handler) async {
        final req = erro.requestOptions;
        final podeRenovar = erro.response?.statusCode == 401
            && !req.path.startsWith('/api/auth/')
            && req.extra['renovado'] != true;
        if (podeRenovar && await renovarSessao()) {
          req.extra['renovado'] = true;
          req.headers['Authorization'] = 'Bearer ${await tokenAcesso()}';
          return handler.resolve(await dio.fetch(req));
        }
        handler.next(erro);
      },
    ));
  }

  static final Api instance = Api._();

  final Dio dio = Dio(BaseOptions(
    baseUrl: apiUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 20),
    contentType: 'application/json',
  ));

  final FlutterSecureStorage _cofre = const FlutterSecureStorage();
  static const _chaveAcesso = 'xepa.token';
  static const _chaveRenovacao = 'xepa.renovacao';

  /// Chamado quando a sessão expira de vez (renovação recusada): o app volta ao login.
  VoidCallback? aoExpirarSessao;

  Future<String?> tokenAcesso() => _cofre.read(key: _chaveAcesso);

  Future<void> salvarSessao(Map<String, dynamic> sessao) async {
    await _cofre.write(key: _chaveAcesso, value: sessao['tokenAcesso'] as String);
    await _cofre.write(key: _chaveRenovacao, value: sessao['tokenRenovacao'] as String);
  }

  Future<void> limparSessao() async {
    await _cofre.delete(key: _chaveAcesso);
    await _cofre.delete(key: _chaveRenovacao);
  }

  Future<String?> tokenRenovacao() => _cofre.read(key: _chaveRenovacao);

  Future<bool> renovarSessao() async {
    final renovacao = await tokenRenovacao();
    if (renovacao == null) return false;
    try {
      final resp = await dio.post<Map<String, dynamic>>('/api/auth/renovar', data: {'tokenRenovacao': renovacao});
      await salvarSessao(resp.data!);
      return true;
    } on DioException {
      await limparSessao();
      aoExpirarSessao?.call();
      return false;
    }
  }

  Future<T> get<T>(String caminho, {Map<String, dynamic>? query}) =>
      _executar(() => dio.get<T>(caminho, queryParameters: query));

  Future<T> post<T>(String caminho, [Object? corpo, Map<String, dynamic>? cabecalhos]) => _executar(() => dio.post<T>(
        caminho,
        data: corpo,
        options: cabecalhos == null ? null : Options(headers: {...cabecalhos}..removeWhere((_, v) => v == null)),
      ));

  Future<T> put<T>(String caminho, [Object? corpo]) => _executar(() => dio.put<T>(caminho, data: corpo));

  Future<T> delete<T>(String caminho) => _executar(() => dio.delete<T>(caminho));

  Future<T> _executar<T>(Future<Response<T>> Function() chamada) async {
    try {
      return (await chamada()).data as T;
    } on DioException catch (e) {
      throw ApiException(_mensagem(e), status: e.response?.statusCode);
    }
  }

  static String _mensagem(DioException e) {
    final dados = e.response?.data;
    if (dados is Map) {
      final erros = dados['errors'];
      if (erros is Map && erros.isNotEmpty) {
        final primeiro = erros.values.first;
        if (primeiro is List && primeiro.isNotEmpty) return primeiro.first.toString();
      }
      if (dados['detail'] is String) return dados['detail'] as String;
      if (dados['title'] is String) return dados['title'] as String;
    }
    return switch (e.type) {
      DioExceptionType.connectionTimeout || DioExceptionType.connectionError =>
        'Sem conexão com o XEPA. Verifique a internet e tente de novo.',
      _ when e.response?.statusCode == 429 => 'Muitas tentativas. Aguarde um minuto.',
      _ => 'Algo deu errado. Tente novamente.',
    };
  }
}
