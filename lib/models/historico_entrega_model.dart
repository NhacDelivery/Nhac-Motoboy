import 'status.dart';

/// Espelha EntregaHistoricoDTO (backend, domain/entregador/dto).
class HistoricoEntregaModel {
  final String pedidoId;
  final String? lojaNome;
  final String? bairroEntrega;
  final String? cidadeEntrega;
  final double? taxaFrete;
  final StatusPedido status;
  final DateTime? coletadoEm;
  final DateTime? entregueEm;
  final DateTime? criadoEm;

  HistoricoEntregaModel({
    required this.pedidoId,
    this.lojaNome,
    this.bairroEntrega,
    this.cidadeEntrega,
    this.taxaFrete,
    required this.status,
    this.coletadoEm,
    this.entregueEm,
    this.criadoEm,
  });

  factory HistoricoEntregaModel.fromJson(Map<String, dynamic> json) {
    return HistoricoEntregaModel(
      pedidoId: json['pedidoId'] as String,
      lojaNome: json['lojaNome'] as String?,
      bairroEntrega: json['bairroEntrega'] as String?,
      cidadeEntrega: json['cidadeEntrega'] as String?,
      taxaFrete: (json['taxaFrete'] as num?)?.toDouble(),
      status: StatusPedido.parse(json['status']),
      coletadoEm: json['coletadoEm'] != null ? DateTime.tryParse(json['coletadoEm'] as String) : null,
      entregueEm: json['entregueEm'] != null ? DateTime.tryParse(json['entregueEm'] as String) : null,
      criadoEm: json['criadoEm'] != null ? DateTime.tryParse(json['criadoEm'] as String) : null,
    );
  }
}

/// Espelha a resposta paginada padrão do Spring Data (`Page<T>`) para o
/// endpoint GET /api/v1/entregador/entregas.
class HistoricoEntregasPagina {
  final List<HistoricoEntregaModel> itens;
  final int totalPaginas;
  final int paginaAtual;
  final bool ultima;

  HistoricoEntregasPagina({
    required this.itens,
    required this.totalPaginas,
    required this.paginaAtual,
    required this.ultima,
  });

  factory HistoricoEntregasPagina.vazia() =>
      HistoricoEntregasPagina(itens: [], totalPaginas: 0, paginaAtual: 0, ultima: true);

  factory HistoricoEntregasPagina.fromJson(Map<String, dynamic> json) {
    final conteudo = (json['content'] as List<dynamic>? ?? [])
        .map((e) => HistoricoEntregaModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return HistoricoEntregasPagina(
      itens: conteudo,
      totalPaginas: json['totalPages'] as int? ?? 0,
      paginaAtual: json['number'] as int? ?? 0,
      ultima: json['last'] as bool? ?? true,
    );
  }
}
