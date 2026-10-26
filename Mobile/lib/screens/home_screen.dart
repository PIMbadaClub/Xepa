import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api.dart';
import '../api/localizacao.dart';

import '../models/oferta.dart';
import '../theme.dart';
import '../widgets/oferta_widgets.dart';
import '../widgets/xepa_logo.dart';
import 'detalhe_screen.dart';

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
    await _carregar();
  }

  /// Busca e categoria são filtradas na API; com localização, a lista vem da mais próxima para a mais distante.
  Future<void> _carregar() async {
    try {
      final pagina = await Api.instance.get<Map<String, dynamic>>('/api/ofertas', query: {
        if (_busca.trim().isNotEmpty) 'busca': _busca.trim(),
        if (_categoria != null) 'categoria': _categoria!.nomeApi,
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

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _carregar,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            const _Cabecalho(),
            const SizedBox(height: 10),
            _Endereco(comLocalizacao: _posicao != null),
            const SizedBox(height: 12),
            _CampoBusca(onChanged: _buscar),
            const SizedBox(height: 14),
            HoraDaXepaBanner(onVerOfertas: () => _filtrar(null)),
            const SizedBox(height: 16),
            _Categorias(
              selecionada: _categoria,
              onSelecionar: (c) => _filtrar(_categoria == c ? null : c),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Text(
                  _posicao == null ? 'Ofertas de hoje' : 'Perto de você',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => _filtrar(null),
                  style: TextButton.styleFrom(foregroundColor: XepaCores.tomateEscuro),
                  child: const Text('Ver todos'),
                ),
              ],
            ),
            if (_erro != null)
              _Falha(mensagem: _erro!, onTentar: _carregar)
            else if (ofertas == null)
              const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
            else if (ofertas.isEmpty)
              const _ListaVazia()
            else
              ...ofertas.map(
                (o) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: OfertaCard(oferta: o, onTap: () => _abrirDetalhe(o)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Falha extends StatelessWidget {
  const _Falha({required this.mensagem, required this.onTentar});

  final String mensagem;
  final VoidCallback onTentar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          const Icon(Icons.wifi_off_rounded, size: 40, color: XepaCores.textoSecundario),
          const SizedBox(height: 8),
          Text(mensagem, textAlign: TextAlign.center, style: const TextStyle(color: XepaCores.textoSecundario)),
          TextButton(onPressed: onTentar, child: const Text('Tentar de novo')),
        ],
      ),
    );
  }
}

class _Cabecalho extends StatelessWidget {
  const _Cabecalho();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const XepaLogo(tamanho: 34),
        const SizedBox(width: 8),
        Text('xepa', style: fonteMarca(tamanho: 24)),
        const Spacer(),
        IconButton(
          onPressed: () {},
          icon: const Badge(
            smallSize: 8,
            child: Icon(Icons.notifications_none_rounded, color: XepaCores.texto),
          ),
        ),
      ],
    );
  }
}

class _Endereco extends StatelessWidget {
  const _Endereco({required this.comLocalizacao});

  final bool comLocalizacao;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(comLocalizacao ? Icons.my_location_rounded : Icons.location_off_outlined,
            size: 16, color: XepaCores.tomateEscuro),
        const SizedBox(width: 4),
        Text(
          comLocalizacao ? 'Usando sua localização' : 'Localização desligada · mostrando todas',
          style: const TextStyle(fontSize: 13, color: XepaCores.textoSecundario),
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
    return TextField(
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Buscar restaurantes, padarias…',
        hintStyle: const TextStyle(color: XepaCores.textoSecundario, fontSize: 14),
        prefixIcon: const Icon(Icons.search, color: XepaCores.textoSecundario),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: Categoria.values.map((c) {
        final ativa = selecionada == c;
        return GestureDetector(
          onTap: () => onSelecionar(c),
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: ativa ? XepaCores.tomate : XepaCores.bege,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  c.icone,
                  size: 26,
                  color: ativa ? Colors.white : XepaCores.tomateEscuro,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                c.rotulo,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: ativa ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _ListaVazia extends StatelessWidget {
  const _ListaVazia();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 40, color: XepaCores.textoSecundario),
          SizedBox(height: 8),
          Text(
            'Nenhuma sacola encontrada por aqui',
            style: TextStyle(color: XepaCores.textoSecundario),
          ),
        ],
      ),
    );
  }
}
