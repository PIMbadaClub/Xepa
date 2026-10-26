import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Tomate da Xepa: redondo, com duas folhas, cabinho e brilho.
/// Com [comFundo], fica dentro do quadrado creme do ícone do app.
class XepaLogo extends StatelessWidget {
  const XepaLogo({super.key, this.tamanho = 32, this.comFundo = false});

  final double tamanho;
  final bool comFundo;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: tamanho,
        child: CustomPaint(painter: TomatePainter(comFundo: comFundo)),
      );
}

/// Nome "Xepa" do logo, desenhado a partir do SVG oficial (docs/marca), sem depender de fonte.
class NomeXepa extends StatelessWidget {
  const NomeXepa({super.key, this.altura = 30, this.cor = XepaCores.verde});

  /// Altura da caixa, do topo do "X" ao pé do "p".
  final double altura;
  final Color cor;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Xepa',
        child: SizedBox(
          width: altura * _NomePainter.largura / _NomePainter.altura,
          height: altura,
          child: CustomPaint(painter: _NomePainter(cor)),
        ),
      );
}

/// Logo completo: tomate + "Xepa". Tem um segredo para quem toca nele várias vezes.
class XepaMarca extends StatefulWidget {
  const XepaMarca({super.key, this.tamanho = 30, this.cor = XepaCores.verde});

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
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          AnimatedBuilder(
            animation: _balanco,
            builder: (_, filho) => Transform.rotate(
              angle: math.sin(_balanco.value * math.pi * 4) * (1 - _balanco.value) * 0.35,
              child: filho,
            ),
            child: XepaLogo(tamanho: widget.tamanho * 1.4),
          ),
          // Mesma proporção do logo oficial: o nome tem ~0,9 da altura do tomate.
          SizedBox(width: widget.tamanho * 0.3),
          NomeXepa(altura: widget.tamanho * 1.25, cor: widget.cor),
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
                        child: XepaLogo(tamanho: t),
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

/// Desenha o tomate num espaço de 100 x 100, igual ao SVG oficial: corpo redondo, brilho,
/// cabinho e duas folhas.
class TomatePainter extends CustomPainter {
  TomatePainter({this.comFundo = false, this.corUnica});

  final bool comFundo;

  /// Com cor única (marca-d'água), o tomate inteiro sai nessa cor, sem brilho.
  final Color? corUnica;

  static const _vermelho = Color(0xFFE30613);
  static const _folha = Color(0xFF2E8B57);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);

    if (comFundo) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 100, 100), const Radius.circular(24)),
        Paint()..color = const Color(0xFFFFF3E0),
      );
      canvas.translate(16.8, 16.8);
      canvas.scale(0.664);
    }

    // Corpo.
    canvas.drawCircle(const Offset(50, 57), 40, Paint()..color = corUnica ?? _vermelho);

    if (corUnica == null) {
      // Brilho, no alto à esquerda.
      canvas.save();
      canvas.translate(33, 44);
      canvas.rotate(-30 * math.pi / 180);
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 20, height: 11), Paint()..color = const Color(0x73FFFFFF));
      canvas.restore();
    }

    final verde = corUnica ?? _folha;

    // Cabinho com a ponta arredondada.
    canvas.drawLine(
      const Offset(50, 18),
      const Offset(50, 6),
      Paint()
        ..color = verde
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round,
    );

    // Folhas: duas, abrindo para os lados a partir do cabinho.
    for (final lado in [-1.0, 1.0]) {
      canvas.save();
      canvas.translate(50 + lado * 12, 20.4);
      canvas.rotate(lado * 20 * math.pi / 180);
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 28.8, height: 12), Paint()..color = verde);
      canvas.restore();
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant TomatePainter oldDelegate) =>
      oldDelegate.comFundo != comFundo || oldDelegate.corUnica != corUnica;
}

/// Desenha o nome "Xepa" a partir do path do SVG oficial (unidades da fonte, y para cima).
class _NomePainter extends CustomPainter {
  _NomePainter(this.cor);

  final Color cor;

  // Caixa do desenho: x de 0 a 1960, y de -256 (pé do "p") a 756 (topo do "X").
  static const largura = 1960.0;
  static const altura = 1012.0;

  static final Path _nome = _lerPath(_nomeD);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / largura, size.height / altura);
    canvas.translate(0, 756);
    canvas.scale(1, -1);
    canvas.drawPath(_nome, Paint()..color = cor);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _NomePainter oldDelegate) => oldDelegate.cor != cor;

  /// Lê só o que o path do logo usa: M, L, H, V, Q e Z absolutos (pares extras depois de M viram L).
  static Path _lerPath(String d) {
    final path = Path();
    final tokens = RegExp(r'[MLHVQZ]|-?\d*\.?\d+').allMatches(d).map((m) => m.group(0)!).toList();
    var i = 0;
    var cmd = 'M';
    double x = 0, y = 0;
    double n() => double.parse(tokens[i++]);
    while (i < tokens.length) {
      if (RegExp(r'[MLHVQZ]').hasMatch(tokens[i])) {
        cmd = tokens[i++];
        if (cmd == 'Z') {
          path.close();
          continue;
        }
      }
      switch (cmd) {
        case 'M':
          x = n();
          y = n();
          path.moveTo(x, y);
          cmd = 'L';
        case 'L':
          x = n();
          y = n();
          path.lineTo(x, y);
        case 'H':
          x = n();
          path.lineTo(x, y);
        case 'V':
          y = n();
          path.lineTo(x, y);
        case 'Q':
          final cx = n(), cy = n();
          x = n();
          y = n();
          path.quadraticBezierTo(cx, cy, x, y);
      }
    }
    return path;
  }
}

const _nomeD = 'M322 332 248 683Q177 656 138.0 599.5Q99 543 99 461Q99 424 106.0 409.5Q113 395 113 393Q59 393 32.5 415.5Q6 438 6 490Q6 554 58.5 614.5Q111 675 193.0 712.5Q275 750 357 750Q371 750 397 748L440 540L556 745H626L458 454L552 0H393L340 250L195 0H134ZM607 153Q607 222 634.0 305.0Q661 388 722.0 448.5Q783 509 877 509Q987 509 987 413Q987 357 955.0 310.0Q923 263 870.0 234.5Q817 206 757 202Q755 172 755 162Q755 113 772.0 95.5Q789 78 827 78Q881 78 919.5 103.0Q958 128 1004 179H1038Q927 -6 763 -6Q689 -6 648.0 32.5Q607 71 607 153ZM910 415Q910 456 885 456Q849 456 814.5 393.0Q780 330 765 250Q802 252 835.5 276.0Q869 300 889.5 337.0Q910 374 910 415ZM1080 537H1224L1208 462Q1258 505 1325 505Q1381 505 1414.0 468.0Q1447 431 1447 347Q1447 268 1424.0 187.5Q1401 107 1346.0 50.5Q1291 -6 1201 -6Q1137 -6 1116 30L1064 -214L913 -250ZM1310 350Q1310 433 1260 433Q1242 433 1223.5 420.0Q1205 407 1191 384L1132 104Q1140 81 1170 81Q1218 81 1249.5 126.0Q1281 171 1295.5 233.5Q1310 296 1310 350ZM1459 155Q1459 229 1488.5 310.5Q1518 392 1576.5 448.5Q1635 505 1716 505Q1757 505 1777.0 491.0Q1797 477 1797 454V447L1808 500H1952L1880 160Q1876 145 1876 128Q1876 108 1885.5 99.5Q1895 91 1917 91Q1931 91 1939 95Q1917 39 1897.0 16.5Q1877 -6 1839 -6Q1798 -6 1772.5 18.5Q1747 43 1741 87Q1680 -6 1592 -6Q1535 -6 1497.0 33.0Q1459 72 1459 155ZM1740 179 1788 405Q1788 418 1778.0 430.5Q1768 443 1747 443Q1707 443 1675.0 396.5Q1643 350 1625.0 284.5Q1607 219 1607 169Q1607 119 1621.5 105.0Q1636 91 1657 91Q1682 91 1706.5 114.5Q1731 138 1740 179Z';
