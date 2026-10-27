import 'package:flutter/foundation.dart';

import '../models/pedido.dart';
import 'api.dart';

class PedidoAnexo {
  PedidoAnexo.fromJson(Map<String, dynamic> j)
      : id = j['id'] as int,
        loja = j['loja'] as String,
        oferta = j['oferta'] as String,
        valorTotal = (j['valorTotal'] as num).toDouble(),
        status = StatusPedido.daApi(j['status'] as String),
        entrega = j['tipoEntrega'] == 'Entrega',
        criadoEm = DateTime.parse(j['criadoEm'] as String).toLocal();

  final int id;
  final String loja;
  final String oferta;
  final double valorTotal;
  final StatusPedido status;
  final bool entrega;
  final DateTime criadoEm;
}

class MensagemSuporte {
  MensagemSuporte.fromJson(Map<String, dynamic> j)
      : id = j['id'] as int,
        doSuporte = j['doSuporte'] as bool,
        automatica = j['automatica'] as bool,
        autor = j['autor'] as String,
        texto = j['texto'] as String,
        em = DateTime.parse(j['em'] as String).toLocal(),
        pedido = j['pedido'] == null ? null : PedidoAnexo.fromJson(j['pedido'] as Map<String, dynamic>);

  final int id;
  final bool doSuporte;
  final bool automatica;
  final String autor;
  final String texto;
  final DateTime em;
  final PedidoAnexo? pedido;
}

class ConversaSuporte {
  ConversaSuporte.fromJson(Map<String, dynamic> j)
      : resolvida = j['status'] == 'Resolvida',
        atendimentoAgora = j['atendimentoAgora'] as bool,
        mensagens = [for (final m in j['mensagens'] as List) MensagemSuporte.fromJson(m as Map<String, dynamic>)];

  final bool resolvida;
  final bool atendimentoAgora;
  final List<MensagemSuporte> mensagens;
}

/// Chat com a equipe da XEPA (/api/suporte) e a bolinha de respostas não lidas no perfil.
class Suporte {
  Suporte._();

  static final Suporte instance = Suporte._();

  final naoLidas = ValueNotifier<int>(0);

  Future<ConversaSuporte> conversa({int? depois}) async => ConversaSuporte.fromJson(
      await Api.instance.get<Map<String, dynamic>>('/api/suporte', query: {if (depois != null) 'depois': depois}));

  Future<ConversaSuporte> enviar(String texto, {int? pedidoId}) async => ConversaSuporte.fromJson(await Api.instance
      .post<Map<String, dynamic>>('/api/suporte/mensagens', {'texto': texto, if (pedidoId != null) 'pedidoId': pedidoId}));

  Future<List<PedidoAnexo>> pedidos() async => [
        for (final p in await Api.instance.get<List<dynamic>>('/api/suporte/pedidos'))
          PedidoAnexo.fromJson(p as Map<String, dynamic>)
      ];

  Future<void> atualizarNaoLidas() async {
    try {
      final j = await Api.instance.get<Map<String, dynamic>>('/api/suporte/nao-lidas');
      naoLidas.value = j['naoLidas'] as int;
    } on ApiException {
      // A bolinha é só um aviso: sem rede, fica como estava.
    }
  }
}
