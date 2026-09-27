/// Espelha GanhosEntregadorDTO (backend, domain/entregador/dto).
class GanhoDiaModel {
  final DateTime data;
  final double valor;
  final int entregas;

  GanhoDiaModel({required this.data, required this.valor, required this.entregas});

  factory GanhoDiaModel.fromJson(Map<String, dynamic> json) {
    return GanhoDiaModel(
      data: DateTime.parse(json['data'] as String),
      valor: (json['valor'] as num?)?.toDouble() ?? 0.0,
      entregas: json['entregas'] as int? ?? 0,
    );
  }
}

class GanhosEntregadorModel {
  final String periodo;
  final double totalGanhos;
  final int totalEntregas;
  final double ticketMedio;
  final List<GanhoDiaModel> porDia;

  GanhosEntregadorModel({
    required this.periodo,
    required this.totalGanhos,
    required this.totalEntregas,
    required this.ticketMedio,
    required this.porDia,
  });

  factory GanhosEntregadorModel.fromJson(Map<String, dynamic> json) {
    return GanhosEntregadorModel(
      periodo: json['periodo'] as String? ?? 'HOJE',
      totalGanhos: (json['totalGanhos'] as num?)?.toDouble() ?? 0.0,
      totalEntregas: json['totalEntregas'] as int? ?? 0,
      ticketMedio: (json['ticketMedio'] as num?)?.toDouble() ?? 0.0,
      porDia: (json['porDia'] as List<dynamic>? ?? [])
          .map((e) => GanhoDiaModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
