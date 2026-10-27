import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/favoritos.dart';
import '../api/notificacoes.dart';
import '../api/push.dart';
import '../api/suporte.dart';
import '../api/tempo_real.dart';
import '../models/pedido.dart';
import '../widgets/pedido_ativo.dart';
import 'favoritos_screen.dart';
import 'home_screen.dart';
import 'mapa_screen.dart';
import 'notificacoes_screen.dart';
import 'pedidos_screen.dart';
import 'perfil_screen.dart';
import 'suporte_screen.dart';

/// Estrutura do app do cliente. Cada aba tem a própria navegação, como nos apps de delivery:
/// oferta, checkout, pagamento e pedido abrem dentro da aba e o menu de baixo continua à mão.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const _abaPedidos = 2;

  int _indice = 0;
  StreamSubscription<Notificacao>? _avisos;
  StreamSubscription<Map<String, dynamic>>? _toquesPush;
  final _navegadores = List.generate(5, (_) => GlobalKey<NavigatorState>());
  late final _observadores = List.generate(5, (_) => _Observador(() => setState(() {})));

  static const _raizes = <Widget>[
    HomeScreen(),
    MapaScreen(),
    PedidosScreen(),
    FavoritosScreen(),
    PerfilScreen(),
  ];

  NavigatorState? get _atual => _navegadores[_indice].currentState;

  @override
  void initState() {
    super.initState();
    // Tempo real primeiro: notificações, barra do pedido e aba Pedidos dependem dele.
    TempoReal.instance.conectar();
    Favoritos.instance.carregar();
    Notificacoes.instance.iniciar();
    PedidosAtivos.instance.iniciar();
    Suporte.instance.atualizarNaoLidas();
    // Tocou no push "A equipe XEPA respondeu": abre o chat; aviso de pedido abre a aba Pedidos.
    _toquesPush = Push.instance.toques.stream.listen((dados) {
      if (!mounted) return;
      if (dados['tipo'] == 'suporte') {
        _atual?.push(MaterialPageRoute(builder: (_) => const SuporteScreen()));
      } else if (dados['tipo'] == 'pedido') {
        _selecionar(2);
      }
    });
    _avisos = Notificacoes.instance.novas.listen((n) {
      if (mounted) {
        AvisoNoTopo.mostrar(context, n, onTap: () {
          final ctx = _navegadores[_indice].currentContext;
          if (ctx != null) abrirNotificacao(ctx, n);
        });
      }
    });
  }

  @override
  void dispose() {
    _avisos?.cancel();
    _toquesPush?.cancel();
    super.dispose();
  }

  void _selecionar(int i) {
    if (i == _indice) {
      // Tocar de novo na aba atual volta para o começo dela.
      _atual?.popUntil((r) => r.isFirst);
      return;
    }
    setState(() => _indice = i);
  }

  /// Abre o pedido da barra na aba atual (sem cobrir o menu).
  Future<void> _abrirPedido(Pedido p) async {
    final ctx = _navegadores[_indice].currentContext;
    if (ctx == null) return;
    await abrirPedido(ctx, p);
    PedidosAtivos.instance.carregar();
  }

  /// Voltar do Android: primeiro dentro da aba, depois para o Início, e só então sai do app.
  void _voltar() {
    if (_atual?.canPop() ?? false) {
      _atual!.pop();
    } else if (_indice != 0) {
      setState(() => _indice = 0);
    } else {
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    // A barra do pedido some na aba Pedidos e quando a aba já mostra uma tela interna (pagamento, acompanhamento...).
    final mostrarBarra = _indice != _abaPedidos && !(_atual?.canPop() ?? false);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _voltar();
      },
      child: Scaffold(
        body: IndexedStack(
          index: _indice,
          children: [
            for (var i = 0; i < _raizes.length; i++)
              HeroControllerScope(
                controller: MaterialApp.createMaterialHeroController(),
                child: Navigator(
                  key: _navegadores[i],
                  observers: [_observadores[i]],
                  onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => _raizes[i]),
                ),
              ),
          ],
        ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (mostrarBarra) BarraPedidoAtivo(onAbrir: _abrirPedido),
            NavigationBar(
              selectedIndex: _indice,
              onDestinationSelected: _selecionar,
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
      ),
    );
  }
}

/// Avisa o shell quando a pilha de uma aba muda, para mostrar ou esconder a barra do pedido.
class _Observador extends NavigatorObserver {
  _Observador(this._mudou);

  final VoidCallback _mudou;

  void _avisar() => WidgetsBinding.instance.addPostFrameCallback((_) => _mudou());

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _avisar();

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _avisar();

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) => _avisar();

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) => _avisar();
}
