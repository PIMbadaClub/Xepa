import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../api/api.dart';
import '../api/localizacao.dart';
import '../api/tempo_real.dart';
import '../models/auth.dart';
import '../theme.dart';
import '../widgets/mapa_entrega.dart';
import '../widgets/oferta_widgets.dart';
import '../widgets/xepa_logo.dart';
import 'login_screen.dart';

class _Entrega {
  _Entrega.fromJson(Map<String, dynamic> j)
      : pedidoId = j['pedidoId'] as int,
        emRota = j['status'] == 'SaiuParaEntrega',
        loja = j['loja'] as String,
        cliente = j['cliente'] as String,
        oferta = '${j['quantidade']}x ${j['oferta']}',
        origem = _ponto(j['origem']),
        destino = _ponto(j['destino']),
        endereco = j['destino'] == null ? '' : '${j['destino']['logradouro']}, ${j['destino']['numero']} · ${j['destino']['bairro']}';

  final int pedidoId;
  final bool emRota;
  final String loja, cliente, oferta, endereco;
  final LatLng? origem, destino;

  static LatLng? _ponto(Object? j) =>
      j is Map && j['latitude'] != null ? LatLng((j['latitude'] as num).toDouble(), (j['longitude'] as num).toDouble()) : null;
}

/// Modo entregador: entregas da loja em preparo, saída, envio da posição a cada 15 s (RN09) e confirmação.
class EntregadorScreen extends StatefulWidget {
  const EntregadorScreen({super.key});

  @override
  State<EntregadorScreen> createState() => _EntregadorScreenState();
}

class _EntregadorScreenState extends State<EntregadorScreen> {
  List<_Entrega>? _entregas;
  String? _erro;
  StreamSubscription<Map<String, dynamic>>? _avisos;

  @override
  void initState() {
    super.initState();
    TempoReal.instance.conectar();
    _avisos = TempoReal.instance.pedidoAlterado.listen((_) => _carregar());
    _carregar();
  }

  @override
  void dispose() {
    _avisos?.cancel();
    super.dispose();
  }

  Future<void> _carregar() async {
    try {
      final lista = await Api.instance.get<List<dynamic>>('/api/entregador/entregas');
      if (mounted) {
        setState(() {
          _entregas = lista.map((j) => _Entrega.fromJson(j as Map<String, dynamic>)).toList();
          _erro = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    }
  }

  Future<void> _iniciar(_Entrega e) async {
    try {
      await Api.instance.post<void>('/api/entregador/entregas/${e.pedidoId}/iniciar');
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => _EntregaEmCurso(entrega: e)));
      _carregar();
    } on ApiException catch (ex) {
      if (mounted) setState(() => _erro = ex.mensagem);
    }
  }

  Future<void> _sair() async {
    await AuthService.instance.sair();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entregas = _entregas;
    return Scaffold(
      appBar: AppBar(
        title: const XepaMarca(tamanho: 22),
        actions: [IconButton(onPressed: _sair, icon: const Icon(Icons.logout_rounded), tooltip: 'Sair')],
      ),
      body: RefreshIndicator(
        color: XepaCores.tomate,
        onRefresh: _carregar,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Text('Olá, ${AuthService.instance.usuario?.primeiroNome ?? ''}',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
            const Text('Suas entregas de hoje', style: TextStyle(color: XepaCores.textoSecundario)),
            const SizedBox(height: 16),
            if (_erro != null) Text(_erro!, style: const TextStyle(color: XepaCores.tomateEscuro)),
            if (entregas == null)
              const Padding(padding: EdgeInsets.all(40), child: TomateCarregando())
            else if (entregas.isEmpty)
              const EstadoVazio(
                titulo: 'Nenhuma entrega agora',
                texto: 'Quando a loja colocar um pedido em preparo, ele aparece aqui sozinho.',
              )
            else
              for (final e in entregas)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(XepaRaios.cartao),
                    border: Border.all(color: e.emRota ? XepaCores.tomate : XepaCores.borda, width: e.emRota ? 1.5 : 1),
                    boxShadow: sombraCartao,
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text('#${e.pedidoId} · ${e.oferta}',
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                            ),
                            if (e.emRota)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: XepaCores.tomateClaro, borderRadius: BorderRadius.circular(XepaRaios.pilula)),
                                child: const Text('Em rota', style: TextStyle(color: XepaCores.tomateEscuro, fontSize: 11.5, fontWeight: FontWeight.w800)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(children: [
                          const Icon(Icons.storefront_outlined, size: 16, color: XepaCores.textoSecundario),
                          const SizedBox(width: 6),
                          Expanded(child: Text(e.loja)),
                        ]),
                        const SizedBox(height: 4),
                        Row(children: [
                          const Icon(Icons.home_outlined, size: 16, color: XepaCores.textoSecundario),
                          const SizedBox(width: 6),
                          Expanded(child: Text('${e.cliente} · ${e.endereco}', style: const TextStyle(color: XepaCores.textoSecundario))),
                        ]),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () => e.emRota
                              ? Navigator.of(context)
                                  .push(MaterialPageRoute(builder: (_) => _EntregaEmCurso(entrega: e)))
                                  .then((_) => _carregar())
                              : _iniciar(e),
                          icon: Icon(e.emRota ? Icons.map_outlined : Icons.delivery_dining),
                          label: Text(e.emRota ? 'Continuar entrega' : 'Sair para entrega'),
                        ),
                      ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _EntregaEmCurso extends StatefulWidget {
  const _EntregaEmCurso({required this.entrega});

  final _Entrega entrega;

  @override
  State<_EntregaEmCurso> createState() => _EntregaEmCursoState();
}

class _EntregaEmCursoState extends State<_EntregaEmCurso> {
  static const _intervalo = Duration(seconds: 15);

  Timer? _timer;
  LatLng? _posicao;
  DateTime? _ultimoEnvio;
  bool _simulando = false;
  int _passoSimulado = 0;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _enviarPosicao();
    _timer = Timer.periodic(_intervalo, (_) => _enviarPosicao());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// GPS real; no modo de demonstração, anda em linha reta da loja até o cliente.
  Future<LatLng?> _lerPosicao() async {
    final e = widget.entrega;
    if (_simulando && e.origem != null && e.destino != null) {
      _passoSimulado = (_passoSimulado + 1).clamp(0, 10);
      final t = _passoSimulado / 10;
      return LatLng(
        e.origem!.latitude + (e.destino!.latitude - e.origem!.latitude) * t,
        e.origem!.longitude + (e.destino!.longitude - e.origem!.longitude) * t,
      );
    }
    final gps = await Localizacao.atual();
    return gps == null ? null : LatLng(gps.latitude, gps.longitude);
  }

  Future<void> _enviarPosicao() async {
    final posicao = await _lerPosicao();
    if (posicao == null) {
      if (mounted) setState(() => _erro = 'Ative a localização para o cliente acompanhar a entrega.');
      return;
    }
    try {
      await Api.instance.post<void>('/api/entregador/entregas/${widget.entrega.pedidoId}/localizacao',
          {'latitude': posicao.latitude, 'longitude': posicao.longitude});
      if (mounted) {
        setState(() {
          _posicao = posicao;
          _ultimoEnvio = DateTime.now();
          _erro = null;
        });
      }
    } on ApiException catch (ex) {
      if (mounted) setState(() => _erro = ex.mensagem);
    }
  }

  Future<void> _concluir() async {
    try {
      await Api.instance.post<void>('/api/entregador/entregas/${widget.entrega.pedidoId}/concluir');
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (ex) {
      if (mounted) setState(() => _erro = ex.mensagem);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entrega;
    return Scaffold(
      appBar: AppBar(title: Text('Entrega #${e.pedidoId}')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(XepaRaios.cartao),
            child: MapaEntrega(loja: e.origem, destino: e.destino, entregador: _posicao, altura: 300),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(e.cliente, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                Text(e.endereco),
                const SizedBox(height: 8),
                Text(
                  _ultimoEnvio == null
                      ? 'Enviando sua posição…'
                      : 'Posição enviada às ${_ultimoEnvio!.hour.toString().padLeft(2, '0')}:${_ultimoEnvio!.minute.toString().padLeft(2, '0')}:${_ultimoEnvio!.second.toString().padLeft(2, '0')} · a cada 15 s',
                  style: const TextStyle(color: XepaCores.textoSecundario),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _simulando,
                  onChanged: (v) {
                    setState(() => _simulando = v);
                    _enviarPosicao();
                  },
                  title: const Text('Simular trajeto (demonstração)'),
                ),
                if (_erro != null) Text(_erro!, style: const TextStyle(color: XepaCores.tomateEscuro)),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _concluir,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Confirmar entrega'),
                  style: FilledButton.styleFrom(backgroundColor: XepaCores.verde),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
