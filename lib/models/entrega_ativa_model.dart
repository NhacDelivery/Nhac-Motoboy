import 'status.dart';

class EnderecoEntregaModel {
  final String? rua;
  final String? numero;
  final String? bairro;
  final String? cidade;
  final String? estado;
  final String? cep;
  final String? complemento;

  EnderecoEntregaModel({
    this.rua,
    this.numero,
    this.bairro,
    this.cidade,
    this.estado,
    this.cep,
    this.complemento,
  });

  factory EnderecoEntregaModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return EnderecoEntregaModel();
    return EnderecoEntregaModel(
      rua: json['rua']?.toString(),
      numero: json['numero']?.toString(),
      bairro: json['bairro']?.toString(),
      cidade: json['cidade']?.toString(),
      estado: json['estado']?.toString(),
      cep: json['cep']?.toString(),
      complemento: json['complemento']?.toString(),
    );
  }

  String get formatado {
    final partes = <String>[];
    if (rua != null && rua!.isNotEmpty) {
      if (numero != null && numero!.isNotEmpty) {
        partes.add('$rua, $numero');
      } else {
        partes.add(rua!);
      }
    }
    if (bairro != null && bairro!.isNotEmpty) partes.add(bairro!);
    if (cidade != null && cidade!.isNotEmpty) partes.add(cidade!);
    if (complemento != null && complemento!.isNotEmpty) partes.add('($complemento)');
    return partes.isNotEmpty ? partes.join(' - ') : 'Endereço não informado';
  }
}

class EntregaAtivaModel {
  final String pedidoId;
  final String? lojaId;
  final String lojaNome;
  final String lojaEndereco;
  final double? lojaLatitude;
  final double? lojaLongitude;
  final String clienteNome;
  final String? clienteTelefone;
  final EnderecoEntregaModel? enderecoEntrega;
  final double? entregaLatitude;
  final double? entregaLongitude;
  final double valorTotal;
  final double taxaFrete;
  final String formaPagamento;
  final StatusPedido statusPedido;
  final String? observacao;

  EntregaAtivaModel({
    required this.pedidoId,
    this.lojaId,
    required this.lojaNome,
    required this.lojaEndereco,
    this.lojaLatitude,
    this.lojaLongitude,
    required this.clienteNome,
    this.clienteTelefone,
    this.enderecoEntrega,
    this.entregaLatitude,
    this.entregaLongitude,
    required this.valorTotal,
    required this.taxaFrete,
    required this.formaPagamento,
    required this.statusPedido,
    this.observacao,
  });

  factory EntregaAtivaModel.fromJson(Map<String, dynamic> json) {
    return EntregaAtivaModel(
      pedidoId: json['pedidoId']?.toString() ?? '',
      lojaId: json['lojaId']?.toString(),
      lojaNome: json['lojaNome']?.toString() ?? 'Restaurante',
      lojaEndereco: json['lojaEndereco']?.toString() ?? '',
      lojaLatitude: json['lojaLatitude'] != null ? (json['lojaLatitude'] as num).toDouble() : null,
      lojaLongitude: json['lojaLongitude'] != null ? (json['lojaLongitude'] as num).toDouble() : null,
      clienteNome: json['clienteNome']?.toString() ?? 'Cliente',
      clienteTelefone: json['clienteTelefone']?.toString(),
      enderecoEntrega: json['enderecoEntrega'] != null
          ? EnderecoEntregaModel.fromJson(json['enderecoEntrega'] as Map<String, dynamic>)
          : null,
      entregaLatitude: json['entregaLatitude'] != null ? (json['entregaLatitude'] as num).toDouble() : null,
      entregaLongitude: json['entregaLongitude'] != null ? (json['entregaLongitude'] as num).toDouble() : null,
      valorTotal: (json['valorTotal'] as num?)?.toDouble() ?? 0.0,
      taxaFrete: (json['taxaFrete'] as num?)?.toDouble() ?? 0.0,
      formaPagamento: json['formaPagamento']?.toString() ?? 'PIX',
      statusPedido: StatusPedido.parse(json['statusPedido']),
      observacao: json['observacao']?.toString(),
    );
  }
}
