import 'package:flutter/material.dart' as material;
import 'package:google_fonts/google_fonts.dart';

/// Paleta do Xepa, baseada no ícone 16
/// (fundo bege, tomate vermelho e folha verde).
class XepaCores {
  static const fundo = material.Color(0xFFFBF4E8);
  static const bege = material.Color(0xFFF5E6CC);
  static const tomate = material.Color(0xFFE30613);
  static const tomateEscuro = material.Color(0xFFB3261E);
  static const tomateClaro = material.Color(0xFFFCE4E2);
  static const verde = material.Color(0xFF1F7A4D);
  static const verdeFolha = material.Color(0xFF2E8B57);
  static const verdeClaro = material.Color(0xFFE3F1E6);
  static const verdeTexto = material.Color(0xFF1F5C3A);
  static const pao = material.Color(0xFFFDE8CF);
  static const paoEscuro = material.Color(0xFFB86A12);
  static const madeira = material.Color(0xFF8A5A2B);
  static const texto = material.Color(0xFF2B1D14);
  static const textoSecundario = material.Color(0xFF7A6A5C);
  static const borda = material.Color(0xFFE8DCC8);
}

material.ThemeData xepaTema() {
  final base = material.ThemeData(
    useMaterial3: true,
    colorScheme: material.ColorScheme.fromSeed(
      seedColor: XepaCores.tomate,
      primary: XepaCores.tomate,
      onPrimary: material.Colors.white,
      surface: XepaCores.fundo,
    ),
    scaffoldBackgroundColor: XepaCores.fundo,
  );


  return base.copyWith(
    textTheme: base.textTheme.apply(
      fontFamily: GoogleFonts.nunito().fontFamily,
      bodyColor: XepaCores.texto,
      displayColor: XepaCores.texto,
    ),
    navigationBarTheme: material.NavigationBarThemeData(
      backgroundColor: material.Colors.white,
      indicatorColor: XepaCores.tomateClaro,
      labelTextStyle: material.WidgetStateProperty.resolveWith(
        (states) => material.TextStyle(
          fontSize: 11,
          fontWeight: states.contains(material.WidgetState.selected)
              ? material.FontWeight.w700
              : material.FontWeight.w500,
          color: states.contains(material.WidgetState.selected)
              ? XepaCores.tomateEscuro
              : XepaCores.textoSecundario,
        ),
      ),
      iconTheme: material.WidgetStateProperty.resolveWith(
        (states) => material.IconThemeData(
          color: states.contains(material.WidgetState.selected)
              ? XepaCores.tomateEscuro
              : XepaCores.textoSecundario,
        ),
      ),
    ),
    snackBarTheme: const material.SnackBarThemeData(
      behavior: material.SnackBarBehavior.floating,
    ),
  );
}

/// Fonte da marca (usada no nome "xepa").
material.TextStyle fonteMarca({
  double tamanho = 22,
  material.Color cor = XepaCores.tomateEscuro,
}) {
  return GoogleFonts.fredoka(
    fontSize: tamanho,
    fontWeight: material.FontWeight.w600,
    color: cor,
  );
}

String formatarPreco(double valor) =>
    'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';

String formatarDistancia(double km) =>
    '${km.toStringAsFixed(1).replaceAll('.', ',')} km';

String formatarDecimal(double valor) =>
    valor.toStringAsFixed(1).replaceAll('.', ',');
