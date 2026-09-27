class OfertaEntregaModel {
  int segundosEm(DateTime agora) {
    final fim = DateTime.tryParse(expiraEm ?? '');
    if (fim == null) return 0;
    return (fim.difference(agora).inMilliseconds / 1000).ceil().clamp(0, 86400);
  }
  bool get expirada => segundosEm(DateTime.now()) == 0;
  final String id;
  final String pedidoId;
  final String lojaNome;
  final String lojaEndereco;
  final double? lojaLatitude;
  final double? lojaLongitude;
  final String? clienteBairro;
  final String? clienteCidade;
  final double taxaFrete;
  final String? criadoEm;
  final String? expiraEm;
  final int tempoRestanteSegundos;

  OfertaEntregaModel({
    required this.id,
    required this.pedidoId,
    required this.lojaNome,
    required this.lojaEndereco,
    this.lojaLatitude,
    this.lojaLongitude,
    this.clienteBairro,
    this.clienteCidade,
    required this.taxaFrete,
    this.criadoEm,
    this.expiraEm,
    required this.tempoRestanteSegundos,
  });

  factory OfertaEntregaModel.fromJson(Map<String, dynamic> json) {
    return OfertaEntregaModel(
      id: json['id']?.toString() ?? '',
      pedidoId: json['pedidoId']?.toString() ?? '',
      lojaNome: json['lojaNome']?.toString() ?? 'Restaurante Parceiro',
      lojaEndereco: json['lojaEndereco']?.toString() ?? '',
      lojaLatitude: json['lojaLatitude'] != null ? (json['lojaLatitude'] as num).toDouble() : null,
      lojaLongitude: json['lojaLongitude'] != null ? (json['lojaLongitude'] as num).toDouble() : null,
      clienteBairro: json['clienteBairro']?.toString(),
      clienteCidade: json['clienteCidade']?.toString(),
      taxaFrete: (json['taxaFrete'] as num?)?.toDouble() ?? 0.0,
      criadoEm: json['criadoEm']?.toString(),
      expiraEm: json['expiraEm']?.toString(),
      tempoRestanteSegundos: (json['tempoRestanteSegundos'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pedidoId': pedidoId,
      'lojaNome': lojaNome,
      'lojaEndereco': lojaEndereco,
      'lojaLatitude': lojaLatitude,
      'lojaLongitude': lojaLongitude,
      'clienteBairro': clienteBairro,
      'clienteCidade': clienteCidade,
      'taxaFrete': taxaFrete,
      'criadoEm': criadoEm,
      'expiraEm': expiraEm,
      'tempoRestanteSegundos': tempoRestanteSegundos,
    };
  }
}
