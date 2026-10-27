import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/auth.dart';
import '../theme.dart';
import 'xepa_logo.dart';

/// Estrutura comum das telas de autenticação: rolagem, largura máxima
/// (tablet/web) e fechamento do teclado ao arrastar.
class AuthPagina extends StatelessWidget {
  const AuthPagina({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Navigator.of(context).canPop()
          ? AppBar(
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              scrolledUnderElevation: 0,
              elevation: 0,
            )
          : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Marca do Xepa: o tomatinho com o nome. Sobre o vermelho, o tomate ganha um selo branco.
class AuthMarca extends StatelessWidget {
  const AuthMarca({super.key, this.sobreFundoVermelho = false});

  final bool sobreFundoVermelho;

  @override
  Widget build(BuildContext context) {
    if (!sobreFundoVermelho) return const XepaMarca(tamanho: 30);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 48,
          height: 48,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: const XepaLogo(tamanho: 36),
        ),
        const SizedBox(width: 12),
        const NomeXepa(altura: 40, cor: Colors.white),
      ],
    );
  }
}

/// Campo de texto padrão do Xepa (fundo branco, borda bege, foco em tomate).
class AuthCampoTexto extends StatelessWidget {
  const AuthCampoTexto({
    super.key,
    required this.controller,
    required this.rotulo,
    required this.icone,
    this.dica,
    this.ajuda,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
    this.inputFormatters,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.autovalidateMode = AutovalidateMode.disabled,
    this.obscureText = false,
    this.sufixo,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String rotulo;
  final IconData icone;
  final String? dica;
  final String? ajuda;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final TextCapitalization textCapitalization;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final AutovalidateMode autovalidateMode;
  final bool obscureText;
  final Widget? sufixo;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder borda(Color cor, [double largura = 1]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: cor, width: largura),
      );
    }

    return TextFormField(
      controller: controller,
      enabled: enabled,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      autofillHints: autofillHints,
      inputFormatters: inputFormatters,
      validator: validator,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      autovalidateMode: autovalidateMode,
      cursorColor: XepaCores.tomate,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      decoration: InputDecoration(
        labelText: rotulo,
        hintText: dica,
        helperText: ajuda,
        helperMaxLines: 2,
        helperStyle: const TextStyle(color: XepaCores.textoSecundario),
        labelStyle: const TextStyle(color: XepaCores.textoSecundario),
        floatingLabelStyle: const TextStyle(
          color: XepaCores.tomateEscuro,
          fontWeight: FontWeight.w700,
        ),
        hintStyle: TextStyle(
          color: XepaCores.textoSecundario.withAlpha(150),
          fontWeight: FontWeight.w500,
        ),
        errorStyle: const TextStyle(
          color: XepaCores.tomateEscuro,
          fontWeight: FontWeight.w600,
          height: 1.2,
        ),
        errorMaxLines: 2,
        prefixIcon: Icon(icone, size: 20, color: XepaCores.textoSecundario),
        suffixIcon: sufixo,
        filled: true,
        fillColor: enabled ? Colors.white : XepaCores.bege.withAlpha(120),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: borda(XepaCores.borda),
        enabledBorder: borda(XepaCores.borda),
        disabledBorder: borda(XepaCores.borda),
        focusedBorder: borda(XepaCores.tomate, 1.8),
        errorBorder: borda(XepaCores.tomateEscuro),
        focusedErrorBorder: borda(XepaCores.tomateEscuro, 1.8),
      ),
    );
  }
}

/// Botão de mostrar/ocultar senha.
class AuthBotaoVisibilidade extends StatelessWidget {
  const AuthBotaoVisibilidade({
    super.key,
    required this.oculta,
    required this.onPressed,
  });

  final bool oculta;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: oculta ? 'Mostrar senha' : 'Ocultar senha',
      onPressed: onPressed,
      icon: Icon(
        oculta ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        size: 20,
        color: XepaCores.textoSecundario,
      ),
    );
  }
}

/// Botão principal (tomate, 54 px) com estado de carregamento.
class AuthBotaoPrimario extends StatelessWidget {
  const AuthBotaoPrimario({
    super.key,
    required this.rotulo,
    required this.onPressed,
    this.carregando = false,
  });

  final String rotulo;
  final VoidCallback onPressed;
  final bool carregando;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton(
        onPressed: carregando ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: XepaCores.tomate,
          foregroundColor: Colors.white,
          disabledBackgroundColor: XepaCores.tomate,
          disabledForegroundColor: Colors.white,
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        child: carregando
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.6,
                  color: Colors.white,
                ),
              )
            : Text(rotulo),
      ),
    );
  }
}

/// Botão de login social (Google).
class AuthBotaoSocial extends StatelessWidget {
  const AuthBotaoSocial({
    super.key,
    required this.rotulo,
    required this.icone,
    required this.onPressed,
  });

  final String rotulo;
  final Widget icone;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: XepaCores.texto,
          side: const BorderSide(color: XepaCores.borda),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icone,
            const SizedBox(width: 10),
            Text(rotulo),
          ],
        ),
      ),
    );
  }
}

/// Ícone "G" simples para o botão do Google.
/// Troque pelo logotipo oficial (asset) antes de publicar.
class AuthIconeGoogle extends StatelessWidget {
  const AuthIconeGoogle({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: XepaCores.borda, width: 1.5),
      ),
      child: const Text(
        'G',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w900,
          color: Color(0xFF4285F4),
          height: 1,
        ),
      ),
    );
  }
}

/// Divisor com texto central ("ou continue com").
class AuthDivisor extends StatelessWidget {
  const AuthDivisor({super.key, required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: XepaCores.borda, thickness: 1.2)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            texto,
            style: const TextStyle(
              color: XepaCores.textoSecundario,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Expanded(child: Divider(color: XepaCores.borda, thickness: 1.2)),
      ],
    );
  }
}

/// Faixa de erro exibida acima do formulário (ex.: credenciais inválidas).
class AuthErroBanner extends StatelessWidget {
  const AuthErroBanner({super.key, required this.mensagem});

  final String mensagem;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: XepaCores.tomateClaro,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: XepaCores.tomateEscuro.withAlpha(90)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 20,
              color: XepaCores.tomateEscuro,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                mensagem,
                style: const TextStyle(
                  color: XepaCores.tomateEscuro,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Medidor de força da senha (4 níveis) com dica de requisitos.
class MedidorSenha extends StatelessWidget {
  const MedidorSenha({super.key, required this.senha});

  final String senha;

  static const _rotulos = ['', 'Fraca', 'Razoável', 'Boa', 'Forte'];
  static const _cores = [
    XepaCores.borda,
    XepaCores.tomate,
    XepaCores.paoEscuro,
    XepaCores.verdeFolha,
    XepaCores.verde,
  ];

  int get _nivel {
    if (senha.isEmpty) return 0;
    var n = 0;
    if (senha.length >= 8) n++;
    if (RegExp(r'[A-Za-z]').hasMatch(senha) && RegExp(r'\d').hasMatch(senha)) {
      n++;
    }
    if (RegExp(r'[a-z]').hasMatch(senha) && RegExp(r'[A-Z]').hasMatch(senha)) {
      n++;
    }
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(senha) || senha.length >= 12) n++;
    return n == 0 ? 1 : n;
  }

  @override
  Widget build(BuildContext context) {
    final nivel = _nivel;
    final cor = _cores[nivel];
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(4, (i) {
              return Expanded(
                child: Container(
                  height: 5,
                  margin: EdgeInsets.only(right: i == 3 ? 0 : 6),
                  decoration: BoxDecoration(
                    color: i < nivel ? cor : XepaCores.borda,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Use 8 ou mais caracteres, com letras e números.',
                  style: TextStyle(
                    color: XepaCores.textoSecundario,
                    fontSize: 12.5,
                  ),
                ),
              ),
              if (nivel > 0)
                Text(
                  _rotulos[nivel],
                  style: TextStyle(
                    color: cor,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Seletor "Cliente / Restaurante / Entregador" do cadastro.
class SeletorTipoConta extends StatelessWidget {
  const SeletorTipoConta({
    super.key,
    required this.valor,
    required this.onChanged,
  });

  final TipoConta valor;
  final ValueChanged<TipoConta> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget opcao(TipoConta tipo, IconData icone, String titulo, String descricao) => Expanded(
          child: _OpcaoConta(
            icone: icone,
            titulo: titulo,
            descricao: descricao,
            selecionado: valor == tipo,
            onTap: () => onChanged(tipo),
          ),
        );

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          opcao(TipoConta.cliente, Icons.shopping_bag_outlined, 'Cliente', 'Resgatar sacolas'),
          const SizedBox(width: 8),
          opcao(TipoConta.entregador, Icons.two_wheeler_rounded, 'Entregador', 'Ganhar por corrida'),
          const SizedBox(width: 8),
          opcao(TipoConta.restaurante, Icons.storefront_outlined, 'Loja', 'Vender excedentes'),
        ],
      ),
    );
  }
}

class _OpcaoConta extends StatelessWidget {
  const _OpcaoConta({
    required this.icone,
    required this.titulo,
    required this.descricao,
    required this.selecionado,
    required this.onTap,
  });

  final IconData icone;
  final String titulo;
  final String descricao;
  final bool selecionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selecionado,
      label: '$titulo. $descricao',
      excludeSemantics: true,
      child: Material(
        color: selecionado ? XepaCores.tomateClaro : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selecionado ? XepaCores.tomate : XepaCores.borda,
            width: selecionado ? 1.8 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  icone,
                  size: 26,
                  color: selecionado
                      ? XepaCores.tomateEscuro
                      : XepaCores.textoSecundario,
                ),
                const SizedBox(height: 10),
                Text(
                  titulo,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.fade,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: selecionado
                        ? XepaCores.tomateEscuro
                        : XepaCores.texto,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  descricao,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: XepaCores.textoSecundario,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MascaraDigitos extends TextInputFormatter {
  const MascaraDigitos(this.mascara);

  final String mascara;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue anterior,
    TextEditingValue novo,
  ) {
    final digitos = novo.text.replaceAll(RegExp(r'\D'), '');
    final saida = StringBuffer();
    var i = 0;
    for (final c in mascara.split('')) {
      if (i >= digitos.length) break;
      if (c == '#') {
        saida.write(digitos[i]);
        i++;
      } else {
        saida.write(c);
      }
    }
    final texto = saida.toString();
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}