import 'package:flutter/material.dart';

import '../theme.dart';

enum Categoria { restaurante, padaria, mercado, feira }

extension CategoriaInfo on Categoria {
  /// Nome do enum na API (CategoriaEstabelecimento).
  String get nomeApi => name[0].toUpperCase() + name.substring(1);

  String get rotulo => switch (this) {
        Categoria.restaurante => 'Restaurantes',
        Categoria.padaria => 'Padarias',
        Categoria.mercado => 'Mercados',
        Categoria.feira => 'Feiras',
      };

  String get singular => switch (this) {
        Categoria.restaurante => 'Restaurante',
        Categoria.padaria => 'Padaria',
        Categoria.mercado => 'Mercado',
        Categoria.feira => 'Feira',
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
    this.avaliacoes = 0,
    this.funcionamento,
    this.aberta,
    required this.kgSalvos,
    required this.categoria,
    this.estabelecimentoId,
    this.fotoUrl,
    this.logoUrl,
    this.sacolaSurpresa = false,
    this.latitude,
    this.longitude,
  });

  /// Oferta como a API devolve em GET /api/ofertas.
  factory Oferta.fromJson(Map<String, dynamic> j) {
    final loja = j['estabelecimento'] as Map<String, dynamic>;
    return Oferta(
      id: (j['id'] as int).toString(),
      loja: loja['nome'] as String,
      titulo: j['titulo'] as String,
      descricao: (j['descricao'] as String?) ?? '',
      retirada: formatarJanela(DateTime.parse(j['retiradaInicio'] as String), DateTime.parse(j['retiradaFim'] as String)),
      distanciaKm: (j['distanciaKm'] as num?)?.toDouble(),
      precoOriginal: (j['precoOriginal'] as num).toDouble(),
      preco: (j['preco'] as num).toDouble(),
      restantes: j['restantes'] as int,
      avaliacao: (loja['nota'] as num?)?.toDouble(),
      avaliacoes: loja['avaliacoes'] as int? ?? 0,
      funcionamento: loja['funcionamento'] as String?,
      aberta: loja['aberta'] as bool?,
      kgSalvos: (j['kgSalvos'] as num?)?.toDouble() ?? 0,
      categoria: Categoria.values.byName((loja['categoria'] as String).toLowerCase()),
      estabelecimentoId: loja['id'] as int,
      fotoUrl: j['fotoUrl'] as String?,
      logoUrl: loja['logoUrl'] as String?,
      sacolaSurpresa: j['tipo'] == 'SacolaSurpresa',
      latitude: (loja['latitude'] as num?)?.toDouble(),
      longitude: (loja['longitude'] as num?)?.toDouble(),
    );
  }

  final String id;
  final String loja;
  final String titulo;
  final String descricao;
  final String retirada;

  /// Só vem quando o app manda a localização.
  final double? distanciaKm;
  final double precoOriginal;
  final double preco;
  final int restantes;

  /// Média das notas que os clientes deram à loja e às sacolas (nula sem avaliações).
  final double? avaliacao;
  final int avaliacoes;

  /// "Aberta · fecha às 20:00" (nulo se a loja não cadastrou horário de funcionamento).
  final String? funcionamento;
  final bool? aberta;
  final double kgSalvos;
  final Categoria categoria;
  final int? estabelecimentoId;
  final String? fotoUrl;
  final String? logoUrl;
  final bool sacolaSurpresa;
  final double? latitude;
  final double? longitude;

  int get idApi => int.parse(id);

  int get descontoPercentual => ((1 - preco / precoOriginal) * 100).round();
}

/// "Hoje, 18h–20h", "Amanhã, 12h–13h30" ou "26/10, 18h–20h", no horário do aparelho.
String formatarJanela(DateTime inicio, DateTime fim) {
  final i = inicio.toLocal(), f = fim.toLocal();
  final hoje = DateTime.now();
  final dia = DateTime(i.year, i.month, i.day);
  final diferenca = dia.difference(DateTime(hoje.year, hoje.month, hoje.day)).inDays;
  final rotulo = switch (diferenca) {
    0 => 'Hoje',
    1 => 'Amanhã',
    _ => '${i.day.toString().padLeft(2, '0')}/${i.month.toString().padLeft(2, '0')}',
  };
  String hora(DateTime d) => d.minute == 0 ? '${d.hour}h' : '${d.hour}h${d.minute.toString().padLeft(2, '0')}';
  return '$rotulo, ${hora(i)}–${hora(f)}';
}
