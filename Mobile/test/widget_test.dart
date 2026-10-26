import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xepa/models/oferta.dart';
import 'package:xepa/models/pedido.dart';
import 'package:xepa/theme.dart';
import 'package:xepa/widgets/oferta_widgets.dart';

Map<String, dynamic> ofertaJson({double? distancia}) => {
      'id': 7,
      'tipo': 'SacolaSurpresa',
      'titulo': 'Sacola surpresa',
      'descricao': 'Pães do dia',
      'fotoUrl': null,
      'precoOriginal': 36.0,
      'preco': 12.9,
      'restantes': 3,
      'kgSalvos': 1.5,
      'retiradaInicio': DateTime.now().toUtc().toIso8601String(),
      'retiradaFim': DateTime.now().toUtc().add(const Duration(hours: 2)).toIso8601String(),
      'distanciaKm': distancia,
      'estabelecimento': {
        'id': 1,
        'nome': 'Padaria Pão Dourado',
        'categoria': 'Padaria',
        'bairro': 'Centro',
        'latitude': -23.5,
        'longitude': -46.6,
      },
    };

void main() {
  test('oferta da API vira o modelo do app', () {
    final o = Oferta.fromJson(ofertaJson(distancia: 0.42));

    expect(o.idApi, 7);
    expect(o.categoria, Categoria.padaria);
    expect(o.sacolaSurpresa, isTrue);
    expect(o.descontoPercentual, 64);
    expect(o.retirada, startsWith('Hoje, '));
    expect(o.distanciaKm, closeTo(0.42, 0.001));
  });

  test('categoria é enviada à API com a primeira letra maiúscula', () {
    expect(Categoria.restaurante.nomeApi, 'Restaurante');
  });

  test('status da API e regra de cancelamento', () {
    expect(StatusPedido.daApi('AguardandoPagamento'), StatusPedido.aguardandoPagamento);
    expect(StatusPedido.daApi('SaiuParaEntrega'), StatusPedido.saiuParaEntrega);
    expect(StatusPedido.pendente.cancelavel, isTrue);
    expect(StatusPedido.confirmado.cancelavel, isFalse);
  });

  test('pedido da API com endereço de entrega', () {
    final p = Pedido.fromJson({
      'id': 3,
      'status': 'Pendente',
      'tipoEntrega': 'Entrega',
      'quantidade': 1,
      'precoUnitario': 12.9,
      'taxaEntrega': 3.78,
      'valorTotal': 16.68,
      'codigoRetirada': '0420',
      'criadoEm': '2026-10-25T22:00:00+00:00',
      'oferta': {
        'id': 1,
        'titulo': 'Sacola surpresa',
        'fotoUrl': null,
        'estabelecimentoId': 1,
        'estabelecimento': 'Padaria Pão Dourado',
        'retiradaInicio': '2026-10-26T21:00:00+00:00',
        'retiradaFim': '2026-10-26T23:00:00+00:00',
      },
      'enderecoEntrega': {'logradouro': 'Av. Paulista', 'numero': '1000', 'bairro': 'Bela Vista', 'latitude': -23.56, 'longitude': -46.65},
    });

    expect(p.entrega, isTrue);
    expect(p.endereco!.resumo, 'Av. Paulista, 1000 · Bela Vista');
    expect(p.valorTotal, 16.68);
  });

  testWidgets('cartão da oferta mostra loja, preço e desconto sem distância quando não há GPS', (tester) async {
    final oferta = Oferta.fromJson(ofertaJson());
    await tester.pumpWidget(MaterialApp(theme: xepaTema(), home: Scaffold(body: OfertaCard(oferta: oferta))));

    expect(find.text('Padaria Pão Dourado'), findsOneWidget);
    expect(find.text('Sacola surpresa'), findsOneWidget);
    expect(find.text('-64%'), findsOneWidget);
    expect(find.textContaining('km'), findsNothing);
  });
}
