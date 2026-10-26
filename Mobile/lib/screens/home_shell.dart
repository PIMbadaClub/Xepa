import 'dart:async';

import 'package:flutter/material.dart';

import '../api/favoritos.dart';
import '../api/notificacoes.dart';
import '../api/tempo_real.dart';
import '../widgets/pedido_ativo.dart';
import 'favoritos_screen.dart';
import 'home_screen.dart';
import 'mapa_screen.dart';
import 'notificacoes_screen.dart';
import 'pedidos_screen.dart';
import 'perfil_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _indice = 0;
  StreamSubscription<Notificacao>? _avisos;

  @override
  void initState() {
    super.initState();
    // Tempo real primeiro: notificações, barra do pedido e aba Pedidos dependem dele.
    TempoReal.instance.conectar();
    Favoritos.instance.carregar();
    Notificacoes.instance.iniciar();
    PedidosAtivos.instance.iniciar();
    _avisos = Notificacoes.instance.novas.listen((n) {
      if (mounted) AvisoNoTopo.mostrar(context, n, onTap: () => abrirNotificacao(context, n));
    });
  }

  @override
  void dispose() {
    _avisos?.cancel();
    super.dispose();
  }

  static const _telas = <Widget>[
    HomeScreen(),
    MapaScreen(),
    PedidosScreen(),
    FavoritosScreen(),
    PerfilScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _indice, children: _telas),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Some na aba Pedidos, onde o andamento já está na lista.
          if (_indice != 2) const BarraPedidoAtivo(),
          NavigationBar(
            selectedIndex: _indice,
            onDestinationSelected: (i) => setState(() => _indice = i),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Início',
              ),
              NavigationDestination(
                icon: Icon(Icons.map_outlined),
                selectedIcon: Icon(Icons.map_rounded),
                label: 'Mapa',
              ),
              NavigationDestination(
                icon: Icon(Icons.shopping_bag_outlined),
                selectedIcon: Icon(Icons.shopping_bag_rounded),
                label: 'Pedidos',
              ),
              NavigationDestination(
                icon: Icon(Icons.favorite_border),
                selectedIcon: Icon(Icons.favorite),
                label: 'Favoritos',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Perfil',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
