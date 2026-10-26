import 'package:flutter/material.dart' as material;
import 'package:google_fonts/google_fonts.dart';

/// Paleta do Xepa: vermelho-tomate da marca usado com moderação, fundo creme quase branco
/// e verde da folha para o que é bom (desconto, impacto, confirmação).
class XepaCores {
  static const fundo = material.Color(0xFFFFFAF6);
  static const bege = material.Color(0xFFF7EDE4);
  static const tomate = material.Color(0xFFD7261E);
  static const tomateEscuro = material.Color(0xFFB71F18);
  static const tomateClaro = material.Color(0xFFFCE7E4);
  static const verde = material.Color(0xFF1F7A4D);
  static const verdeFolha = material.Color(0xFF2E8B57);
  static const verdeClaro = material.Color(0xFFE5F3EA);
  static const verdeTexto = material.Color(0xFF1F5C3A);
  static const pao = material.Color(0xFFFDEBD6);
  static const paoEscuro = material.Color(0xFFB86A12);
  static const madeira = material.Color(0xFF8A5A2B);
  static const texto = material.Color(0xFF241A16);
  static const textoSecundario = material.Color(0xFF7B6E66);
  static const borda = material.Color(0xFFF0E6DF);
  static const cartao = material.Colors.white;
}

/// Raios usados no app inteiro.
class XepaRaios {
  static const cartao = 18.0;
  static const campo = 14.0;
  static const pilula = 99.0;
}

/// Sombra suave dos cartões.
const sombraCartao = [
  material.BoxShadow(color: material.Color(0x0F3C1E14), blurRadius: 16, offset: material.Offset(0, 4)),
];

material.ThemeData xepaTema() {
  final base = material.ThemeData(
    useMaterial3: true,
    colorScheme: material.ColorScheme.fromSeed(
      seedColor: XepaCores.tomate,
      primary: XepaCores.tomate,
      onPrimary: material.Colors.white,
      secondary: XepaCores.verde,
      surface: XepaCores.fundo,
      onSurface: XepaCores.texto,
    ),
    scaffoldBackgroundColor: XepaCores.fundo,
  );

  final texto = base.textTheme.apply(
    fontFamily: GoogleFonts.manrope().fontFamily,
    bodyColor: XepaCores.texto,
    displayColor: XepaCores.texto,
  );

  const pilula = material.StadiumBorder();

  return base.copyWith(
    textTheme: texto,
    appBarTheme: material.AppBarTheme(
      backgroundColor: XepaCores.fundo,
      foregroundColor: XepaCores.texto,
      surfaceTintColor: material.Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.manrope(
        fontSize: 19,
        fontWeight: material.FontWeight.w800,
        color: XepaCores.texto,
      ),
    ),
    filledButtonTheme: material.FilledButtonThemeData(
      style: material.FilledButton.styleFrom(
        backgroundColor: XepaCores.tomate,
        foregroundColor: material.Colors.white,
        minimumSize: const material.Size(0, 52),
        shape: pilula,
        textStyle: GoogleFonts.manrope(fontSize: 15, fontWeight: material.FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: material.OutlinedButtonThemeData(
      style: material.OutlinedButton.styleFrom(
        foregroundColor: XepaCores.texto,
        backgroundColor: material.Colors.white,
        minimumSize: const material.Size(0, 50),
        side: const material.BorderSide(color: XepaCores.borda),
        shape: pilula,
        textStyle: GoogleFonts.manrope(fontSize: 15, fontWeight: material.FontWeight.w700),
      ),
    ),
    textButtonTheme: material.TextButtonThemeData(
      style: material.TextButton.styleFrom(
        foregroundColor: XepaCores.tomateEscuro,
        textStyle: GoogleFonts.manrope(fontWeight: material.FontWeight.w800),
      ),
    ),
    inputDecorationTheme: material.InputDecorationTheme(
      filled: true,
      fillColor: material.Colors.white,
      border: material.OutlineInputBorder(
        borderRadius: material.BorderRadius.circular(XepaRaios.campo),
        borderSide: const material.BorderSide(color: XepaCores.borda),
      ),
      enabledBorder: material.OutlineInputBorder(
        borderRadius: material.BorderRadius.circular(XepaRaios.campo),
        borderSide: const material.BorderSide(color: XepaCores.borda),
      ),
      focusedBorder: material.OutlineInputBorder(
        borderRadius: material.BorderRadius.circular(XepaRaios.campo),
        borderSide: const material.BorderSide(color: XepaCores.tomate, width: 1.6),
      ),
    ),
    chipTheme: material.ChipThemeData(
      backgroundColor: material.Colors.white,
      selectedColor: XepaCores.tomate,
      side: const material.BorderSide(color: XepaCores.borda),
      shape: pilula,
      labelStyle: GoogleFonts.manrope(fontSize: 13, fontWeight: material.FontWeight.w700, color: XepaCores.texto),
      secondaryLabelStyle: GoogleFonts.manrope(fontSize: 13, fontWeight: material.FontWeight.w700, color: material.Colors.white),
      showCheckmark: false,
      padding: const material.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    ),
    progressIndicatorTheme: const material.ProgressIndicatorThemeData(color: XepaCores.tomate),
    dividerTheme: const material.DividerThemeData(color: XepaCores.borda, thickness: 1),
    navigationBarTheme: material.NavigationBarThemeData(
      backgroundColor: material.Colors.white,
      surfaceTintColor: material.Colors.transparent,
      indicatorColor: XepaCores.tomateClaro,
      height: 66,
      labelTextStyle: material.WidgetStateProperty.resolveWith(
        (states) => GoogleFonts.manrope(
          fontSize: 11,
          fontWeight: states.contains(material.WidgetState.selected)
              ? material.FontWeight.w800
              : material.FontWeight.w600,
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
    snackBarTheme: material.SnackBarThemeData(
      behavior: material.SnackBarBehavior.floating,
      backgroundColor: XepaCores.texto,
      shape: material.RoundedRectangleBorder(borderRadius: material.BorderRadius.circular(14)),
      contentTextStyle: GoogleFonts.manrope(color: material.Colors.white, fontWeight: material.FontWeight.w600),
    ),
    bottomSheetTheme: const material.BottomSheetThemeData(
      backgroundColor: XepaCores.fundo,
      surfaceTintColor: material.Colors.transparent,
    ),
  );
}

String formatarPreco(double valor) =>
    'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';

String formatarDistancia(double km) =>
    '${km.toStringAsFixed(1).replaceAll('.', ',')} km';

String formatarDecimal(double valor) =>
    valor.toStringAsFixed(1).replaceAll('.', ',');
