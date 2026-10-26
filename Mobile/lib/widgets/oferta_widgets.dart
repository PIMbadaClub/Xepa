import 'package:flutter/material.dart';

import '../api/api.dart';
import '../models/oferta.dart';
import '../theme.dart';
import 'xepa_logo.dart';

/// Endereço absoluto de uma foto: em desenvolvimento a API devolve caminhos relativos (/uploads/...).
String? urlFoto(String? url) {
  if (url == null || url.isEmpty) return null;
  return url.startsWith('/') ? '$apiUrl$url' : url;
}

/// Foto da oferta; sem foto (ou se ela não carregar), um fundo da categoria com o ícone e um tomatinho escondido.
class FotoOferta extends StatelessWidget {
  const FotoOferta({super.key, required this.url, required this.categoria, this.tamanhoIcone = 40});

  final String? url;
  final Categoria categoria;
  final double tamanhoIcone;

  @override
  Widget build(BuildContext context) {
    final reserva = _SemFoto(categoria: categoria, tamanhoIcone: tamanhoIcone);
    final endereco = urlFoto(url);
    if (endereco == null) return reserva;
    return Image.network(
      endereco,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => reserva,
      frameBuilder: (_, filho, quadro, sincrono) => sincrono || quadro != null
          ? filho
          : ColoredBox(color: categoria.fundo),
    );
  }
}

class _SemFoto extends StatelessWidget {
  const _SemFoto({required this.categoria, required this.tamanhoIcone});

  final Categoria categoria;
  final double tamanhoIcone;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [categoria.fundo, Color.lerp(categoria.fundo, categoria.cor, 0.18)!],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            right: -tamanhoIcone * 0.3,
            bottom: -tamanhoIcone * 0.3,
            child: TomateMarcaDagua(tamanho: tamanhoIcone * 1.8, opacidade: 0.1, cor: categoria.cor),
          ),
          Center(child: Icon(categoria.icone, size: tamanhoIcone, color: categoria.cor)),
        ],
      ),
    );
  }
}

/// Avatar redondo da loja (logo, ou a inicial sobre a cor da categoria).
class AvatarLoja extends StatelessWidget {
  const AvatarLoja({super.key, required this.nome, required this.categoria, this.logoUrl, this.tamanho = 32, this.borda = true});

  final String nome;
  final Categoria categoria;
  final String? logoUrl;
  final double tamanho;
  final bool borda;

  @override
  Widget build(BuildContext context) {
    final url = urlFoto(logoUrl);
    return Container(
      width: tamanho,
      height: tamanho,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: categoria.fundo,
        border: borda ? Border.all(color: Colors.white, width: 2) : null,
        image: url == null ? null : DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
      ),
      alignment: Alignment.center,
      child: url != null
          ? null
          : Text(
              nome.isEmpty ? '?' : nome[0].toUpperCase(),
              style: TextStyle(color: categoria.cor, fontWeight: FontWeight.w800, fontSize: tamanho * 0.42),
            ),
    );
  }
}

/// Selo "Restam 3" / "Último!" sobre a foto.
class SeloRestantes extends StatelessWidget {
  const SeloRestantes({super.key, required this.restantes, this.sobreFoto = true});

  final int restantes;
  final bool sobreFoto;

  @override
  Widget build(BuildContext context) {
    final texto = switch (restantes) {
      0 => 'Esgotado',
      1 => 'Último!',
      _ => 'Restam $restantes',
    };
    final urgente = restantes <= 2;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: sobreFoto
            ? (urgente ? XepaCores.tomate : Colors.white)
            : (urgente ? XepaCores.tomateClaro : XepaCores.verdeClaro),
        borderRadius: BorderRadius.circular(XepaRaios.pilula),
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: sobreFoto
              ? (urgente ? Colors.white : XepaCores.tomateEscuro)
              : (urgente ? XepaCores.tomateEscuro : XepaCores.verdeTexto),
        ),
      ),
    );
  }
}

/// Selo verde do desconto ("-64%").
class SeloDesconto extends StatelessWidget {
  const SeloDesconto({super.key, required this.percentual});

  final int percentual;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: XepaCores.verdeClaro, borderRadius: BorderRadius.circular(8)),
      child: Text(
        '-$percentual%',
        style: const TextStyle(color: XepaCores.verde, fontSize: 12, fontWeight: FontWeight.w800),
      ),
    );
  }
}

/// Banner "Hora da xepa", com um tomatão escondido no canto.
class HoraDaXepaBanner extends StatelessWidget {
  const HoraDaXepaBanner({super.key, required this.quantidade, this.precoMinimo, this.onVerOfertas});

  final int quantidade;
  final double? precoMinimo;
  final VoidCallback? onVerOfertas;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(XepaRaios.cartao),
      child: Container(
        color: XepaCores.tomate,
        child: Stack(
          children: [
            const Positioned(
              right: -26,
              top: -18,
              child: TomateMarcaDagua(tamanho: 130, opacidade: 0.16, angulo: 0.35, cor: Colors.white),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Hora da xepa',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    precoMinimo == null
                        ? 'Sacolas com até 70% de desconto'
                        : '$quantidade ${quantidade == 1 ? 'sacola' : 'sacolas'} a partir de ${formatarPreco(precoMinimo!)}',
                    style: TextStyle(color: Colors.white.withAlpha(225), fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Material(
                    color: Colors.white,
                    shape: const StadiumBorder(),
                    child: InkWell(
                      customBorder: const StadiumBorder(),
                      onTap: onVerOfertas,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        child: Text(
                          'Ver ofertas',
                          style: TextStyle(color: XepaCores.tomateEscuro, fontSize: 12.5, fontWeight: FontWeight.w800),
                        ),
                      ),
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

/// Cartão de oferta com foto grande. [largura] fixa é para o carrossel; sem ela ocupa a linha.
class OfertaCard extends StatelessWidget {
  const OfertaCard({super.key, required this.oferta, this.onTap, this.largura, this.alturaFoto = 140});

  final Oferta oferta;
  final VoidCallback? onTap;
  final double? largura;
  final double alturaFoto;

  @override
  Widget build(BuildContext context) {
    final o = oferta;
    const secundario = TextStyle(color: XepaCores.textoSecundario, fontSize: 12.5);

    return Container(
      width: largura,
      decoration: BoxDecoration(
        color: XepaCores.cartao,
        borderRadius: BorderRadius.circular(XepaRaios.cartao),
        border: Border.all(color: XepaCores.borda),
        boxShadow: sombraCartao,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(XepaRaios.cartao),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: alturaFoto,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Hero(tag: 'foto-${o.id}', child: FotoOferta(url: o.fotoUrl, categoria: o.categoria)),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0x80000000)],
                          stops: [0.45, 1],
                        ),
                      ),
                    ),
                    Positioned(top: 10, left: 10, child: SeloRestantes(restantes: o.restantes)),
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 10,
                      child: Row(
                        children: [
                          AvatarLoja(nome: o.loja, categoria: o.categoria, logoUrl: o.logoUrl, tamanho: 30),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              o.loja,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                shadows: [Shadow(color: Color(0x66000000), blurRadius: 4)],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 11, 14, 13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      o.titulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.schedule_rounded, size: 14, color: XepaCores.textoSecundario),
                        const SizedBox(width: 3),
                        Flexible(child: Text(o.retirada, maxLines: 1, overflow: TextOverflow.ellipsis, style: secundario)),
                        if (o.distanciaKm != null) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.place_outlined, size: 14, color: XepaCores.textoSecundario),
                          const SizedBox(width: 2),
                          Text(formatarDistancia(o.distanciaKm!), style: secundario),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              formatarPreco(o.precoOriginal),
                              style: secundario.copyWith(fontSize: 12, decoration: TextDecoration.lineThrough),
                            ),
                            Text(
                              formatarPreco(o.preco),
                              style: const TextStyle(
                                color: XepaCores.tomate,
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                                height: 1.15,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        SeloDesconto(percentual: o.descontoPercentual),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Estado vazio ou de erro, com o tomatinho no lugar do ícone genérico.
class EstadoVazio extends StatelessWidget {
  const EstadoVazio({super.key, required this.titulo, this.texto, this.acao, this.onAcao});

  final String titulo;
  final String? texto;
  final String? acao;
  final VoidCallback? onAcao;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Column(
        children: [
          const TomateMarcaDagua(tamanho: 64, opacidade: 0.9, angulo: -0.2),
          const SizedBox(height: 12),
          Text(titulo, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          if (texto != null) ...[
            const SizedBox(height: 4),
            Text(texto!, textAlign: TextAlign.center, style: const TextStyle(color: XepaCores.textoSecundario, height: 1.4)),
          ],
          if (acao != null) ...[
            const SizedBox(height: 8),
            TextButton(onPressed: onAcao, child: Text(acao!)),
          ],
        ],
      ),
    );
  }
}
