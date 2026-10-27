import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter, TextInput;

import 'package:url_launcher/url_launcher.dart';

import '../api/endereco_pagina.dart';
import '../models/auth.dart';
import '../theme.dart';
import '../widgets/auth_validadores.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/xepa_logo.dart';
import 'cadastro_screen.dart';
import 'abertura_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.erroInicial});

  /// Mensagem que voltou do login com Google (ex.: cancelado, conta de loja).
  final String? erroInicial;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _senhaCtrl = TextEditingController();

  bool _ocultarSenha = true;
  bool _carregando = false;
  String? _erro;
  AutovalidateMode _autovalidar = AutovalidateMode.disabled;

  @override
  void initState() {
    super.initState();
    _erro = widget.erroInicial;
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _senhaCtrl.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      setState(() => _autovalidar = AutovalidateMode.onUserInteraction);
      return;
    }

    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      final usuario = await AuthService.instance.login(
        email: _emailCtrl.text.trim().toLowerCase(),
        senha: _senhaCtrl.text,
      );
      if (!mounted) return;
      TextInput.finishAutofillContext();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => telaInicialPara(usuario)),
        (_) => false,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = e.mensagem;
        _carregando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _erro =
            'Não foi possível entrar agora. Verifique sua conexão e tente novamente.';
        _carregando = false;
      });
    }
  }

  void _abrirCadastro() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CadastroScreen()),
    );
  }

  Future<void> _abrirRecuperarSenha() {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: XepaCores.fundo,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _RecuperarSenhaSheet(emailInicial: _emailCtrl.text.trim()),
    );
  }

  void _loginSocial(String provedor) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('Entrar com $provedor estará disponível em breve.')),
      );
  }

  /// Vai para o Google na mesma aba; ele volta para a abertura do app com ?google=código.
  Future<void> _entrarComGoogle() async {
    final retorno = EnderecoPagina.base;
    if (retorno == null) {
      _loginSocial('Google no celular');
      return;
    }
    setState(() {
      _carregando = true;
      _erro = null;
    });
    await launchUrl(Uri.parse(AuthService.instance.urlLoginGoogle(retorno)), webOnlyWindowName: '_self');
  }

  @override
  Widget build(BuildContext context) {
    final mostrarApple = defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;

    return AuthPagina(
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _LoginHero(),
              const SizedBox(height: 28),
              const Text(
                'Entre na sua conta',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              if (_erro != null) ...[
                AuthErroBanner(mensagem: _erro!),
                const SizedBox(height: 16),
              ],
              AuthCampoTexto(
                controller: _emailCtrl,
                rotulo: 'E-mail',
                icone: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                validator: AuthValidadores.email,
                autovalidateMode: _autovalidar,
                enabled: !_carregando,
              ),
              const SizedBox(height: 14),
              AuthCampoTexto(
                controller: _senhaCtrl,
                rotulo: 'Senha',
                icone: Icons.lock_outline_rounded,
                obscureText: _ocultarSenha,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                validator: AuthValidadores.senhaLogin,
                autovalidateMode: _autovalidar,
                enabled: !_carregando,
                onFieldSubmitted: (_) => _entrar(),
                sufixo: AuthBotaoVisibilidade(
                  oculta: _ocultarSenha,
                  onPressed: () =>
                      setState(() => _ocultarSenha = !_ocultarSenha),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _carregando ? null : _abrirRecuperarSenha,
                  style: TextButton.styleFrom(
                    foregroundColor: XepaCores.tomateEscuro,
                    textStyle: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  child: const Text('Esqueci minha senha'),
                ),
              ),
              const SizedBox(height: 4),
              AuthBotaoPrimario(
                rotulo: 'Entrar',
                carregando: _carregando,
                onPressed: _entrar,
              ),
              const SizedBox(height: 24),
              const AuthDivisor(texto: 'ou continue com'),
              const SizedBox(height: 20),
              AuthBotaoSocial(
                rotulo: 'Continuar com Google',
                icone: const AuthIconeGoogle(),
                onPressed: () {
                  if (!_carregando) _entrarComGoogle();
                },
              ),
              if (mostrarApple) ...[
                const SizedBox(height: 12),
                AuthBotaoSocial(
                  rotulo: 'Continuar com Apple',
                  icone: const Icon(Icons.apple, size: 24),
                  onPressed: () => _loginSocial('Apple'),
                ),
              ],
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Novo por aqui?',
                    style: TextStyle(color: XepaCores.textoSecundario),
                  ),
                  TextButton(
                    onPressed: _carregando ? null : _abrirCadastro,
                    style: TextButton.styleFrom(
                      foregroundColor: XepaCores.tomateEscuro,
                      textStyle: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    child: const Text('Criar conta'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cartão vermelho de abertura, no mesmo estilo do banner "Hora da xepa".
class _LoginHero extends StatelessWidget {
  const _LoginHero();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        width: double.infinity,
        color: XepaCores.tomate,
        child: Stack(
          children: [
            // Tomatão escondido no canto.
            const Positioned(
              right: -40,
              bottom: -46,
              child: TomateMarcaDagua(tamanho: 190, opacidade: 0.14, angulo: -0.25, cor: Colors.white),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 28),
              child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AuthMarca(sobreFundoVermelho: true),
          const SizedBox(height: 26),
          const Text(
            'Comida boa não precisa ir pro lixo',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Resgate sacolas de padarias e restaurantes perto de você, com desconto.',
            style: TextStyle(
              color: Colors.white.withAlpha(230),
              fontSize: 15,
              height: 1.35,
            ),
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

/// Folha de "Esqueci minha senha": e-mail → código de 6 dígitos + nova senha → já entra no app.
class _RecuperarSenhaSheet extends StatefulWidget {
  const _RecuperarSenhaSheet({required this.emailInicial});

  final String emailInicial;

  @override
  State<_RecuperarSenhaSheet> createState() => _RecuperarSenhaSheetState();
}

class _RecuperarSenhaSheetState extends State<_RecuperarSenhaSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailCtrl;
  final _codigoCtrl = TextEditingController();
  final _senhaCtrl = TextEditingController();
  final _confirmacaoCtrl = TextEditingController();

  bool _carregando = false;
  bool _codigoEnviado = false;
  bool _ocultarSenha = true;
  String? _erro;
  String? _aviso;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.emailInicial);
  }

  @override
  void dispose() {
    for (final c in [_emailCtrl, _codigoCtrl, _senhaCtrl, _confirmacaoCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  String get _email => _emailCtrl.text.trim().toLowerCase();

  void _falhar(String mensagem) => setState(() {
        _erro = mensagem;
        _carregando = false;
      });

  Future<void> _enviarCodigo({bool reenvio = false}) async {
    if (!reenvio && !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _carregando = true;
      _erro = null;
      _aviso = null;
    });
    try {
      await AuthService.instance.recuperarSenha(email: _email);
      if (!mounted) return;
      setState(() {
        _codigoEnviado = true;
        _carregando = false;
        if (reenvio) _aviso = 'Se a conta existir, um novo código foi enviado.';
      });
    } on AuthException catch (e) {
      if (mounted) _falhar(e.mensagem);
    } catch (_) {
      if (mounted) _falhar('Não foi possível enviar o código agora. Tente novamente.');
    }
  }

  Future<void> _redefinir() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _carregando = true;
      _erro = null;
      _aviso = null;
    });
    try {
      final usuario = await AuthService.instance.redefinirSenha(
        email: _email,
        codigo: _codigoCtrl.text.trim(),
        novaSenha: _senhaCtrl.text,
      );
      if (!mounted) return;
      // Loja e administração usam o portal: a senha mudou, mas o app não abre para elas.
      if (usuario.perfil == PerfilUsuario.estabelecimento || usuario.perfil == PerfilUsuario.administrador) {
        await AuthService.instance.sair();
        if (!mounted) return;
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Senha alterada. Use a nova senha para entrar no portal.')),
        );
        return;
      }
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => telaInicialPara(usuario)),
        (_) => false,
      );
    } on AuthException catch (e) {
      if (mounted) _falhar(e.mensagem);
    } catch (_) {
      if (mounted) _falhar('Não foi possível trocar a senha agora. Tente novamente.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final teclado = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + teclado),
      child: SingleChildScrollView(
        child: AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.topCenter,
          child: Form(
            key: _formKey,
            child: _codigoEnviado ? _buildCodigo() : _buildEmail(),
          ),
        ),
      ),
    );
  }

  List<Widget> _mensagens() => [
        if (_erro != null) ...[AuthErroBanner(mensagem: _erro!), const SizedBox(height: 14)],
        if (_aviso != null) ...[
          Text(_aviso!, style: const TextStyle(color: XepaCores.verdeTexto, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
        ],
      ];

  Widget _buildEmail() {
    return Column(
      key: const ValueKey('email'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Recuperar senha', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        const Text(
          'Digite o e-mail da sua conta e enviaremos um código de 6 dígitos para criar uma nova senha.',
          style: TextStyle(color: XepaCores.textoSecundario, height: 1.35),
        ),
        const SizedBox(height: 18),
        ..._mensagens(),
        AuthCampoTexto(
          controller: _emailCtrl,
          rotulo: 'E-mail',
          icone: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.email],
          validator: AuthValidadores.email,
          enabled: !_carregando,
          onFieldSubmitted: (_) => _enviarCodigo(),
        ),
        const SizedBox(height: 18),
        AuthBotaoPrimario(rotulo: 'Enviar código', carregando: _carregando, onPressed: _enviarCodigo),
      ],
    );
  }

  Widget _buildCodigo() {
    return Column(
      key: const ValueKey('codigo'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(color: XepaCores.verdeClaro, shape: BoxShape.circle),
              child: const Icon(Icons.mark_email_read_outlined, color: XepaCores.verde),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Confira seu e-mail', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Se existir uma conta para ${_emailCtrl.text.trim()}, o código chega em instantes. Veja também a caixa de spam. Ele vale por 15 minutos.',
          style: const TextStyle(color: XepaCores.textoSecundario, height: 1.4),
        ),
        const SizedBox(height: 18),
        ..._mensagens(),
        TextFormField(
          controller: _codigoCtrl,
          enabled: !_carregando,
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          autofillHints: const [AutofillHints.oneTimeCode],
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(fontSize: 28, letterSpacing: 12, fontWeight: FontWeight.w800),
          decoration: const InputDecoration(counterText: '', hintText: '000000', labelText: 'Código do e-mail'),
          validator: (v) => (v == null || v.length != 6) ? 'O código tem 6 dígitos.' : null,
        ),
        const SizedBox(height: 14),
        AuthCampoTexto(
          controller: _senhaCtrl,
          rotulo: 'Nova senha',
          icone: Icons.lock_outline_rounded,
          obscureText: _ocultarSenha,
          autofillHints: const [AutofillHints.newPassword],
          validator: AuthValidadores.senhaCadastro,
          enabled: !_carregando,
          onChanged: (_) => setState(() {}),
          sufixo: AuthBotaoVisibilidade(
            oculta: _ocultarSenha,
            onPressed: () => setState(() => _ocultarSenha = !_ocultarSenha),
          ),
        ),
        const SizedBox(height: 8),
        MedidorSenha(senha: _senhaCtrl.text),
        const SizedBox(height: 14),
        AuthCampoTexto(
          controller: _confirmacaoCtrl,
          rotulo: 'Confirmar nova senha',
          icone: Icons.lock_outline_rounded,
          obscureText: _ocultarSenha,
          textInputAction: TextInputAction.done,
          validator: (v) => AuthValidadores.confirmarSenha(v, _senhaCtrl.text),
          enabled: !_carregando,
          onFieldSubmitted: (_) => _redefinir(),
        ),
        const SizedBox(height: 18),
        AuthBotaoPrimario(rotulo: 'Salvar e entrar', carregando: _carregando, onPressed: _redefinir),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: _carregando ? null : () => _enviarCodigo(reenvio: true),
              child: const Text('Mandar outro código'),
            ),
            TextButton(
              onPressed: _carregando
                  ? null
                  : () => setState(() {
                        _codigoEnviado = false;
                        _erro = null;
                        _aviso = null;
                      }),
              child: const Text('Trocar e-mail'),
            ),
          ],
        ),
      ],
    );
  }
}
