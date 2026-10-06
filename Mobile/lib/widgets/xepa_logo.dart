import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme.dart';

/// Ícone do app (versão 16): fundo bege, tomate vermelho com folhinha e x branco.
class XepaLogo extends StatelessWidget {
  const XepaLogo({super.key, this.tamanho = 32});

  final double tamanho;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: tamanho,
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _TomatePainter())),
          Align(
            alignment: const Alignment(0, 0.1),
            child: Text(
              'x',
              style: GoogleFonts.fredoka(
                fontSize: tamanho * 0.44,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TomatePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Desenha num espaço de 100 x 100 e escala para o tamanho real.
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);

    final fundo = RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 0, 100, 100),
      const Radius.circular(22),
    );
    canvas.drawRRect(fundo, Paint()..color = XepaCores.bege);

    canvas.drawCircle(const Offset(50, 57), 33, Paint()..color = XepaCores.tomate);

    canvas.drawOval(
      Rect.fromCenter(center: const Offset(37, 44), width: 16, height: 9.2),
      Paint()..color = const Color(0x80FFFFFF),
    );

    // Folhinha (cálice) do tomate.
    final folha = Paint()..color = XepaCores.verdeFolha;
    canvas.save();
    canvas.translate(50, 25);
    canvas.scale(2);
    canvas.drawLine(
      Offset.zero,
      const Offset(0, -5),
      Paint()
        ..color = XepaCores.verdeFolha
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
    for (final lado in [-1.0, 1.0]) {
      canvas.save();
      canvas.translate(5 * lado, 1);
      canvas.rotate(lado * 20 * math.pi / 180);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 12, height: 5),
        folha,
      );
      canvas.restore();
    }
    canvas.restore();

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
