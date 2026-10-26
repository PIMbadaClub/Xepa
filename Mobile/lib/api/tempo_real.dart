import 'dart:async';

import 'package:signalr_netcore/signalr_client.dart';

import 'api.dart';

/// Conexão com o hub /hubs/pedidos da API (SignalR): status do pedido e posição do entregador.
class TempoReal {
  TempoReal._();

  static final TempoReal instance = TempoReal._();

  HubConnection? _conexao;
  final _pedidos = StreamController<Map<String, dynamic>>.broadcast();
  final _posicoes = StreamController<Map<String, dynamic>>.broadcast();

  /// Eventos {pedidoId, status} de pedidos do usuário (e da loja, no caso do entregador).
  Stream<Map<String, dynamic>> get pedidoAlterado => _pedidos.stream;

  /// Eventos {pedidoId, latitude, longitude} dos pedidos acompanhados.
  Stream<Map<String, dynamic>> get posicaoEntregador => _posicoes.stream;

  Future<void> conectar() async {
    if (_conexao?.state == HubConnectionState.Connected) return;
    final conexao = HubConnectionBuilder()
        .withUrl('$apiUrl/hubs/pedidos',
            options: HttpConnectionOptions(accessTokenFactory: () async => await Api.instance.tokenAcesso() ?? ''))
        .withAutomaticReconnect()
        .build();
    conexao.on('PedidoAlterado', (args) => _emitir(_pedidos, args));
    conexao.on('PosicaoEntregador', (args) => _emitir(_posicoes, args));
    _conexao = conexao;
    try {
      await conexao.start();
    } catch (_) {
      // Sem tempo real o app continua funcionando: as telas também atualizam ao puxar para baixo.
    }
  }

  Future<void> acompanharPedido(int pedidoId) async {
    await conectar();
    if (_conexao?.state == HubConnectionState.Connected) {
      await _conexao!.invoke('AcompanharPedido', args: [pedidoId]);
    }
  }

  Future<void> desconectar() async {
    await _conexao?.stop();
    _conexao = null;
  }

  void _emitir(StreamController<Map<String, dynamic>> destino, List<Object?>? args) {
    final dado = args?.isNotEmpty == true ? args!.first : null;
    if (dado is Map) destino.add(Map<String, dynamic>.from(dado));
  }
}
