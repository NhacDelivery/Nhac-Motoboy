class CoordenadaModel {
  final double latitude;
  final double longitude;

  const CoordenadaModel({
    required this.latitude,
    required this.longitude,
  });

  factory CoordenadaModel.fromJson(Map<String, dynamic>? json) {
    if (json == null || json['latitude'] is! num || json['longitude'] is! num) {
      throw const FormatException('Coordenadas da rota indisponíveis.');
    }
    return CoordenadaModel(
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class RotaModel {
  final String pedidoId;
  final String lojaNome;
  final CoordenadaModel origem;
  final CoordenadaModel destino;
  final double distanciaMetros;
  final double distanciaKm;
  final int duracaoEstimadaMinutos;
  final String polyline;
  final List<CoordenadaModel> waypoints;

  RotaModel({
    required this.pedidoId,
    required this.lojaNome,
    required this.origem,
    required this.destino,
    required this.distanciaMetros,
    required this.distanciaKm,
    required this.duracaoEstimadaMinutos,
    required this.polyline,
    required this.waypoints,
  });

  factory RotaModel.fromJson(Map<String, dynamic> json) {
    var rawWaypoints = json['waypoints'] as List<dynamic>? ?? [];
    List<CoordenadaModel> listaPontos = rawWaypoints
        .map((p) => CoordenadaModel.fromJson(p as Map<String, dynamic>))
        .toList();

    return RotaModel(
      pedidoId: json['pedidoId']?.toString() ?? '',
      lojaNome: json['lojaNome']?.toString() ?? '',
      origem: CoordenadaModel.fromJson(json['origem'] as Map<String, dynamic>?),
      destino: CoordenadaModel.fromJson(json['destino'] as Map<String, dynamic>?),
      distanciaMetros: (json['distanciaMetros'] as num?)?.toDouble() ?? 0.0,
      distanciaKm: (json['distanciaKm'] as num?)?.toDouble() ?? 0.0,
      duracaoEstimadaMinutos: (json['duracaoEstimadaMinutos'] as num?)?.toInt() ?? 0,
      polyline: json['polyline']?.toString() ?? '',
      waypoints: listaPontos,
    );
  }
}
