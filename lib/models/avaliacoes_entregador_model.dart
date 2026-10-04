class AvaliacaoEntregadorModel {
  final String pedidoId, clienteNome;
  final String? comentario;
  final int nota;
  final DateTime? criadoEm;
  const AvaliacaoEntregadorModel({
    required this.pedidoId,
    required this.clienteNome,
    required this.nota,
    this.comentario,
    this.criadoEm,
  });
  factory AvaliacaoEntregadorModel.fromJson(Map<String, dynamic> json) =>
      AvaliacaoEntregadorModel(
        pedidoId: json['pedidoId'] as String,
        clienteNome: json['clienteNome'] as String? ?? 'Cliente',
        nota: (json['nota'] as num).toInt(),
        comentario: json['comentario'] as String?,
        criadoEm: DateTime.tryParse(json['criadoEm']?.toString() ?? ''),
      );
}

class AvaliacoesEntregadorPagina {
  final double media;
  final int total, paginaAtual;
  final bool ultima;
  final List<AvaliacaoEntregadorModel> itens;
  const AvaliacoesEntregadorPagina({
    required this.media,
    required this.total,
    required this.paginaAtual,
    required this.ultima,
    required this.itens,
  });
  factory AvaliacoesEntregadorPagina.fromJson(Map<String, dynamic> json) {
    final resumo = json['resumo'] as Map<String, dynamic>;
    final pagina = json['avaliacoes'] as Map<String, dynamic>;
    return AvaliacoesEntregadorPagina(
      media: (resumo['media'] as num).toDouble(),
      total: (resumo['total'] as num).toInt(),
      paginaAtual: (pagina['number'] as num).toInt(),
      ultima: pagina['last'] == true,
      itens: (pagina['content'] as List)
          .map((e) => AvaliacaoEntregadorModel.fromJson(e))
          .toList(),
    );
  }
}
