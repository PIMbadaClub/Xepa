import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api.dart';
import '../api/localizacao.dart';
import '../api/tempo_real.dart';
import '../models/auth.dart';
import '../theme.dart';
import '../widgets/mapa_entrega.dart';
import '../widgets/oferta_widgets.dart';
import '../widgets/xepa_logo.dart';
import 'login_screen.dart';

LatLng? _ponto(Object? j) =>
    j is Map && j['latitude'] != null ? LatLng((j['latitude'] as num).toDouble(), (j['longitude'] as num).toDouble()) : null;

List<LatLng> _pontos(Object? j) => j is List ? j.map(_ponto).whereType<LatLng>().toList() : [];

String _km(double km) => '${km.toStringAsFixed(1).replaceAll('.', ',')} km';

/// Corrida como a API devolve em GET /api/entregador/corridas.
class Corrida {
  Corrida.fromJson(Map<String, dynamic> j)
      : pedidoId = j['pedidoId'] as int,
        status = j['status'] as String,
        valor = (j['valor'] as num).toDouble(),
        loja = j['loja'] as String,
        enderecoColeta = j['enderecoColeta'] as String,
        coleta = _ponto(j['coleta']),
        bairroDestino = j['bairroDestino'] as String,
        enderecoDestino = j['enderecoDestino'] as String?,
        destino = _ponto(j['destino']),
        cliente = j['cliente'] as String?,
        ateColetaKm = (j['distanciaAteColetaKm'] as num?)?.toDouble(),
        entregaKm = (j['distanciaEntregaKm'] as num).toDouble(),
        totalKm = (j['distanciaTotalKm'] as num).toDouble(),
        minutos = j['minutosEstimados'] as int,
        itens = '${j['quantidade']}x ${j['oferta']}',
        observacao = j['observacao'] as String?,
        minha = j['minha'] as bool,
        coletada = j['coletada'] as bool;

  final int pedidoId;
  final String status;
  final double valor;
  final String loja, enderecoColeta, bairroDestino, itens;
  final String? enderecoDestino, cliente, observacao;
  final LatLng? coleta, destino;
  final double? ateColetaKm;
  final double entregaKm, totalKm;
  final int minutos;
  final bool minha, coletada;

  /// A loja marcou o pedido como pronto: só então dá para coletar.
  bool get pronto => status == 'ProntoParaRetirada';
}

/// Modo entregador, no estilo dos apps de delivery: ganhos do dia, corridas perto com valor e km, aceitar.
class EntregadorScreen extends StatefulWidget {
  const EntregadorScreen({super.key});

  @override
  State<EntregadorScreen> createState() => _EntregadorScreenState();
}

class _EntregadorScreenState extends State<EntregadorScreen> {
  List<Corrida>? _corridas;
  Map<String, dynamic>? _ganhos;
  String? _erro;
  bool _disponivel = true;
  final _recusadas = <int>{};
  int? _aceitando;
  StreamSubscription<Map<String, dynamic>>? _avisos;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    TempoReal.instance.conectar();
    _avisos = TempoReal.instance.pedidoAlterado.listen((_) => _carregar());
    // A posição muda enquanto o entregador anda: recalcula as distâncias de tempos em tempos.
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _carregar());
    _carregar();
  }

  @override
  void dispose() {
    _avisos?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _carregar() async {
    final gps = await Localizacao.atual();
    try {
      final lista = await Api.instance.get<List<dynamic>>('/api/entregador/corridas', query: {
        if (gps != null) 'latitude': gps.latitude,
        if (gps != null) 'longitude': gps.longitude,
      });
      final ganhos = await Api.instance.get<Map<String, dynamic>>('/api/entregador/ganhos');
      if (!mounted) return;
      setState(() {
        _corridas = lista.map((j) => Corrida.fromJson(j as Map<String, dynamic>)).toList();
        _ganhos = ganhos;
        _erro = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    }
  }

  Future<void> _aceitar(Corrida c) async {
    setState(() => _aceitando = c.pedidoId);
    try {
      await Api.instance.post<void>('/api/entregador/corridas/${c.pedidoId}/aceitar');
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      await _abrir(c.pedidoId);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensagem)));
      _carregar();
    } finally {
      if (mounted) setState(() => _aceitando = null);
    }
  }

  Future<void> _abrir(int pedidoId) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => CorridaScreen(pedidoId: pedidoId)));
    _carregar();
  }

  Future<void> _sair() async {
    await AuthService.instance.sair();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final corridas = _corridas;
    final minha = corridas?.where((c) => c.minha).firstOrNull;
    final ofertas = corridas?.where((c) => !c.minha && !_recusadas.contains(c.pedidoId)).toList() ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const XepaMarca(tamanho: 22),
        actions: [IconButton(onPressed: _sair, icon: const Icon(Icons.logout_rounded), tooltip: 'Sair')],
      ),
      body: RefreshIndicator(
        color: XepaCores.tomate,
        onRefresh: _carregar,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Olá, ${AuthService.instance.usuario?.primeiroNome ?? ''}',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                ),
                _Disponibilidade(
                  disponivel: _disponivel,
                  onChanged: (v) => setState(() => _disponivel = v),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _CartaoGanhos(ganhos: _ganhos),
            if (_erro != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_erro!, style: const TextStyle(color: XepaCores.tomateEscuro)),
              ),
            if (minha != null) ...[
              const _Titulo('Corrida em andamento'),
              _CartaoCorrida(corrida: minha, onTap: () => _abrir(minha.pedidoId)),
            ],
            _Titulo(minha != null ? 'Próximas corridas' : 'Corridas perto de você'),
            if (corridas == null)
              const Padding(padding: EdgeInsets.all(32), child: TomateCarregando(texto: 'Procurando corridas...'))
            else if (!_disponivel)
              const EstadoVazio(
                titulo: 'Você está pausado',
                texto: 'Fique disponível para receber corridas das lojas perto de você.',
              )
            else if (ofertas.isEmpty)
              const EstadoVazio(
                titulo: 'Nenhuma corrida agora',
                texto: 'Quando uma loja aceitar um pedido com entrega perto de você, ele aparece aqui na hora.',
              )
            else
              for (final c in ofertas)
                _CartaoCorrida(
                  corrida: c,
                  aceitando: _aceitando == c.pedidoId,
                  bloqueada: minha != null,
                  onAceitar: () => _aceitar(c),
                  onRecusar: () => setState(() => _recusadas.add(c.pedidoId)),
                ),
          ],
        ),
      ),
    );
  }
}

class _Titulo extends StatelessWidget {
  const _Titulo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 10),
        child: Text(texto, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      );
}

class _Disponibilidade extends StatelessWidget {
  const _Disponibilidade({required this.disponivel, required this.onChanged});

  final bool disponivel;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => onChanged(!disponivel),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: disponivel ? XepaCores.verdeClaro : XepaCores.bege,
            borderRadius: BorderRadius.circular(XepaRaios.pilula),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: disponivel ? XepaCores.verde : XepaCores.textoSecundario,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                disponivel ? 'Disponível' : 'Pausado',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: disponivel ? XepaCores.verdeTexto : XepaCores.textoSecundario,
                ),
              ),
            ],
          ),
        ),
      );
}

class _CartaoGanhos extends StatelessWidget {
  const _CartaoGanhos({required this.ganhos});

  final Map<String, dynamic>? ganhos;

  @override
  Widget build(BuildContext context) {
    final g = ganhos;
    final hoje = (g?['ganhosHoje'] as num?)?.toDouble() ?? 0;
    final corridas = g?['corridasHoje'] as int? ?? 0;
    final km = (g?['kmHoje'] as num?)?.toDouble() ?? 0;
    final semana = (g?['ganhosSemana'] as num?)?.toDouble() ?? 0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(XepaRaios.cartao),
      child: Container(
        color: XepaCores.texto,
        child: Stack(
          children: [
            const Positioned(
              right: -24,
              bottom: -30,
              child: TomateMarcaDagua(tamanho: 130, opacidade: 0.12, angulo: -0.3, cor: Colors.white),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ganhos de hoje', style: TextStyle(color: Colors.white.withAlpha(190), fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(formatarPreco(hoje),
                      style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _Numero(valor: '$corridas', rotulo: corridas == 1 ? 'corrida' : 'corridas'),
                      _Numero(valor: _km(km), rotulo: 'rodados'),
                      _Numero(valor: formatarPreco(semana), rotulo: 'na semana'),
                    ],
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

class _Numero extends StatelessWidget {
  const _Numero({required this.valor, required this.rotulo});

  final String valor;
  final String rotulo;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(valor, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
            Text(rotulo, style: TextStyle(color: Colors.white.withAlpha(170), fontSize: 12)),
          ],
        ),
      );
}

/// Cartão da corrida: valor em destaque, km até a coleta e de entrega, tempo, loja e bairro do destino.
class _CartaoCorrida extends StatelessWidget {
  const _CartaoCorrida({
    required this.corrida,
    this.onTap,
    this.onAceitar,
    this.onRecusar,
    this.aceitando = false,
    this.bloqueada = false,
  });

  final Corrida corrida;
  final VoidCallback? onTap;
  final VoidCallback? onAceitar;
  final VoidCallback? onRecusar;
  final bool aceitando;
  final bool bloqueada;

  @override
  Widget build(BuildContext context) {
    final c = corrida;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(XepaRaios.cartao),
        border: Border.all(color: c.minha ? XepaCores.tomate : XepaCores.borda, width: c.minha ? 1.6 : 1),
        boxShadow: sombraCartao,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(XepaRaios.cartao),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(formatarPreco(c.valor),
                              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.8, color: XepaCores.verde)),
                          Text('${_km(c.totalKm)} no total · ~${c.minutos} min',
                              style: const TextStyle(color: XepaCores.textoSecundario, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    if (c.minha)
                      _Etiqueta(
                        texto: c.coletada ? 'Levando ao cliente' : (c.pronto ? 'Pronto para coletar' : 'Indo até a loja'),
                        cor: c.pronto && !c.coletada ? XepaCores.verde : XepaCores.tomate,
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                _Trecho(
                  icone: Icons.storefront_rounded,
                  cor: XepaCores.paoEscuro,
                  titulo: c.loja,
                  texto: c.enderecoColeta,
                  distancia: c.coletada ? null : (c.ateColetaKm == null ? null : '${_km(c.ateColetaKm!)} até a coleta'),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 15),
                  child: Container(width: 2, height: 14, color: XepaCores.borda),
                ),
                _Trecho(
                  icone: Icons.location_on_rounded,
                  cor: XepaCores.tomate,
                  titulo: c.cliente == null ? 'Bairro ${c.bairroDestino}' : 'Para ${c.cliente}',
                  texto: c.enderecoDestino ?? 'Endereço completo depois de aceitar',
                  distancia: '${_km(c.entregaKm)} de entrega',
                ),
                const SizedBox(height: 10),
                Text(c.itens, style: const TextStyle(color: XepaCores.textoSecundario, fontSize: 12.5)),
                if (!c.minha) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: aceitando ? null : onRecusar,
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                          child: const Text('Recusar', maxLines: 1),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          onPressed: aceitando || bloqueada ? null : onAceitar,
                          child: aceitando
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Text(bloqueada ? 'Termine a atual' : 'Aceitar corrida'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta({required this.texto, required this.cor});

  final String texto;
  final Color cor;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: cor.withAlpha(28), borderRadius: BorderRadius.circular(XepaRaios.pilula)),
        child: Text(texto, style: TextStyle(color: cor, fontWeight: FontWeight.w800, fontSize: 12)),
      );
}

class _Trecho extends StatelessWidget {
  const _Trecho({required this.icone, required this.cor, required this.titulo, required this.texto, this.distancia});

  final IconData icone;
  final Color cor;
  final String titulo;
  final String texto;
  final String? distancia;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: cor.withAlpha(30), shape: BoxShape.circle),
            child: Icon(icone, size: 18, color: cor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(texto, style: const TextStyle(color: XepaCores.textoSecundario, fontSize: 12.5)),
              ],
            ),
          ),
          if (distancia != null)
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 2),
              child: Text(distancia!, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
            ),
        ],
      );
}

// ---------------------------------------------------------------------------
// Corrida aceita: mapa com a rota real, coleta e finalização com o código do cliente.

class CorridaScreen extends StatefulWidget {
  const CorridaScreen({super.key, required this.pedidoId});

  final int pedidoId;

  @override
  State<CorridaScreen> createState() => _CorridaScreenState();
}

class _CorridaScreenState extends State<CorridaScreen> {
  /// RN09: com GPS real, a posição vai para o cliente a cada 15 s.
  static const _intervaloGps = Duration(seconds: 15);

  /// Na demonstração, a moto anda pela rota a cada 2 s, uns 120 m por passo.
  static const _intervaloSimulacao = Duration(seconds: 2);
  static const _passoSimulacaoKm = 0.12;

  final _mapa = MapController();
  // Sem arredondar: com o padrão, cada trecho de rota menor que 1 km viraria 0 km.
  final _distancia = const Distance(roundResult: false);

  ConfigMapa? _config;
  Corrida? _corrida;
  List<LatLng> _ateColeta = [];
  List<LatLng> _entrega = [];
  LatLng? _eu;
  bool _simulando = false;
  int _indiceSimulacao = 0;
  List<LatLng> _trajetoSimulado = [];
  Timer? _timer;
  bool _ocupado = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    ConfigMapa.obter().then((c) {
      if (mounted) setState(() => _config = c);
    });
    _carregar();
    _timer = Timer.periodic(_intervaloGps, (_) => _enviarGps());
    // A loja marca "pronto" pelo portal: o aviso chega em tempo real e libera o botão de coleta.
    _avisos = TempoReal.instance.pedidoAlterado.where((e) => e['pedidoId'] == widget.pedidoId).listen((_) => _carregar());
  }

  StreamSubscription<Map<String, dynamic>>? _avisos;

  @override
  void dispose() {
    _timer?.cancel();
    _avisos?.cancel();
    super.dispose();
  }

  Future<void> _carregar() async {
    final gps = await Localizacao.atual();
    try {
      final lista = await Api.instance.get<List<dynamic>>('/api/entregador/corridas', query: {
        if (gps != null) 'latitude': gps.latitude,
        if (gps != null) 'longitude': gps.longitude,
      });
      final corrida = lista
          .map((j) => Corrida.fromJson(j as Map<String, dynamic>))
          .where((c) => c.pedidoId == widget.pedidoId && c.minha)
          .firstOrNull;
      if (corrida == null) {
        if (mounted) Navigator.of(context).pop();
        return;
      }
      final origem = _eu ?? (gps == null ? null : LatLng(gps.latitude, gps.longitude));
      final rota = await Api.instance.get<Map<String, dynamic>>('/api/entregador/corridas/${widget.pedidoId}/rota', query: {
        if (origem != null) 'latitude': origem.latitude,
        if (origem != null) 'longitude': origem.longitude,
      });
      if (!mounted) return;
      setState(() {
        _corrida = corrida;
        _eu ??= origem;
        _ateColeta = _pontos(rota['ateColeta']);
        _entrega = _pontos(rota['entrega']);
        _erro = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    }
  }

  Future<void> _enviarPosicao(LatLng p) async {
    setState(() => _eu = p);
    try {
      await Api.instance.post<void>('/api/entregador/corridas/${widget.pedidoId}/localizacao',
          {'latitude': p.latitude, 'longitude': p.longitude});
    } on ApiException catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    }
  }

  Future<void> _enviarGps() async {
    if (_simulando) return;
    final gps = await Localizacao.atual();
    if (gps != null && mounted) await _enviarPosicao(LatLng(gps.latitude, gps.longitude));
  }

  // ---------- Simulação pela rota real ----------

  /// Liga a demonstração: a moto percorre o traçado pelas ruas (até a loja e, depois de coletar, até o cliente).
  void _alternarSimulacao(bool ligar) {
    _timer?.cancel();
    setState(() => _simulando = ligar);
    if (!ligar) {
      _timer = Timer.periodic(_intervaloGps, (_) => _enviarGps());
      return;
    }
    _prepararTrajeto();
    _timer = Timer.periodic(_intervaloSimulacao, (_) => _passo());
    _passo();
  }

  void _prepararTrajeto() {
    final c = _corrida;
    if (c == null) return;
    var base = c.coletada ? _entrega : (_ateColeta.length > 1 ? _ateColeta : _rotaDeAproximacao(c));
    if (base.length < 2) base = [if (c.coleta != null) c.coleta!, if (c.destino != null) c.destino!];
    _trajetoSimulado = _densificar(base);
    _indiceSimulacao = 0;
  }

  /// Sem GPS, começa ~1 km antes da loja, vindo pela rota de entrega ao contrário (ainda são ruas reais).
  List<LatLng> _rotaDeAproximacao(Corrida c) {
    final volta = _entrega.reversed.toList();
    var acumulado = 0.0;
    final trecho = <LatLng>[];
    for (var i = 0; i < volta.length; i++) {
      trecho.add(volta[i]);
      if (i > 0) acumulado += _distancia.as(LengthUnit.Kilometer, volta[i - 1], volta[i]);
      if (acumulado >= 1.0) break;
    }
    return trecho.reversed.toList();
  }

  /// Quebra o traçado em passos de ~120 m, para a moto andar suave no mapa.
  List<LatLng> _densificar(List<LatLng> rota) {
    final saida = <LatLng>[rota.first];
    for (var i = 1; i < rota.length; i++) {
      final a = rota[i - 1], b = rota[i];
      final km = _distancia.as(LengthUnit.Kilometer, a, b);
      final partes = (km / _passoSimulacaoKm).ceil();
      for (var k = 1; k <= partes; k++) {
        final t = k / partes;
        saida.add(LatLng(a.latitude + (b.latitude - a.latitude) * t, a.longitude + (b.longitude - a.longitude) * t));
      }
    }
    return saida;
  }

  void _passo() {
    if (_trajetoSimulado.isEmpty) return;
    if (_indiceSimulacao >= _trajetoSimulado.length) {
      // Chegou: na loja espera a coleta; no cliente espera o código.
      _timer?.cancel();
      setState(() => _simulando = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_corrida?.coletada == true ? 'Você chegou ao cliente. Peça o código.' : 'Você chegou à loja. Colete o pedido.'),
      ));
      return;
    }
    final p = _trajetoSimulado[_indiceSimulacao];
    _indiceSimulacao++;
    _enviarPosicao(p);
    _mapa.move(p, _mapa.camera.zoom);
  }

  // ---------- Ações ----------

  Future<void> _coletar() async {
    setState(() => _ocupado = true);
    try {
      await Api.instance.post<void>('/api/entregador/corridas/${widget.pedidoId}/coletar');
      HapticFeedback.mediumImpact();
      await _carregar();
      if (_simulando) {
        _prepararTrajeto();
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensagem)));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _finalizar() async {
    final codigo = await showDialog<String>(context: context, builder: (_) => const _DialogoCodigo());
    if (codigo == null) return;
    setState(() => _ocupado = true);
    try {
      await Api.instance.post<void>('/api/entregador/corridas/${widget.pedidoId}/concluir', {'codigo': codigo});
      // Entregue: para de mandar posição (GPS ou simulação).
      _timer?.cancel();
      _simulando = false;
      HapticFeedback.heavyImpact();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          icon: const Icon(Icons.check_circle_rounded, color: XepaCores.verde, size: 48),
          title: const Text('Entrega concluída!'),
          content: Text('Você ganhou ${formatarPreco(_corrida?.valor ?? 0)} nesta corrida. Obrigado por salvar essa comida!'),
          actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Voltar às corridas'))],
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _ocupado = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensagem)));
      }
    }
  }

  Future<void> _desistir() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Desistir da corrida?'),
        content: const Text('Ela volta para os outros entregadores.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Continuar')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Desistir')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Api.instance.post<void>('/api/entregador/corridas/${widget.pedidoId}/desistir');
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensagem)));
    }
  }

  /// Abre o Google Maps com a navegação até a loja ou o cliente.
  void _navegar(LatLng destino) => launchUrl(
        Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${destino.latitude},${destino.longitude}&travelmode=two-wheeler'),
        mode: LaunchMode.externalApplication,
      );

  @override
  Widget build(BuildContext context) {
    final c = _corrida;
    final config = _config;
    return Scaffold(
      appBar: AppBar(title: Text('Corrida #${widget.pedidoId}')),
      body: c == null || config == null
          ? Center(child: _erro == null ? const TomateCarregando() : Text(_erro!))
          : Column(
              children: [
                Expanded(child: _mapaCorrida(c, config)),
                _painel(c),
              ],
            ),
    );
  }

  Widget _mapaCorrida(Corrida c, ConfigMapa config) {
    final pontos = [
      if (_eu != null) _eu!,
      if (c.coleta != null) c.coleta!,
      if (c.destino != null) c.destino!,
    ];
    return FlutterMap(
      mapController: _mapa,
      options: MapOptions(
        initialCenter: _eu ?? c.coleta ?? const LatLng(-22.5647, -47.4017),
        initialZoom: 15,
        initialCameraFit: pontos.length > 1
            ? CameraFit.coordinates(coordinates: pontos, padding: const EdgeInsets.all(56), maxZoom: 17)
            : null,
      ),
      children: [
        TileLayer(urlTemplate: config.urlTiles, userAgentPackageName: 'app.xepa'),
        PolylineLayer(polylines: [
          if (!c.coletada && _ateColeta.length > 1)
            Polyline(points: _ateColeta, color: XepaCores.paoEscuro.withValues(alpha: 0.8), strokeWidth: 5, pattern: const StrokePattern.dotted()),
          if (_entrega.length > 1)
            Polyline(points: _entrega, color: XepaCores.tomate, strokeWidth: 6, borderColor: Colors.white, borderStrokeWidth: 2),
        ]),
        MarkerLayer(markers: [
          if (c.coleta != null) _marcador(c.coleta!, Icons.storefront_rounded, XepaCores.paoEscuro),
          if (c.destino != null) _marcador(c.destino!, Icons.home_rounded, XepaCores.verde),
          if (_eu != null)
            Marker(
              point: _eu!,
              width: 46,
              height: 46,
              child: Container(
                decoration: BoxDecoration(
                  color: XepaCores.tomate,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: const [BoxShadow(color: Color(0x55D7261E), blurRadius: 12, spreadRadius: 3)],
                ),
                child: const Icon(Icons.two_wheeler_rounded, color: Colors.white, size: 24),
              ),
            ),
        ]),
        RichAttributionWidget(attributions: [TextSourceAttribution(config.atribuicao)]),
      ],
    );
  }

  Marker _marcador(LatLng p, IconData icone, Color cor) => Marker(
        point: p,
        width: 40,
        height: 40,
        child: Container(
          decoration: BoxDecoration(color: cor, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
          child: Icon(icone, color: Colors.white, size: 20),
        ),
      );

  Widget _painel(Corrida c) {
    final indoNaLoja = !c.coletada;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Color(0x22000000), blurRadius: 16, offset: Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(indoNaLoja ? 'Vá até a loja' : 'Leve até o cliente',
                            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                        Text(
                          indoNaLoja
                              ? '${c.loja} · ${c.enderecoColeta}'
                              : '${c.cliente ?? 'Cliente'} · ${c.enderecoDestino ?? c.bairroDestino}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: XepaCores.textoSecundario, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(formatarPreco(c.valor),
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: XepaCores.verde)),
                      Text(_km(indoNaLoja ? (c.ateColetaKm ?? 0) + c.entregaKm : c.entregaKm),
                          style: const TextStyle(color: XepaCores.textoSecundario, fontSize: 12)),
                    ],
                  ),
                ],
              ),
              if (c.observacao != null && !indoNaLoja) ...[
                const SizedBox(height: 8),
                Text('Obs.: ${c.observacao}', style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 13)),
              ],
              if (indoNaLoja)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(c.pronto ? Icons.check_circle_rounded : Icons.hourglass_top_rounded,
                          size: 16, color: c.pronto ? XepaCores.verde : XepaCores.paoEscuro),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          c.pronto ? 'Pedido pronto na loja. Pode coletar!' : 'A loja ainda está preparando. Pode ir indo!',
                          style: TextStyle(
                            color: c.pronto ? XepaCores.verdeTexto : XepaCores.paoEscuro,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final alvo = indoNaLoja ? c.coleta : c.destino;
                        if (alvo != null) _navegar(alvo);
                      },
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                      icon: const Icon(Icons.navigation_rounded, size: 18),
                      label: const Text('Navegar', maxLines: 1),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _ocupado || (indoNaLoja && !c.pronto) ? null : (indoNaLoja ? _coletar : _finalizar),
                      style: indoNaLoja ? null : FilledButton.styleFrom(backgroundColor: XepaCores.verde),
                      child: Text(indoNaLoja ? (c.pronto ? 'Coletei o pedido' : 'Aguardando a loja') : 'Finalizar entrega'),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Switch(value: _simulando, onChanged: _alternarSimulacao, activeTrackColor: XepaCores.tomate),
                  const Expanded(
                    child: Text('Simular o trajeto pelas ruas (demonstração)', style: TextStyle(fontSize: 12.5)),
                  ),
                  if (indoNaLoja)
                    TextButton(
                      onPressed: _desistir,
                      style: TextButton.styleFrom(foregroundColor: XepaCores.textoSecundario),
                      child: const Text('Desistir'),
                    ),
                ],
              ),
              if (_erro != null) Text(_erro!, style: const TextStyle(color: XepaCores.tomateEscuro, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogoCodigo extends StatefulWidget {
  const _DialogoCodigo();

  @override
  State<_DialogoCodigo> createState() => _DialogoCodigoState();
}

class _DialogoCodigoState extends State<_DialogoCodigo> {
  final _codigo = TextEditingController();

  @override
  void dispose() {
    _codigo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Código do cliente'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Peça ao cliente o código de 4 dígitos que aparece no pedido dele.',
                style: TextStyle(color: XepaCores.textoSecundario)),
            const SizedBox(height: 14),
            TextField(
              controller: _codigo,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              textAlign: TextAlign.center,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 30, letterSpacing: 12, fontWeight: FontWeight.w800),
              decoration: const InputDecoration(counterText: '', hintText: '0000'),
              onSubmitted: (v) {
                if (v.length == 4) Navigator.pop(context, v);
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              if (_codigo.text.length == 4) Navigator.pop(context, _codigo.text);
            },
            child: const Text('Confirmar'),
          ),
        ],
      );
}
