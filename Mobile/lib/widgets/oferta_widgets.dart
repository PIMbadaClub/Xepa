import 'package:flutter/material.dart';

import '../models/oferta.dart';
import '../theme.dart';

class HoraDaXepaBanner extends StatelessWidget {
  const HoraDaXepaBanner({super.key, this.onVerOfertas});

  final VoidCallback? onVerOfertas;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: XepaCores.tomate,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Hora da xepa',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Sacolas a partir de R\$ 9,90 até as 22h',
                  style: TextStyle(color: Color(0xFFFFE3DF), fontSize: 12.5),
                ),
                const SizedBox(height: 12),
                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: onVerOfertas,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      child: Text(
                        'Ver ofertas',
                        style: TextStyle(
                          color: XepaCores.tomateEscuro,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.access_time_rounded, size: 56, color: Color(0xFFFFD9D4)),
        ],
      ),
    );
  }
}

class SeloRestantes extends StatelessWidget {
  const SeloRestantes({super.key, required this.restantes});

  final int restantes;

  @override
  Widget build(BuildContext context) {
    final poucos = restantes <= 2;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: poucos ? XepaCores.tomateClaro : XepaCores.verdeClaro,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$restantes ${restantes == 1 ? 'restante' : 'restantes'}',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: poucos ? XepaCores.tomateEscuro : XepaCores.verdeTexto,
        ),
      ),
    );
  }
}

class OfertaCard extends StatelessWidget {
  const OfertaCard({super.key, required this.oferta, this.onTap});

  final Oferta oferta;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const secundario = TextStyle(color: XepaCores.textoSecundario, fontSize: 12.5);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: oferta.categoria.fundo,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(oferta.categoria.icone, color: oferta.categoria.cor, size: 32),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            oferta.loja,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: 6),
                        SeloRestantes(restantes: oferta.restantes),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${oferta.titulo} · ${formatarDistancia(oferta.distanciaKm)}',
                      style: secundario,
                    ),
                    Row(
                      children: [
                        const Icon(Icons.schedule, size: 13, color: XepaCores.textoSecundario),
                        const SizedBox(width: 3),
                        Text(oferta.retirada, style: secundario),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          formatarPreco(oferta.precoOriginal),
                          style: secundario.copyWith(decoration: TextDecoration.lineThrough),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          formatarPreco(oferta.preco),
                          style: const TextStyle(
                            color: XepaCores.verde,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '-${oferta.descontoPercentual}%',
                          style: const TextStyle(
                            color: XepaCores.verde,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
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
