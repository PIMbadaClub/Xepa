import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api.dart';
import '../api/cidade.dart';
import '../api/localizacao.dart';
import '../api/notificacoes.dart';
import '../models/auth.dart';
import '../models/oferta.dart';
import '../theme.dart';
import '../widgets/oferta_widgets.dart';
import '../widgets/xepa_logo.dart';
import 'detalhe_screen.dart';
import 'notificacoes_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Categoria? _categoria;
  String _busca = '';
  Timer? _atrasoBusca;
  Posicao? _posicao;
  String? _cidade;
  List<Oferta>? _ofertas;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  @override
  void dispose() {
    _atrasoBusca?.cancel();
    super.dispose();
  }

  Future<void> _iniciar() async {
    _posicao = await Localizacao.atual();
    _cidade = await CidadeCliente.instance.cidade();
    await _carregar();
  }

  /// Busca e categoria são filtradas na API; com localização, a lista vem da mais próxima para a mais distante.
  Future<void> _carregar() async {
    try {
      final pagina = await Api.instance.get<Map<String, dynamic>>('/api/ofertas', query: {
        if (_busca.trim().isNotEmpty) 'busca': _busca.trim(),
        if (_categoria != null) 'categoria': _categoria!.nomeApi,
        if (_cidade != null) 'cidade': _cidade,
        if (_posicao != null) 'latitude': _posicao!.latitude,
        if (_posicao != null) 'longitude': _posicao!.longitude,
        'tamanhoPagina': 50,
      });
      if (!mounted) return;
      setState(() {
        _ofertas = (pagina['itens'] as List).map((j) => Oferta.fromJson(j as Map<String, dynamic>)).toList();
        _erro = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    }
  }

  void _buscar(String valor) {
    _busca = valor;
    _atrasoBusca?.cancel();
    _atrasoBusca = Timer(const Duration(milliseconds: 400), _carregar);
  }

  void _filtrar(Categoria? categoria) {
    setState(() => _categoria = categoria);
    _carregar();
  }

  void _abrirDetalhe(Oferta oferta) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DetalheScreen(oferta: oferta)),
    ).then((_) => _carregar());
  }

  @override
  Widget build(BuildContext context) {
    final ofertas = _ofertas;
    final semFiltro = _busca.trim().isEmpty && _categoria == null;
    // "Acabando logo": as que têm poucas unidades, só na tela sem busca nem filtro.
    final acabando = semFiltro && ofertas != null
        ? (ofertas.where((o) => o.restantes > 0 && o.restantes <= 3).toList()
          ..sort((a, b) => a.restantes.compareTo(b.restantes)))
        : <Oferta>[];
    final precoMinimo = ofertas == null || ofertas.isEmpty
        ? null
        : ofertas.map((o) => o.preco).reduce((a, b) => a < b ? a : b);

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: XepaCores.tomate,
        onRefresh: _carregar,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 8, 0),
              child: _Cabecalho(comLocalizacao: _posicao != null, cidade: _cidade),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: _Saudacao(quantidade: ofertas?.fold<int>(0, (total, o) => total + o.restantes)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: _CampoBusca(onChanged: _buscar),
            ),
            const SizedBox(height: 12),
            _Categorias(
              selecionada: _categoria,
              onSelecionar: (c) => _filtrar(_categoria == c ? null : c),
            ),
            if (semFiltro) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: HoraDaXepaBanner(
                  quantidade: ofertas?.length ?? 0,
                  precoMinimo: precoMinimo,
                  onVerOfertas: () => _filtrar(null),
                ),
              ),
            ],
            if (acabando.isNotEmpty) ...[
              const _TituloSecao(titulo: 'Acabando logo'),
              SizedBox(
                height: 262,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  itemCount: acabando.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, i) => OfertaCard(
                    oferta: acabando[i],
                    largura: 230,
                    alturaFoto: 120,
                    onTap: () => _abrirDetalhe(acabando[i]),
                  ),
                ),
              ),
            ],
            _TituloSecao(
              titulo: _categoria?.rotulo ?? (_posicao == null ? 'Ofertas de hoje' : 'Perto de você'),
              acao: _categoria != null ? 'Limpar filtro' : null,
              onAcao: () => _filtrar(null),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  if (_erro != null)
                    EstadoVazio(
                      titulo: 'Não deu para carregar as ofertas',
                      texto: _erro,
                      acao: 'Tentar de novo',
                      onAcao: _carregar,
                    )
                  else if (ofertas == null)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: TomateCarregando(texto: 'Procurando sacolas...'),
                    )
                  else if (ofertas.isEmpty)
                    const EstadoVazio(
                      titulo: 'Nenhuma sacola por aqui',
                      texto: 'Tente outra busca ou volte mais tarde: as lojas publicam perto do fechamento.',
                    )
                  else
                    for (final o in ofertas)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: OfertaCard(oferta: o, onTap: () => _abrirDetalhe(o)),
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

class _TituloSecao extends StatelessWidget {
  const _TituloSecao({required this.titulo, this.acao, this.onAcao});

  final String titulo;
  final String? acao;
  final VoidCallback? onAcao;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 8, 8),
      child: SizedBox(
        height: 36,
        child: Row(
          children: [
            Text(titulo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.2)),
            const Spacer(),
            if (acao != null) TextButton(onPressed: onAcao, child: Text(acao!)),
          ],
        ),
      ),
    );
  }
}

class _Cabecalho extends StatelessWidget {
  const _Cabecalho({required this.comLocalizacao, this.cidade});

  final bool comLocalizacao;
  final String? cidade;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const XepaMarca(tamanho: 26),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(XepaRaios.pilula),
            border: Border.all(color: XepaCores.borda),
          ),
          child: Row(
            children: [
              Icon(comLocalizacao ? Icons.near_me_rounded : Icons.location_off_outlined,
                  size: 14, color: XepaCores.tomate),
              const SizedBox(width: 4),
              Text(
                cidade ?? (comLocalizacao ? 'Perto de mim' : 'Todas as lojas'),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        ValueListenableBuilder<int>(
          valueListenable: Notificacoes.instance.naoLidas,
          builder: (context, naoLidas, _) => IconButton(
            tooltip: naoLidas == 0 ? 'Notificações' : '$naoLidas notificações novas',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificacoesScreen())),
            icon: Badge.count(
              count: naoLidas,
              isLabelVisible: naoLidas > 0,
              backgroundColor: XepaCores.tomate,
              child: Icon(
                naoLidas > 0 ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
                color: XepaCores.texto,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Saudacao extends StatelessWidget {
  const _Saudacao({required this.quantidade});

  final int? quantidade;

  @override
  Widget build(BuildContext context) {
    final hora = DateTime.now().hour;
    final periodo = hora >= 5 && hora < 12 ? 'Bom dia' : (hora >= 12 && hora < 18 ? 'Boa tarde' : 'Boa noite');
    final nome = AuthService.instance.usuario?.nome.split(' ').first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          nome == null ? '$periodo!' : '$periodo, $nome',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5, height: 1.15),
        ),
        const SizedBox(height: 4),
        Text(
          switch (quantidade) {
            null => 'Vendo o que sobrou de bom hoje...',
            0 => 'Nenhuma sacola agora. As lojas publicam perto do fechamento.',
            1 => '1 sacola esperando resgate',
            _ => '$quantidade sacolas esperando resgate',
          },
          style: const TextStyle(color: XepaCores.textoSecundario, fontSize: 13.5),
        ),
      ],
    );
  }
}

class _CampoBusca extends StatelessWidget {
  const _CampoBusca({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final borda = OutlineInputBorder(
      borderRadius: BorderRadius.circular(XepaRaios.pilula),
      borderSide: const BorderSide(color: XepaCores.borda),
    );
    return TextField(
      onChanged: onChanged,
      onSubmitted: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Buscar padarias, mercados...',
        hintStyle: const TextStyle(color: XepaCores.textoSecundario, fontSize: 14),
        prefixIcon: const Icon(Icons.search_rounded, color: XepaCores.textoSecundario),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: borda,
        enabledBorder: borda,
        focusedBorder: borda.copyWith(borderSide: const BorderSide(color: XepaCores.tomate, width: 1.4)),
      ),
    );
  }
}

class _Categorias extends StatelessWidget {
  const _Categorias({required this.selecionada, required this.onSelecionar});

  final Categoria? selecionada;
  final ValueChanged<Categoria> onSelecionar;

  @override
  Widget build(BuildContext context) {
    Widget chip(String rotulo, IconData? icone, bool ativo, VoidCallback onTap) => ChoiceChip(
          selected: ativo,
          onSelected: (_) => onTap(),
          avatar: icone == null
              ? null
              : Icon(icone, size: 16, color: ativo ? Colors.white : XepaCores.tomateEscuro),
          label: Text(rotulo),
        );

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          chip('Todos', null, selecionada == null, () {
            if (selecionada != null) onSelecionar(selecionada!);
          }),
          for (final c in Categoria.values) ...[
            const SizedBox(width: 8),
            chip(c.rotulo, c.icone, selecionada == c, () => onSelecionar(c)),
          ],
        ],
      ),
    );
  }
}
