import 'package:flutter/material.dart';

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

  List<Oferta> get _ofertasFiltradas {
    final termo = _busca.trim().toLowerCase();
    return ofertasExemplo.where((o) {
      final categoriaOk = _categoria == null || o.categoria == _categoria;
      final buscaOk = termo.isEmpty ||
          o.loja.toLowerCase().contains(termo) ||
          o.titulo.toLowerCase().contains(termo);
      return categoriaOk && buscaOk;
    }).toList();
  }

  void _abrirDetalhe(Oferta oferta) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DetalheScreen(oferta: oferta)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ofertas = _ofertasFiltradas;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const _Cabecalho(),
          const SizedBox(height: 10),
          const _Endereco(),
          const SizedBox(height: 12),
          _CampoBusca(onChanged: (valor) => setState(() => _busca = valor)),
          const SizedBox(height: 14),
          HoraDaXepaBanner(onVerOfertas: () => setState(() => _categoria = null)),
          const SizedBox(height: 16),
          _Categorias(
            selecionada: _categoria,
            onSelecionar: (c) => setState(() => _categoria = _categoria == c ? null : c),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Text(
                'Perto de você',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() => _categoria = null),
                style: TextButton.styleFrom(foregroundColor: XepaCores.tomateEscuro),
                child: const Text('Ver todos'),
              ),
            ],
          ),
          if (ofertas.isEmpty)
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
  const _Endereco();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Icon(Icons.location_on_outlined, size: 16, color: XepaCores.tomateEscuro),
        SizedBox(width: 4),
        Text(
          'Rua das Flores, 120 · Centro',
          style: TextStyle(fontSize: 13, color: XepaCores.textoSecundario),
        ),
        Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: XepaCores.textoSecundario),
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
