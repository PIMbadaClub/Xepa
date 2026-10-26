import 'package:dio/dio.dart';

class EnderecoCep {
  const EnderecoCep({required this.logradouro, required this.bairro, required this.cidade, required this.uf});

  final String logradouro;
  final String bairro;
  final String cidade;
  final String uf;
}

/// Consulta pública do ViaCEP para preencher o endereço a partir do CEP.
class Cep {
  static final _dio = Dio(BaseOptions(
    baseUrl: 'https://viacep.com.br/ws/',
    connectTimeout: const Duration(seconds: 6),
    receiveTimeout: const Duration(seconds: 6),
  ));

  /// Devolve null quando o CEP não existe ou a consulta falha.
  static Future<EnderecoCep?> buscar(String cep) async {
    final digitos = cep.replaceAll(RegExp(r'\D'), '');
    if (digitos.length != 8) return null;
    try {
      final r = await _dio.get<Map<String, dynamic>>('$digitos/json/');
      final j = r.data;
      if (j == null || j['erro'] != null) return null;
      return EnderecoCep(
        logradouro: (j['logradouro'] ?? '') as String,
        bairro: (j['bairro'] ?? '') as String,
        cidade: (j['localidade'] ?? '') as String,
        uf: (j['uf'] ?? '') as String,
      );
    } catch (_) {
      return null;
    }
  }
}
