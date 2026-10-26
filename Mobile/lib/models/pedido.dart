import 'package:flutter/material.dart';

import '../theme.dart';

enum StatusPedido {
  aguardandoPagamento('Aguardando pagamento', Icons.qr_code_2_rounded),
  pendente('Pago · aguardando a loja', Icons.hourglass_top_rounded),
  confirmado('Confirmado pela loja', Icons.thumb_up_alt_outlined),
  emPreparo('Em preparo', Icons.soup_kitchen_outlined),
  prontoParaRetirada('Pronto para retirada', Icons.storefront_outlined),
  saiuParaEntrega('Saiu para entrega', Icons.delivery_dining_outlined),
  entregue('Entregue', Icons.check_circle_outline_rounded),
  cancelado('Cancelado', Icons.cancel_outlined);

  const StatusPedido(this.rotulo, this.icone);

  final String rotulo;
  final IconData icone;

  static StatusPedido daApi(String valor) => values.byName(valor[0].toLowerCase() + valor.substring(1));

  bool get emAndamento => this != entregue && this != cancelado;

  /// Cliente só cancela antes de a loja confirmar (RN05).
  bool get cancelavel => this == aguardandoPagamento || this == pendente;

  Color get cor => switch (this) {
        entregue => XepaCores.verde,
        cancelado => XepaCores.textoSecundario,
        aguardandoPagamento => XepaCores.paoEscuro,
        _ => XepaCores.tomateEscuro,
      };
}

class EnderecoPedido {
  const EnderecoPedido({required this.logradouro, required this.numero, required this.bairro, this.latitude, this.longitude});

  factory EnderecoPedido.fromJson(Map<String, dynamic> j) => EnderecoPedido(
        logradouro: j['logradouro'] as String,
        numero: j['numero'] as String,
        bairro: j['bairro'] as String,
        latitude: (j['latitude'] as num?)?.toDouble(),
        longitude: (j['longitude'] as num?)?.toDouble(),
      );

  final String logradouro;
  final String numero;
  final String bairro;
  final double? latitude;
  final double? longitude;

  String get resumo => '$logradouro, $numero · $bairro';
}

class Pedido {
  const Pedido({
    required this.id,
    required this.status,
    required this.entrega,
    required this.quantidade,
    required this.taxaEntrega,
    required this.valorTotal,
    required this.codigoRetirada,
    required this.criadoEm,
    required this.oferta,
    required this.loja,
    required this.retiradaInicio,
    required this.retiradaFim,
    this.endereco,
    this.fotoUrl,
  });

  factory Pedido.fromJson(Map<String, dynamic> j) {
    final o = j['oferta'] as Map<String, dynamic>;
    return Pedido(
      id: j['id'] as int,
      status: StatusPedido.daApi(j['status'] as String),
      entrega: j['tipoEntrega'] == 'Entrega',
      quantidade: j['quantidade'] as int,
      taxaEntrega: (j['taxaEntrega'] as num).toDouble(),
      valorTotal: (j['valorTotal'] as num).toDouble(),
      codigoRetirada: j['codigoRetirada'] as String?,
      criadoEm: DateTime.parse(j['criadoEm'] as String).toLocal(),
      oferta: o['titulo'] as String,
      loja: o['estabelecimento'] as String,
      retiradaInicio: DateTime.parse(o['retiradaInicio'] as String).toLocal(),
      retiradaFim: DateTime.parse(o['retiradaFim'] as String).toLocal(),
      endereco: j['enderecoEntrega'] == null ? null : EnderecoPedido.fromJson(j['enderecoEntrega'] as Map<String, dynamic>),
      fotoUrl: o['fotoUrl'] as String?,
    );
  }

  final int id;
  final StatusPedido status;
  final bool entrega;
  final int quantidade;
  final double taxaEntrega;
  final double valorTotal;
  final String? codigoRetirada;
  final DateTime criadoEm;
  final String oferta;
  final String loja;
  final DateTime retiradaInicio;
  final DateTime retiradaFim;
  final EnderecoPedido? endereco;
  final String? fotoUrl;
}

class Pagamento {
  const Pagamento({
    required this.idExterno,
    required this.pix,
    required this.status,
    required this.valor,
    required this.provedor,
    this.qrCodePix,
    this.urlCheckout,
    this.expiraEm,
  });

  factory Pagamento.fromJson(Map<String, dynamic> j) => Pagamento(
        idExterno: j['idExterno'] as String,
        pix: j['metodo'] == 'Pix',
        status: j['status'] as String,
        valor: (j['valor'] as num).toDouble(),
        provedor: j['provedor'] as String,
        qrCodePix: j['qrCodePix'] as String?,
        urlCheckout: j['urlCheckout'] as String?,
        expiraEm: j['expiraEm'] == null ? null : DateTime.parse(j['expiraEm'] as String).toLocal(),
      );

  final String idExterno;
  final bool pix;
  final String status;
  final double valor;
  final String provedor;
  final String? qrCodePix;
  final String? urlCheckout;
  final DateTime? expiraEm;

  bool get simulado => provedor == 'Simulado';
}

class EnderecoSalvo {
  const EnderecoSalvo({required this.id, required this.apelido, required this.endereco, required this.principal});

  factory EnderecoSalvo.fromJson(Map<String, dynamic> j) => EnderecoSalvo(
        id: j['id'] as int,
        apelido: j['apelido'] as String,
        principal: j['principal'] as bool,
        endereco: EnderecoPedido.fromJson(j['endereco'] as Map<String, dynamic>),
      );

  final int id;
  final String apelido;
  final bool principal;
  final EnderecoPedido endereco;
}
