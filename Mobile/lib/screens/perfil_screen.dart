import 'package:flutter/material.dart';

import '../api/api.dart';
import '../api/cidade.dart';
import '../api/notificacoes.dart';
import '../api/suporte.dart';
import '../models/auth.dart';
import 'abertura_screen.dart';
import '../models/pedido.dart';
import '../theme.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/denuncia_widgets.dart';
import '../widgets/endereco_form.dart';
import '../widgets/oferta_widgets.dart';
import '../widgets/xepa_logo.dart';
import 'login_screen.dart';
import 'cadastro_screen.dart' show abrirPaginaLegal;
import 'notificacoes_screen.dart';
import 'suporte_screen.dart';

/// Aba Perfil: dados da conta, impacto, endereços, senha, denúncias, ajuda e sair.
class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  @override
  void initState() {
    super.initState();
    Suporte.instance.atualizarNaoLidas();
  }

  Future<void> _sair() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Sair da conta?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Ficar')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Sair')),
        ],
      ),
    );
    if (confirmar != true) return;
    await AuthService.instance.sair();
    if (mounted) {
      Navigator.of(context, rootNavigator: true)
          .pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
    }
  }

  Future<void> _abrir(Widget tela) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => tela));
    if (mounted) setState(() {}); // nome ou telefone podem ter mudado
  }

  @override
  Widget build(BuildContext context) {
    final u = AuthService.instance.usuario;
    final nome = u?.nome ?? '';
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          const Text('Perfil', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.6)),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(XepaRaios.cartao),
            child: Container(
              color: XepaCores.tomate,
              child: Stack(
                children: [
                  const Positioned(
                    right: -20,
                    top: -24,
                    child: TomateMarcaDagua(tamanho: 120, opacidade: 0.15, angulo: 0.3, cor: Colors.white),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.white,
                          child: Text(nome.isEmpty ? '?' : nome[0].toUpperCase(),
                              style: const TextStyle(color: XepaCores.tomate, fontSize: 22, fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(nome, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                              Text(u?.email ?? '', style: TextStyle(color: Colors.white.withAlpha(220), fontSize: 13)),
                              if (u?.telefone != null)
                                Text(u!.telefone!, style: TextStyle(color: Colors.white.withAlpha(220), fontSize: 13)),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Editar dados',
                          onPressed: () => _abrir(const EditarDadosScreen()),
                          icon: const Icon(Icons.edit_outlined, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const _ImpactoCliente(),
          if (AuthService.instance.usuario?.perfil == PerfilUsuario.entregador) ...[
            const SizedBox(height: 16),
            _Grupo(children: [
              _ItemMenu(
                icone: Icons.two_wheeler_rounded,
                titulo: 'Voltar a entregar',
                cor: XepaCores.verde,
                onTap: () => trocarModoEntregador(context, cliente: false),
              ),
            ]),
          ],
          const _TituloGrupo('Minha conta'),
          _Grupo(children: [
            _ItemMenu(icone: Icons.person_outline_rounded, titulo: 'Meus dados', onTap: () => _abrir(const EditarDadosScreen())),
            _ItemMenu(icone: Icons.place_outlined, titulo: 'Endereços de entrega', onTap: () => _abrir(const EnderecosScreen())),
            _ItemMenu(icone: Icons.lock_outline_rounded, titulo: 'Alterar senha', onTap: () => _abrir(const AlterarSenhaScreen())),
            ValueListenableBuilder<int>(
              valueListenable: Notificacoes.instance.naoLidas,
              builder: (_, naoLidas, __) => _ItemMenu(
                icone: Icons.notifications_none_rounded,
                titulo: 'Notificações',
                selo: naoLidas > 0 ? '$naoLidas' : null,
                onTap: () => _abrir(const NotificacoesScreen()),
              ),
            ),
          ]),
          const _TituloGrupo('Ajuda'),
          _Grupo(children: [
            ValueListenableBuilder<int>(
              valueListenable: Suporte.instance.naoLidas,
              builder: (_, naoLidas, __) => _ItemMenu(
                icone: Icons.support_agent_rounded,
                titulo: 'Fale com a XEPA',
                selo: naoLidas > 0 ? '$naoLidas' : null,
                onTap: () => _abrir(const SuporteScreen()),
              ),
            ),
            _ItemMenu(icone: Icons.flag_outlined, titulo: 'Minhas denúncias', onTap: () => _abrir(const MinhasDenunciasScreen())),
            _ItemMenu(icone: Icons.help_outline_rounded, titulo: 'Como funciona a XEPA', onTap: () => _abrir(const AjudaScreen())),
          ]),
          const _TituloGrupo('Privacidade'),
          GrupoPrivacidade.grupo(context),
          const SizedBox(height: 16),
          _Grupo(children: [
            _ItemMenu(icone: Icons.logout_rounded, titulo: 'Sair', cor: XepaCores.tomateEscuro, seta: false, onTap: _sair),
          ]),
          const SizedBox(height: 28),
          const Center(child: XepaMarca(tamanho: 20)),
          const SizedBox(height: 4),
          const Center(
            child: Text('Comida boa não vai pro lixo', style: TextStyle(color: XepaCores.textoSecundario, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _TituloGrupo extends StatelessWidget {
  const _TituloGrupo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 22, 4, 8),
        child: Text(texto, style: const TextStyle(fontWeight: FontWeight.w800, color: XepaCores.textoSecundario)),
      );
}

class _Grupo extends StatelessWidget {
  const _Grupo({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(XepaRaios.cartao),
          border: Border.all(color: XepaCores.borda),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(XepaRaios.cartao),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 56),
                children[i],
              ],
            ],
          ),
        ),
      );
}

class _ItemMenu extends StatelessWidget {
  const _ItemMenu({required this.icone, required this.titulo, required this.onTap, this.selo, this.cor, this.seta = true});

  final IconData icone;
  final String titulo;
  final VoidCallback onTap;
  final String? selo;
  final Color? cor;
  final bool seta;

  @override
  Widget build(BuildContext context) => ListTile(
        onTap: onTap,
        leading: Icon(icone, color: cor ?? XepaCores.texto),
        title: Text(titulo, style: TextStyle(fontWeight: FontWeight.w700, color: cor)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selo != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: XepaCores.tomate, borderRadius: BorderRadius.circular(XepaRaios.pilula)),
                child: Text(selo!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
              ),
            if (seta) const Icon(Icons.chevron_right_rounded, color: XepaCores.textoSecundario),
          ],
        ),
      );
}

// ---------------------------------------------------------------------------
// Meus dados

class EditarDadosScreen extends StatefulWidget {
  const EditarDadosScreen({super.key});

  @override
  State<EditarDadosScreen> createState() => _EditarDadosScreenState();
}

class _EditarDadosScreenState extends State<EditarDadosScreen> {
  final _form = GlobalKey<FormState>();
  late final _nome = TextEditingController(text: AuthService.instance.usuario?.nome);
  late final _telefone = TextEditingController(text: AuthService.instance.usuario?.telefone);
  bool _salvando = false;
  String? _erro;

  @override
  void dispose() {
    _nome.dispose();
    _telefone.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _salvando = true;
      _erro = null;
    });
    try {
      await AuthService.instance.atualizarPerfil(
        nome: _nome.text.trim(),
        telefone: _telefone.text.trim().isEmpty ? null : _telefone.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dados atualizados.')));
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _erro = e.mensagem;
          _salvando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meus dados')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (_erro != null) ...[AuthErroBanner(mensagem: _erro!), const SizedBox(height: 16)],
            AuthCampoTexto(
              controller: _nome,
              rotulo: 'Nome completo',
              icone: Icons.person_outline_rounded,
              textCapitalization: TextCapitalization.words,
              validator: (v) => (v == null || v.trim().length < 3) ? 'Informe seu nome.' : null,
            ),
            const SizedBox(height: 14),
            AuthCampoTexto(
              controller: _telefone,
              rotulo: 'Celular (opcional)',
              icone: Icons.phone_iphone_rounded,
              dica: '(11) 91234-5678',
              keyboardType: TextInputType.phone,
              inputFormatters: const [MascaraDigitos('(##) #####-####')],
            ),
            const SizedBox(height: 14),
            AuthCampoTexto(
              controller: TextEditingController(text: AuthService.instance.usuario?.email),
              rotulo: 'E-mail',
              icone: Icons.mail_outline_rounded,
              ajuda: 'O e-mail é o seu login e não pode ser trocado por aqui.',
              enabled: false,
            ),
            const SizedBox(height: 24),
            AuthBotaoPrimario(rotulo: 'Salvar', carregando: _salvando, onPressed: _salvar),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Alterar senha

class AlterarSenhaScreen extends StatefulWidget {
  const AlterarSenhaScreen({super.key});

  @override
  State<AlterarSenhaScreen> createState() => _AlterarSenhaScreenState();
}

class _AlterarSenhaScreenState extends State<AlterarSenhaScreen> {
  final _form = GlobalKey<FormState>();
  final _atual = TextEditingController();
  final _nova = TextEditingController();
  final _confirmar = TextEditingController();
  bool _oculta = true;
  bool _salvando = false;
  String? _erro;

  @override
  void dispose() {
    _atual.dispose();
    _nova.dispose();
    _confirmar.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _salvando = true;
      _erro = null;
    });
    try {
      await AuthService.instance.alterarSenha(atual: _atual.text, nova: _nova.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Senha alterada. Os outros aparelhos precisam entrar de novo.')),
      );
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _erro = e.mensagem;
          _salvando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alterar senha')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (_erro != null) ...[AuthErroBanner(mensagem: _erro!), const SizedBox(height: 16)],
            AuthCampoTexto(
              controller: _atual,
              rotulo: 'Senha atual',
              icone: Icons.lock_outline_rounded,
              obscureText: _oculta,
              validator: (v) => (v == null || v.isEmpty) ? 'Informe a senha atual.' : null,
              sufixo: AuthBotaoVisibilidade(oculta: _oculta, onPressed: () => setState(() => _oculta = !_oculta)),
            ),
            const SizedBox(height: 14),
            AuthCampoTexto(
              controller: _nova,
              rotulo: 'Nova senha',
              icone: Icons.lock_reset_rounded,
              obscureText: _oculta,
              onChanged: (_) => setState(() {}),
              validator: (v) => (v == null || v.length < 8) ? 'Use ao menos 8 caracteres.' : null,
            ),
            MedidorSenha(senha: _nova.text),
            const SizedBox(height: 14),
            AuthCampoTexto(
              controller: _confirmar,
              rotulo: 'Confirmar nova senha',
              icone: Icons.lock_reset_rounded,
              obscureText: _oculta,
              textInputAction: TextInputAction.done,
              validator: (v) => v != _nova.text ? 'As senhas não conferem.' : null,
              onFieldSubmitted: (_) => _salvar(),
            ),
            const SizedBox(height: 24),
            AuthBotaoPrimario(rotulo: 'Alterar senha', carregando: _salvando, onPressed: _salvar),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Endereços

class EnderecosScreen extends StatefulWidget {
  const EnderecosScreen({super.key});

  @override
  State<EnderecosScreen> createState() => _EnderecosScreenState();
}

class _EnderecosScreenState extends State<EnderecosScreen> {
  List<EnderecoSalvo>? _enderecos;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final lista = await Api.instance.get<List<dynamic>>('/api/enderecos');
      if (mounted) {
        setState(() {
          _enderecos = lista.map((e) => EnderecoSalvo.fromJson(e as Map<String, dynamic>)).toList();
          _erro = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    }
  }

  Future<void> _novo() async {
    final criado = await showModalBottomSheet<EnderecoSalvo>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const FormEndereco(),
    );
    if (criado != null) {
      CidadeCliente.instance.limpar();
      _carregar();
    }
  }

  Future<void> _excluir(EnderecoSalvo e) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Excluir "${e.apelido}"?'),
        content: Text(e.endereco.resumo),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Manter')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Excluir')),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await Api.instance.delete<void>('/api/enderecos/${e.id}');
      CidadeCliente.instance.limpar();
      _carregar();
    } on ApiException catch (ex) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ex.mensagem)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final enderecos = _enderecos;
    return Scaffold(
      appBar: AppBar(title: const Text('Endereços de entrega')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _novo,
        backgroundColor: XepaCores.tomate,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Novo endereço', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: _erro != null
          ? Center(child: EstadoVazio(titulo: 'Não deu para carregar', texto: _erro, acao: 'Tentar de novo', onAcao: _carregar))
          : enderecos == null
              ? const Center(child: TomateCarregando())
              : enderecos.isEmpty
                  ? const Center(
                      child: EstadoVazio(
                        titulo: 'Nenhum endereço salvo',
                        texto: 'Cadastre um endereço para receber pedidos em casa (até 5 km da loja).',
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
                      children: [
                        for (final e in enderecos)
                          Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(XepaRaios.cartao),
                              border: Border.all(color: e.principal ? XepaCores.tomate : XepaCores.borda),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
                              leading: Icon(e.principal ? Icons.home_rounded : Icons.place_outlined,
                                  color: e.principal ? XepaCores.tomate : XepaCores.textoSecundario),
                              title: Row(
                                children: [
                                  Text(e.apelido, style: const TextStyle(fontWeight: FontWeight.w800)),
                                  if (e.principal) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: XepaCores.tomateClaro,
                                        borderRadius: BorderRadius.circular(XepaRaios.pilula),
                                      ),
                                      child: const Text('Principal',
                                          style: TextStyle(color: XepaCores.tomateEscuro, fontSize: 11, fontWeight: FontWeight.w800)),
                                    ),
                                  ],
                                ],
                              ),
                              subtitle: Text(e.endereco.resumo),
                              trailing: IconButton(
                                tooltip: 'Excluir',
                                onPressed: () => _excluir(e),
                                icon: const Icon(Icons.delete_outline_rounded),
                              ),
                            ),
                          ),
                      ],
                    ),
    );
  }
}

// ---------------------------------------------------------------------------
// Minhas denúncias

class MinhasDenunciasScreen extends StatefulWidget {
  const MinhasDenunciasScreen({super.key});

  @override
  State<MinhasDenunciasScreen> createState() => _MinhasDenunciasScreenState();
}

class _MinhasDenunciasScreenState extends State<MinhasDenunciasScreen> {
  List<Denuncia>? _denuncias;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final lista = await Api.instance.get<List<dynamic>>('/api/usuarios/me/denuncias');
      if (mounted) {
        setState(() {
          _denuncias = lista.map((j) => Denuncia.fromJson(j as Map<String, dynamic>)).toList();
          _erro = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    }
  }

  @override
  Widget build(BuildContext context) {
    final denuncias = _denuncias;
    return Scaffold(
      appBar: AppBar(title: const Text('Minhas denúncias')),
      body: _erro != null
          ? Center(child: EstadoVazio(titulo: 'Não deu para carregar', texto: _erro, acao: 'Tentar de novo', onAcao: _carregar))
          : denuncias == null
              ? const Center(child: TomateCarregando())
              : denuncias.isEmpty
                  ? const Center(
                      child: EstadoVazio(
                        titulo: 'Nenhuma denúncia',
                        texto: 'Se algo der errado num pedido, abra o pedido e toque em "Algo deu errado? Denunciar".',
                      ),
                    )
                  : RefreshIndicator(
                      color: XepaCores.tomate,
                      onRefresh: _carregar,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        children: [for (final d in denuncias) CartaoDenuncia(denuncia: d, mostrarPedido: true)],
                      ),
                    ),
    );
  }
}

// ---------------------------------------------------------------------------
// Ajuda

class AjudaScreen extends StatelessWidget {
  const AjudaScreen({super.key});

  static const _perguntas = [
    (
      'O que é a XEPA?',
      'Um app que conecta você a padarias, restaurantes, mercados e feiras que têm comida boa sobrando no fim do dia. '
          'Você compra com desconto e a comida não vai pro lixo.'
    ),
    (
      'O que vem na sacola surpresa?',
      'Depende do que sobrou no dia. A descrição da oferta dá uma ideia do que pode vir, e o peso estimado mostra o tamanho.'
    ),
    (
      'Como retiro meu pedido?',
      'Vá até a loja no horário de retirada e mostre o código de 4 dígitos que aparece no pedido.'
    ),
    (
      'E a entrega?',
      'Algumas lojas entregam até 5 km. A taxa é calculada pela rota e aparece antes do pagamento. Você acompanha o entregador no mapa.'
    ),
    (
      'Posso cancelar?',
      'Sim, até a loja aceitar o pedido. Se você já pagou, o valor é estornado integralmente.'
    ),
    (
      'Algo deu errado. E agora?',
      'Abra o pedido e toque em "Algo deu errado? Denunciar". A equipe da XEPA analisa e responde no próprio pedido. '
          'Casos de discriminação são tratados com prioridade.'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Como funciona')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(XepaRaios.cartao),
            child: Container(
              color: XepaCores.verdeClaro,
              padding: const EdgeInsets.all(18),
              child: const Row(
                children: [
                  XepaLogo(tamanho: 48),
                  SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Quase 1/3 da comida do mundo se perde ou vai pro lixo. Cada sacola resgatada é comida no prato, não no aterro.',
                      style: TextStyle(color: XepaCores.verdeTexto, fontWeight: FontWeight.w700, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final (pergunta, resposta) in _perguntas)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: XepaCores.borda),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  title: Text(pergunta, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  expandedAlignment: Alignment.centerLeft,
                  iconColor: XepaCores.tomate,
                  children: [Text(resposta, style: const TextStyle(color: XepaCores.textoSecundario, height: 1.45))],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

/// "Sua xepa": quanto o cliente já salvou do lixo e economizou.
class _ImpactoCliente extends StatefulWidget {
  const _ImpactoCliente();

  @override
  State<_ImpactoCliente> createState() => _ImpactoClienteState();
}

class _ImpactoClienteState extends State<_ImpactoCliente> {
  Map<String, dynamic>? _impacto;

  @override
  void initState() {
    super.initState();
    Api.instance.get<Map<String, dynamic>>('/api/usuarios/me/impacto').then((j) {
      if (mounted) setState(() => _impacto = j);
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final i = _impacto;
    final pedidos = (i?['pedidos'] as int?) ?? 0;
    final kg = (i?['kgSalvos'] as num?)?.toDouble() ?? 0;
    final economia = (i?['economia'] as num?)?.toDouble() ?? 0;

    Widget numero(String valor, String rotulo) => Expanded(
          child: Column(
            children: [
              Text(valor, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: XepaCores.verdeTexto)),
              const SizedBox(height: 2),
              Text(rotulo, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11.5, color: XepaCores.verdeTexto)),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: XepaCores.verdeClaro, borderRadius: BorderRadius.circular(XepaRaios.cartao)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.eco_rounded, color: XepaCores.verde, size: 20),
              SizedBox(width: 6),
              Text('Sua xepa', style: TextStyle(fontWeight: FontWeight.w800, color: XepaCores.verdeTexto, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 12),
          if (i == null)
            const Center(child: Padding(padding: EdgeInsets.all(8), child: TomateCarregando(tamanho: 24)))
          else if (pedidos == 0)
            const Text('Seu primeiro resgate vai aparecer aqui: quanta comida você salvou e quanto economizou.',
                style: TextStyle(color: XepaCores.verdeTexto, height: 1.4))
          else
            Row(
              children: [
                numero('${formatarDecimal(kg)} kg', 'de comida salva do lixo'),
                numero(formatarPreco(economia), 'economizados'),
                numero('$pedidos', pedidos == 1 ? 'resgate' : 'resgates'),
              ],
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Privacidade (LGPD)

/// Termos, política de privacidade e exclusão da conta; usado no perfil do cliente e no do entregador.
class GrupoPrivacidade {
  static Widget grupo(BuildContext context) => _Grupo(children: [
        _ItemMenu(icone: Icons.description_outlined, titulo: 'Termos de uso', onTap: () => abrirPaginaLegal('termos')),
        _ItemMenu(icone: Icons.privacy_tip_outlined, titulo: 'Política de privacidade', onTap: () => abrirPaginaLegal('privacidade')),
        _ItemMenu(
          icone: Icons.delete_outline_rounded,
          titulo: 'Excluir minha conta',
          cor: XepaCores.tomateEscuro,
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ExcluirContaScreen())),
        ),
      ]);
}

/// Exclusão da conta pelo próprio titular (LGPD, art. 18): explica o que some e o que fica, pede a senha e EXCLUIR.
class ExcluirContaScreen extends StatefulWidget {
  const ExcluirContaScreen({super.key});

  @override
  State<ExcluirContaScreen> createState() => _ExcluirContaScreenState();
}

class _ExcluirContaScreenState extends State<ExcluirContaScreen> {
  final _senha = TextEditingController();
  final _confirmacao = TextEditingController();
  bool _excluindo = false;
  bool _ocultar = true;
  String? _erro;

  @override
  void dispose() {
    _senha.dispose();
    _confirmacao.dispose();
    super.dispose();
  }

  bool get _confirmado => _confirmacao.text.trim().toUpperCase() == 'EXCLUIR';

  Future<void> _excluir() async {
    setState(() {
      _excluindo = true;
      _erro = null;
    });
    try {
      await AuthService.instance.excluirConta(senha: _senha.text.isEmpty ? null : _senha.text);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(
            builder: (_) => const LoginScreen(erroInicial: 'Sua conta foi excluída. Obrigado por salvar comida com a gente!')),
        (_) => false,
      );
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _erro = e.mensagem;
          _excluindo = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const estilo = TextStyle(height: 1.45);
    return Scaffold(
      appBar: AppBar(title: const Text('Excluir minha conta')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: XepaCores.tomateClaro, borderRadius: BorderRadius.circular(XepaRaios.cartao)),
            child: const Text(
              'Excluir a conta não dá para desfazer. Se quiser só dar um tempo, é só sair da conta.',
              style: TextStyle(fontWeight: FontWeight.w700, color: XepaCores.tomateEscuro, height: 1.4),
            ),
          ),
          const SizedBox(height: 18),
          const Text('O que apagamos na hora', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 6),
          const Text(
            '• Nome, e-mail, celular e placa da moto\n'
            '• Endereços salvos e lojas favoritas\n'
            '• Conversas com o suporte e celulares cadastrados para notificação\n'
            '• Todas as sessões abertas',
            style: estilo,
          ),
          const SizedBox(height: 14),
          const Text('O que fica, sem identificar você', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 6),
          const Text(
            'Os pedidos e pagamentos, pelo prazo que a lei fiscal exige, para a loja e a contabilidade da XEPA.',
            style: estilo,
          ),
          const SizedBox(height: 22),
          TextField(
            controller: _senha,
            obscureText: _ocultar,
            enabled: !_excluindo,
            decoration: InputDecoration(
              labelText: 'Sua senha',
              helperText: 'Entrou só com o Google e nunca criou senha? Deixe em branco.',
              helperMaxLines: 2,
              suffixIcon: IconButton(
                onPressed: () => setState(() => _ocultar = !_ocultar),
                icon: Icon(_ocultar ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _confirmacao,
            enabled: !_excluindo,
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Digite EXCLUIR para confirmar'),
          ),
          if (_erro != null) ...[
            const SizedBox(height: 14),
            AuthErroBanner(mensagem: _erro!),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _confirmado && !_excluindo ? _excluir : null,
            style: FilledButton.styleFrom(backgroundColor: XepaCores.tomateEscuro, minimumSize: const Size.fromHeight(52)),
            child: _excluindo
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                : const Text('Excluir minha conta', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}
