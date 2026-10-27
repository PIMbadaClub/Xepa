import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter, LengthLimitingTextInputFormatter, TextInput;

import 'package:url_launcher/url_launcher.dart';

import '../api/api.dart';
import '../models/auth.dart';
import '../theme.dart';
import '../widgets/auth_validadores.dart';
import '../widgets/auth_widgets.dart';
import 'abertura_screen.dart';

class CadastroScreen extends StatefulWidget {
  const CadastroScreen({super.key});

  @override
  State<CadastroScreen> createState() => _CadastroScreenState();
}

class _CadastroScreenState extends State<CadastroScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _celularCtrl = TextEditingController();
  final _cnpjCtrl = TextEditingController();
  final _placaCtrl = TextEditingController();
  final _senhaCtrl = TextEditingController();
  final _confirmarCtrl = TextEditingController();

  TipoConta _tipo = TipoConta.cliente;
  bool _ocultarSenha = true;
  bool _carregando = false;
  String? _erro;
  AutovalidateMode _autovalidar = AutovalidateMode.disabled;

  bool get _ehRestaurante => _tipo == TipoConta.restaurante;
  bool get _ehEntregador => _tipo == TipoConta.entregador;

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _emailCtrl.dispose();
    _celularCtrl.dispose();
    _cnpjCtrl.dispose();
    _placaCtrl.dispose();
    _senhaCtrl.dispose();
    _confirmarCtrl.dispose();
    super.dispose();
  }

  String _digitos(String v) => v.replaceAll(RegExp(r'\D'), '');

  Future<void> _cadastrar() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      setState(() => _autovalidar = AutovalidateMode.onUserInteraction);
      return;
    }

    setState(() {
      _carregando = true;
      _erro = null;
    });

    final dados = CadastroDados(
      tipo: _tipo,
      nome: _nomeCtrl.text.trim(),
      email: _emailCtrl.text.trim().toLowerCase(),
      celular: _digitos(_celularCtrl.text),
      cnpj: _ehRestaurante ? _digitos(_cnpjCtrl.text) : null,
      placa: _ehEntregador ? _placaCtrl.text.replaceAll('-', '').toUpperCase() : null,
      senha: _senhaCtrl.text,
      // O formulário só chega aqui com a caixa dos termos marcada.
      aceitouTermos: true,
    );

    try {
      final usuario = await AuthService.instance.cadastrar(dados);
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
            'Não foi possível criar sua conta agora. Verifique sua conexão e tente novamente.';
        _carregando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthPagina(
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Crie sua conta',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Text(
                  switch (_tipo) {
                    TipoConta.restaurante => 'Transforme o que sobra em renda e evite o desperdício.',
                    TipoConta.entregador => 'Faça entregas na sua cidade e ganhe a taxa de cada corrida.',
                    TipoConta.cliente => 'Resgate comida boa e pague menos por isso.',
                  },
                  key: ValueKey(_tipo),
                  style: const TextStyle(
                    color: XepaCores.textoSecundario,
                    fontSize: 15,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              SeletorTipoConta(
                valor: _tipo,
                onChanged: (t) {
                  if (_carregando) return;
                  setState(() => _tipo = t);
                },
              ),
              const SizedBox(height: 22),
              if (_ehRestaurante)
                const _CadastroNoPortal()
              else ...[
              if (_erro != null) ...[
                AuthErroBanner(mensagem: _erro!),
                const SizedBox(height: 16),
              ],
              AuthCampoTexto(
                controller: _nomeCtrl,
                rotulo: _ehRestaurante
                    ? 'Nome do estabelecimento'
                    : 'Nome completo',
                icone: _ehRestaurante
                    ? Icons.storefront_outlined
                    : Icons.person_outline_rounded,
                textCapitalization: TextCapitalization.words,
                autofillHints: [
                  _ehRestaurante
                      ? AutofillHints.organizationName
                      : AutofillHints.name,
                ],
                validator: (v) =>
                    AuthValidadores.nome(v, restaurante: _ehRestaurante),
                autovalidateMode: _autovalidar,
                enabled: !_carregando,
              ),
              if (_ehEntregador) ...[
                const SizedBox(height: 14),
                AuthCampoTexto(
                  controller: _placaCtrl,
                  rotulo: 'Placa da moto',
                  icone: Icons.two_wheeler_rounded,
                  dica: 'ABC1D23',
                  ajuda: 'A loja e o cliente veem a placa para conferir quem chegou.',
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9-]')),
                    LengthLimitingTextInputFormatter(8),
                  ],
                  validator: (v) => RegExp(r'^[A-Za-z]{3}-?\d[A-Za-z\d]\d{2}$').hasMatch(v?.trim() ?? '')
                      ? null
                      : 'Informe a placa (ex.: ABC1D23 ou ABC-1234).',
                  autovalidateMode: _autovalidar,
                  enabled: !_carregando,
                ),
              ],
              if (_ehRestaurante) ...[
                const SizedBox(height: 14),
                AuthCampoTexto(
                  controller: _cnpjCtrl,
                  rotulo: 'CNPJ',
                  icone: Icons.badge_outlined,
                  dica: '00.000.000/0000-00',
                  ajuda: 'Usamos o CNPJ para confirmar o seu estabelecimento.',
                  keyboardType: TextInputType.number,
                  inputFormatters: const [MascaraDigitos('##.###.###/####-##')],
                  validator: AuthValidadores.cnpj,
                  autovalidateMode: _autovalidar,
                  enabled: !_carregando,
                ),
              ],
              const SizedBox(height: 14),
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
                controller: _celularCtrl,
                rotulo: 'Celular',
                icone: Icons.phone_iphone_rounded,
                dica: '(11) 91234-5678',
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumberNational],
                inputFormatters: const [MascaraDigitos('(##) #####-####')],
                validator: AuthValidadores.celular,
                autovalidateMode: _autovalidar,
                enabled: !_carregando,
              ),
              const SizedBox(height: 14),
              AuthCampoTexto(
                controller: _senhaCtrl,
                rotulo: 'Senha',
                icone: Icons.lock_outline_rounded,
                obscureText: _ocultarSenha,
                autofillHints: const [AutofillHints.newPassword],
                validator: AuthValidadores.senhaCadastro,
                autovalidateMode: _autovalidar,
                enabled: !_carregando,
                onChanged: (_) => setState(() {}),
                sufixo: AuthBotaoVisibilidade(
                  oculta: _ocultarSenha,
                  onPressed: () =>
                      setState(() => _ocultarSenha = !_ocultarSenha),
                ),
              ),
              MedidorSenha(senha: _senhaCtrl.text),
              const SizedBox(height: 14),
              AuthCampoTexto(
                controller: _confirmarCtrl,
                rotulo: 'Confirmar senha',
                icone: Icons.lock_reset_rounded,
                obscureText: _ocultarSenha,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                validator: (v) =>
                    AuthValidadores.confirmarSenha(v, _senhaCtrl.text),
                autovalidateMode: _autovalidar,
                enabled: !_carregando,
                onFieldSubmitted: (_) => _cadastrar(),
              ),
              const SizedBox(height: 16),
              _CampoTermos(
                autovalidateMode: _autovalidar,
                habilitado: !_carregando,
              ),
              const SizedBox(height: 20),
              AuthBotaoPrimario(
                rotulo: _ehEntregador ? 'Quero ser entregador' : 'Criar conta',
                carregando: _carregando,
                onPressed: _cadastrar,
              ),
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Já tem conta?',
                    style: TextStyle(color: XepaCores.textoSecundario),
                  ),
                  TextButton(
                    onPressed:
                        _carregando ? null : () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: XepaCores.tomateEscuro,
                      textStyle: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    child: const Text('Entrar'),
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

/// Aceite dos Termos de Uso e da Política de Privacidade (LGPD); os trechos em destaque abrem as páginas no portal.
class _CampoTermos extends StatelessWidget {
  const _CampoTermos({
    required this.autovalidateMode,
    required this.habilitado,
  });

  final AutovalidateMode autovalidateMode;
  final bool habilitado;

  @override
  Widget build(BuildContext context) {
    const destaque = TextStyle(
      color: XepaCores.tomateEscuro,
      fontWeight: FontWeight.w800,
    );

    return FormField<bool>(
      initialValue: false,
      autovalidateMode: autovalidateMode,
      validator: (v) =>
          v == true ? null : 'Aceite os termos para criar sua conta',
      builder: (campo) {
        final marcado = campo.value ?? false;
        final erro = campo.hasError;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: habilitado ? () => campo.didChange(!marcado) : null,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: marcado,
                    onChanged:
                        habilitado ? (v) => campo.didChange(v ?? false) : null,
                    activeColor: XepaCores.tomate,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                    side: WidgetStateBorderSide.resolveWith((estados) {
                      if (estados.contains(WidgetState.selected)) {
                        return const BorderSide(color: XepaCores.tomate);
                      }
                      return BorderSide(
                        color: erro
                            ? XepaCores.tomateEscuro
                            : XepaCores.textoSecundario,
                        width: 1.6,
                      );
                    }),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12, right: 4),
                      child: Text.rich(
                        TextSpan(
                          text: 'Li e concordo com os ',
                          children: [
                            TextSpan(
                              text: 'Termos de Uso',
                              style: destaque,
                              recognizer: TapGestureRecognizer()..onTap = () => abrirPaginaLegal('termos'),
                            ),
                            const TextSpan(text: ' e a '),
                            TextSpan(
                              text: 'Política de Privacidade',
                              style: destaque,
                              recognizer: TapGestureRecognizer()..onTap = () => abrirPaginaLegal('privacidade'),
                            ),
                            const TextSpan(text: '.'),
                          ],
                        ),
                        style: const TextStyle(fontSize: 13.5, height: 1.35),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (erro)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 2, 0, 0),
                child: Text(
                  campo.errorText!,
                  style: const TextStyle(
                    color: XepaCores.tomateEscuro,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Lojas se cadastram pelo portal, onde o CNPJ e o endereço são conferidos antes da aprovação (RN10).
class _CadastroNoPortal extends StatelessWidget {
  const _CadastroNoPortal();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(XepaRaios.cartao),
        border: Border.all(color: XepaCores.borda),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.storefront_rounded, color: XepaCores.tomate, size: 32),
          const SizedBox(height: 10),
          const Text('Cadastro de lojas pelo portal', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text(
            'No portal você informa CNPJ e endereço de retirada, e a equipe da XEPA aprova a loja. '
            'Depois é por lá que você publica as ofertas e acompanha os pedidos.',
            style: TextStyle(color: XepaCores.textoSecundario, height: 1.4),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => launchUrl(Uri.parse('$portalUrl/conta/cadastrar'), mode: LaunchMode.externalApplication),
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('Abrir o cadastro de lojas'),
          ),
        ],
      ),
    );
  }
}

/// Abre os termos de uso ou a política de privacidade no navegador.
void abrirPaginaLegal(String pagina) => launchUrl(paginaLegal(pagina), mode: LaunchMode.externalApplication);
