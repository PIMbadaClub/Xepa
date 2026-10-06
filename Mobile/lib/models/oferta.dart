import 'package:flutter/material.dart';

import '../theme.dart';

enum Categoria { restaurante, padaria, mercado, feira }

extension CategoriaInfo on Categoria {
  String get rotulo => switch (this) {
        Categoria.restaurante => 'Restaurantes',
        Categoria.padaria => 'Padarias',
        Categoria.mercado => 'Mercados',
        Categoria.feira => 'Feiras',
      };

  IconData get icone => switch (this) {
        Categoria.restaurante => Icons.restaurant,
        Categoria.padaria => Icons.bakery_dining_outlined,
        Categoria.mercado => Icons.shopping_cart_outlined,
        Categoria.feira => Icons.eco_outlined,
      };

  Color get fundo => switch (this) {
        Categoria.restaurante => XepaCores.tomateClaro,
        Categoria.padaria => XepaCores.pao,
        Categoria.mercado => XepaCores.bege,
        Categoria.feira => XepaCores.verdeClaro,
      };

  Color get cor => switch (this) {
        Categoria.restaurante => XepaCores.tomateEscuro,
        Categoria.padaria => XepaCores.paoEscuro,
        Categoria.mercado => XepaCores.madeira,
        Categoria.feira => XepaCores.verde,
      };
}

class Oferta {
  const Oferta({
    required this.id,
    required this.loja,
    required this.titulo,
    required this.descricao,
    required this.retirada,
    required this.distanciaKm,
    required this.precoOriginal,
    required this.preco,
    required this.restantes,
    required this.avaliacao,
    required this.kgSalvos,
    required this.categoria,
  });

  final String id;
  final String loja;
  final String titulo;
  final String descricao;
  final String retirada;
  final double distanciaKm;
  final double precoOriginal;
  final double preco;
  final int restantes;
  final double avaliacao;
  final double kgSalvos;
  final Categoria categoria;

  int get descontoPercentual => ((1 - preco / precoOriginal) * 100).round();
}

const ofertasExemplo = <Oferta>[
  Oferta(
    id: '1',
    loja: 'Padaria Pão Dourado',
    titulo: 'Sacola surpresa',
    descricao:
        'Pães do dia, bolos, salgados e doces que não foram vendidos. O conteúdo muda a cada dia.',
    retirada: 'Hoje, 18h–20h',
    distanciaKm: 0.4,
    precoOriginal: 36,
    preco: 12.90,
    restantes: 3,
    avaliacao: 4.8,
    kgSalvos: 1.5,
    categoria: Categoria.padaria,
  ),
  Oferta(
    id: '2',
    loja: 'Cantina da Nona',
    titulo: 'Marmita do dia',
    descricao:
        'Pratos preparados no dia, como massas, carnes e acompanhamentos, embalados para viagem.',
    retirada: 'Hoje, 21h–22h',
    distanciaKm: 0.9,
    precoOriginal: 42,
    preco: 15.90,
    restantes: 1,
    avaliacao: 4.7,
    kgSalvos: 1.2,
    categoria: Categoria.restaurante,
  ),
  Oferta(
    id: '3',
    loja: 'Barraca do Seu Zé',
    titulo: 'Caixote de hortifrúti',
    descricao:
        'Frutas, verduras e legumes da xepa do fim da feira, ainda frescos e bons para consumo.',
    retirada: 'Hoje, 12h–13h',
    distanciaKm: 1.2,
    precoOriginal: 30,
    preco: 9.90,
    restantes: 5,
    avaliacao: 4.9,
    kgSalvos: 3.0,
    categoria: Categoria.feira,
  ),
  Oferta(
    id: '4',
    loja: 'Mercadinho Bom Preço',
    titulo: 'Kit mercado',
    descricao:
        'Frios, laticínios e outros itens próximos da data de validade, todos dentro do prazo.',
    retirada: 'Hoje, 19h–21h',
    distanciaKm: 1.6,
    precoOriginal: 45,
    preco: 17.90,
    restantes: 2,
    avaliacao: 4.6,
    kgSalvos: 2.0,
    categoria: Categoria.mercado,
  ),
];
