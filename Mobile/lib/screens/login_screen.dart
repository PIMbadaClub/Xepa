import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show TextInput;

import '../models/auth.dart';
import '../theme.dart';
import '../widgets/auth_validadores.dart';
import '../widgets/auth_widgets.dart';
import 'cadastro_screen.dart';
import 'home_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

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
      await AuthService.instance.login(
        email: _emailCtrl.text.trim().toLowerCase(),
        senha: _senhaCtrl.text,
      );
      if (!mounted) return;
      TextInput.finishAutofillContext();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeShell()),
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
                onPressed: () => _loginSocial('Google'),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 26),
      decoration: BoxDecoration(
        color: XepaCores.tomate,
        borderRadius: BorderRadius.circular(24),
      ),
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
    );
  }
}

/// Folha de "Esqueci minha senha".
class _RecuperarSenhaSheet extends StatefulWidget {
  const _RecuperarSenhaSheet({required this.emailInicial});

  final String emailInicial;

  @override
  State<_RecuperarSenhaSheet> createState() => _RecuperarSenhaSheetState();
}

class _RecuperarSenhaSheetState extends State<_RecuperarSenhaSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailCtrl;

  bool _carregando = false;
  bool _enviado = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.emailInicial);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      await AuthService.instance
          .recuperarSenha(email: _emailCtrl.text.trim().toLowerCase());
      if (!mounted) return;
      setState(() {
        _enviado = true;
        _carregando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _erro = 'Não foi possível enviar o link agora. Tente novamente.';
        _carregando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final teclado = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + teclado),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.topCenter,
        child: _enviado ? _buildConfirmacao() : _buildFormulario(),
      ),
    );
  }

  Widget _buildFormulario() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recuperar senha',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Digite o e-mail da sua conta e enviaremos um link para criar uma nova senha.',
            style: TextStyle(color: XepaCores.textoSecundario, height: 1.35),
          ),
          const SizedBox(height: 18),
          if (_erro != null) ...[
            AuthErroBanner(mensagem: _erro!),
            const SizedBox(height: 14),
          ],
          AuthCampoTexto(
            controller: _emailCtrl,
            rotulo: 'E-mail',
            icone: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            validator: AuthValidadores.email,
            enabled: !_carregando,
            onFieldSubmitted: (_) => _enviar(),
          ),
          const SizedBox(height: 18),
          AuthBotaoPrimario(
            rotulo: 'Enviar link',
            carregando: _carregando,
            onPressed: _enviar,
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmacao() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            color: XepaCores.verdeClaro,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.mark_email_read_outlined,
            size: 30,
            color: XepaCores.verde,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Confira seu e-mail',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          'Se existir uma conta para ${_emailCtrl.text.trim()}, você receberá o link em instantes. Veja também a caixa de spam.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: XepaCores.textoSecundario, height: 1.4),
        ),
        const SizedBox(height: 22),
        AuthBotaoPrimario(
          rotulo: 'Voltar para o login',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}