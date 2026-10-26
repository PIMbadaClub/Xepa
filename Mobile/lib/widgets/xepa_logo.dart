import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme.dart';

/// Tomatinho da Xepa: tomate com cálice de folhas e o "x" branco.
/// Com [comFundo], fica dentro do quadrado bege do ícone do app.
class XepaLogo extends StatelessWidget {
  const XepaLogo({super.key, this.tamanho = 32, this.comFundo = false, this.comX = true});

  final double tamanho;
  final bool comFundo;
  final bool comX;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: tamanho,
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: TomatePainter(comFundo: comFundo))),
          if (comX)
            Align(
              alignment: Alignment(0, comFundo ? 0.22 : 0.3),
              child: Text(
                'x',
                style: GoogleFonts.fredoka(
                  fontSize: tamanho * (comFundo ? 0.4 : 0.5),
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  height: 1,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Logo completo: tomatinho + "xepa". Tem um segredo para quem toca nele várias vezes.
class XepaMarca extends StatefulWidget {
  const XepaMarca({super.key, this.tamanho = 30, this.cor = XepaCores.tomate});

  final double tamanho;
  final Color cor;

  @override
  State<XepaMarca> createState() => _XepaMarcaState();
}

class _XepaMarcaState extends State<XepaMarca> with SingleTickerProviderStateMixin {
  late final _balanco = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
  var _toques = 0;

  static const _segredos = [
    'Psiu! Você achou o tomate da xepa 🍅',
    'Tomate amassado também dá molho. Nada se perde!',
    'Quase 1/3 da comida do mundo se perde ou vai pro lixo (FAO). Cada sacola ajuda a mudar isso.',
  ];

  @override
  void dispose() {
    _balanco.dispose();
    super.dispose();
  }

  void _tocar() {
    _balanco.forward(from: 0);
    _toques++;
    if (_toques % 5 == 0) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(_segredos[(_toques ~/ 5 - 1) % _segredos.length])));
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _tocar,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _balanco,
            builder: (_, filho) => Transform.rotate(
              angle: math.sin(_balanco.value * math.pi * 4) * (1 - _balanco.value) * 0.35,
              child: filho,
            ),
            child: XepaLogo(tamanho: widget.tamanho * 1.15),
          ),
          SizedBox(width: widget.tamanho * 0.18),
          Text('xepa', style: fonteMarca(tamanho: widget.tamanho, cor: widget.cor)),
        ],
      ),
    );
  }
}

/// Tomate apagado e girado, usado como marca-d'água nos cantos dos banners e telas vazias.
class TomateMarcaDagua extends StatelessWidget {
  const TomateMarcaDagua({super.key, this.tamanho = 120, this.opacidade = 0.12, this.angulo = -0.3, this.cor});

  final double tamanho;
  final double opacidade;
  final double angulo;

  /// Sem cor, usa as cores normais do tomate; com cor, desenha o tomate inteiro nela.
  final Color? cor;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Opacity(
        opacity: opacidade,
        child: Transform.rotate(
          angle: angulo,
          child: SizedBox.square(
            dimension: tamanho,
            child: CustomPaint(painter: TomatePainter(corUnica: cor)),
          ),
        ),
      ),
    );
  }
}

/// Carregamento: o tomatinho quicando, no lugar da rodinha padrão.
class TomateCarregando extends StatefulWidget {
  const TomateCarregando({super.key, this.tamanho = 36, this.texto});

  final double tamanho;
  final String? texto;

  @override
  State<TomateCarregando> createState() => _TomateCarregandoState();
}

class _TomateCarregandoState extends State<TomateCarregando> with SingleTickerProviderStateMixin {
  late final _pulo = AnimationController(vsync: this, duration: const Duration(milliseconds: 650))..repeat(reverse: true);

  @override
  void dispose() {
    _pulo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tamanho;
    return Semantics(
      label: widget.texto ?? 'Carregando',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulo,
            builder: (_, __) {
              final v = Curves.easeOut.transform(_pulo.value);
              return SizedBox(
                height: t * 1.6,
                width: t * 1.4,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    // Sombra que encolhe quando o tomate sobe.
                    Container(
                      width: t * (0.9 - v * 0.35),
                      height: t * 0.12,
                      decoration: BoxDecoration(
                        color: XepaCores.texto.withAlpha(25),
                        borderRadius: BorderRadius.circular(t),
                      ),
                    ),
                    Positioned(
                      bottom: t * 0.06 + v * t * 0.5,
                      child: Transform.scale(
                        scaleX: 1 + (1 - v) * 0.08,
                        scaleY: 1 - (1 - v) * 0.08,
                        child: XepaLogo(tamanho: t, comX: false),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          if (widget.texto != null) ...[
            const SizedBox(height: 8),
            Text(widget.texto!, style: const TextStyle(color: XepaCores.textoSecundario, fontSize: 13)),
          ],
        ],
      ),
    );
  }
}

/// Desenha o tomate num espaço de 100 x 100.
class TomatePainter extends CustomPainter {
  TomatePainter({this.comFundo = false, this.corUnica});

  final bool comFundo;
  final Color? corUnica;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);

    if (comFundo) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 100, 100), const Radius.circular(24)),
        Paint()..color = XepaCores.bege,
      );
      // Tomate um pouco menor dentro do quadrado.
      canvas.translate(12, 12);
      canvas.scale(0.76);
    }

    // Corpo: um pouco mais largo que alto, com dois gomos discretos em cima.
    final corpo = Path()
      ..moveTo(50, 26)
      ..cubicTo(62, 20, 80, 22, 90, 36)
      ..cubicTo(100, 52, 96, 76, 80, 88)
      ..cubicTo(66, 98, 34, 98, 20, 88)
      ..cubicTo(4, 76, 0, 52, 10, 36)
      ..cubicTo(20, 22, 38, 20, 50, 26)
      ..close();
    final paintCorpo = Paint();
    if (corUnica != null) {
      paintCorpo.color = corUnica!;
    } else {
      paintCorpo.shader = const RadialGradient(
        center: Alignment(-0.35, -0.4),
        radius: 0.95,
        colors: [Color(0xFFF0473C), XepaCores.tomate, Color(0xFFA81A14)],
        stops: [0, 0.6, 1],
      ).createShader(const Rect.fromLTWH(4, 20, 92, 78));
    }
    canvas.drawPath(corpo, paintCorpo);

    if (corUnica == null) {
      // Brilho.
      canvas.save();
      canvas.translate(30, 45);
      canvas.rotate(-0.6);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 18, height: 9),
        Paint()..color = Colors.white.withAlpha(110),
      );
      canvas.restore();
    }

    // Cálice: cinco folhas pontudas em estrela e o cabinho.
    final verde = Paint()..color = corUnica ?? XepaCores.verdeFolha;
    for (var i = 0; i < 5; i++) {
      final angulo = -math.pi / 2 + i * 2 * math.pi / 5 + math.pi / 5;
      canvas.save();
      canvas.translate(50, 25);
      canvas.rotate(angulo);
      canvas.scale(1, 0.62);
      final folha = Path()
        ..moveTo(0, -4)
        ..quadraticBezierTo(10, -3, 19, 0)
        ..quadraticBezierTo(10, 3, 0, 4)
        ..close();
      canvas.drawPath(folha, verde);
      canvas.restore();
    }
    canvas.drawCircle(const Offset(50, 25), 5, verde);
    canvas.drawLine(
      const Offset(50, 24),
      const Offset(53, 11),
      Paint()
        ..color = corUnica ?? XepaCores.verde
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant TomatePainter oldDelegate) =>
      oldDelegate.comFundo != comFundo || oldDelegate.corUnica != corUnica;
}
