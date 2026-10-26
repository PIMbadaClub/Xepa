import 'package:flutter/foundation.dart';

import 'api.dart';

/// Lojas favoritas do cliente. Guarda os ids para o coração aparecer certo em qualquer tela.
class Favoritos {
  Favoritos._();

  static final Favoritos instance = Favoritos._();

  final ids = ValueNotifier<Set<int>>({});

  Future<void> carregar() async {
    try {
      final lista = await Api.instance.get<List<dynamic>>('/api/favoritos/ids');
      ids.value = lista.map((e) => e as int).toSet();
    } on ApiException {
      // Sem favoritos carregados o app segue funcionando; o coração só aparece vazio.
    }
  }

  bool contem(int estabelecimentoId) => ids.value.contains(estabelecimentoId);

  /// Marca ou desmarca na hora e desfaz se a API recusar.
  Future<void> alternar(int estabelecimentoId) async {
    final antes = ids.value;
    final favorito = antes.contains(estabelecimentoId);
    ids.value = favorito ? ({...antes}..remove(estabelecimentoId)) : {...antes, estabelecimentoId};
    try {
      if (favorito) {
        await Api.instance.delete<void>('/api/favoritos/$estabelecimentoId');
      } else {
        await Api.instance.put<void>('/api/favoritos/$estabelecimentoId');
      }
    } on ApiException {
      ids.value = antes;
      rethrow;
    }
  }

  void limpar() => ids.value = {};
}
