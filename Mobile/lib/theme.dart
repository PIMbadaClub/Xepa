import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paleta do Xepa, baseada no ícone 16 (fundo bege, tomate vermelho e folha verde).
class XepaCores {
  static const fundo = Color(0xFFFBF4E8);
  static const bege = Color(0xFFF5E6CC);
  static const tomate = Color(0xFFE30613);
  static const tomateEscuro = Color(0xFFB3261E);
  static const tomateClaro = Color(0xFFFCE4E2);
  static const verde = Color(0xFF1F7A4D);
  static const verdeFolha = Color(0xFF2E8B57);
  static const verdeClaro = Color(0xFFE3F1E6);
  static const verdeTexto = Color(0xFF1F5C3A);
  static const pao = Color(0xFFFDE8CF);
  static const paoEscuro = Color(0xFFB86A12);
  static const madeira = Color(0xFF8A5A2B);
  static const texto = Color(0xFF2B1D14);
  static const textoSecundario = Color(0xFF7A6A5C);
  static const borda = Color(0xFFE8DCC8);
}

ThemeData xepaTema() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: XepaCores.tomate,
      primary: XepaCores.tomate,
      onPrimary: Colors.white,
      surface: XepaCores.fundo,
    ),
    scaffoldBackgroundColor: XepaCores.fundo,
  );

  return base.copyWith(
    textTheme: GoogleFonts.nunitoTextTheme(base.textTheme).apply(
      bodyColor: XepaCores.texto,
      displayColor: XepaCores.texto,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: XepaCores.tomateClaro,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 11,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? XepaCores.tomateEscuro
              : XepaCores.textoSecundario,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? XepaCores.tomateEscuro
              : XepaCores.textoSecundario,
        ),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// Fonte da marca (usada no nome "xepa").
TextStyle fonteMarca({double tamanho = 22, Color cor = XepaCores.tomateEscuro}) {
  return GoogleFonts.fredoka(
    fontSize: tamanho,
    fontWeight: FontWeight.w600,
    color: cor,
  );
}

String formatarPreco(double valor) =>
    'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';

String formatarDistancia(double km) =>
    '${km.toStringAsFixed(1).replaceAll('.', ',')} km';

String formatarDecimal(double valor) =>
    valor.toStringAsFixed(1).replaceAll('.', ',');
