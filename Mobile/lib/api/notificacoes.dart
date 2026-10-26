import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/pedido.dart';
import 'api.dart';
import 'tempo_real.dart';

enum TipoNotificacao { pedido, denuncia, ofertaFavorita }

class Notificacao {
  Notificacao.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        tipo = TipoNotificacao.values.byName(_minuscula(j['tipo'] as String)),
        titulo = j['titulo'] as String,
        texto = j['texto'] as String,
        em = DateTime.parse(j['em'] as String).toLocal(),
        lida = j['lida'] as bool,
        pedidoId = j['pedidoId'] as int?,
        ofertaId = j['ofertaId'] as int?,
        status = j['status'] == null ? null : StatusPedido.daApi(j['status'] as String);

  final String id;
  final TipoNotificacao tipo;
  final String titulo;
  final String texto;
  final DateTime em;
  final bool lida;
  final int? pedidoId;
  final int? ofertaId;
  final StatusPedido? status;

  static String _minuscula(String s) => s[0].toLowerCase() + s.substring(1);
}

/// Central de notificações do cliente: carrega da API, conta as não lidas e avisa quando chega algo novo
/// (pelo tempo real dos pedidos ou a cada minuto, para respostas de denúncia e ofertas das favoritas).
class Notificacoes {
  Notificacoes._();

  static final Notificacoes instance = Notificacoes._();

  final itens = ValueNotifier<List<Notificacao>>([]);
  final naoLidas = ValueNotifier<int>(0);

  final _novas = StreamController<Notificacao>.broadcast();

  /// Notificações que chegaram desde a última carga, para o aviso no topo da tela.
  Stream<Notificacao> get novas => _novas.stream;

  Timer? _timer;
  StreamSubscription<Map<String, dynamic>>? _eventos;
  final _vistas = <String>{};
  bool _primeiraCarga = true;

  void iniciar() {
    _eventos ??= TempoReal.instance.pedidoAlterado.listen((_) => carregar());
    _timer ??= Timer.periodic(const Duration(minutes: 1), (_) => carregar());
    carregar();
  }

  void parar() {
    _timer?.cancel();
    _timer = null;
    _eventos?.cancel();
    _eventos = null;
    _vistas.clear();
    _primeiraCarga = true;
    itens.value = [];
    naoLidas.value = 0;
  }

  Future<void> carregar() async {
    try {
      final j = await Api.instance.get<Map<String, dynamic>>('/api/usuarios/me/notificacoes');
      final lista = (j['itens'] as List).map((e) => Notificacao.fromJson(e as Map<String, dynamic>)).toList();
      // Na primeira carga só registra o que já existia; depois, o que for novo e não lido vira aviso.
      for (final n in lista.reversed) {
        if (_vistas.add(n.id) && !_primeiraCarga && !n.lida) _novas.add(n);
      }
      _primeiraCarga = false;
      itens.value = lista;
      naoLidas.value = j['naoLidas'] as int;
    } on ApiException {
      // Sem conexão, mantém o que já tinha.
    }
  }

  Future<void> marcarLidas() async {
    if (naoLidas.value == 0) return;
    naoLidas.value = 0;
    try {
      await Api.instance.post<void>('/api/usuarios/me/notificacoes/lidas');
    } on ApiException {
      // Na próxima carga o contador volta a refletir o servidor.
    }
  }
}

/// Pedidos do cliente ainda em andamento, para a barra fixa acima do menu.
class PedidosAtivos {
  PedidosAtivos._();

  static final PedidosAtivos instance = PedidosAtivos._();

  final pedidos = ValueNotifier<List<Pedido>>([]);
  StreamSubscription<Map<String, dynamic>>? _eventos;

  void iniciar() {
    _eventos ??= TempoReal.instance.pedidoAlterado.listen((_) => carregar());
    carregar();
  }

  void parar() {
    _eventos?.cancel();
    _eventos = null;
    pedidos.value = [];
  }

  Future<void> carregar() async {
    try {
      final lista = await Api.instance.get<List<dynamic>>('/api/pedidos');
      pedidos.value = lista
          .map((j) => Pedido.fromJson(j as Map<String, dynamic>))
          .where((p) => p.status.emAndamento)
          .toList();
    } on ApiException {
      // Mantém a barra como estava.
    }
  }
}
