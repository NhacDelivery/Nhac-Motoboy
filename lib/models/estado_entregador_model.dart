import 'entrega_ativa_model.dart';
import 'entregador_cadastro_model.dart';
import 'oferta_entrega_model.dart';

class EstadoEntregadorModel {
  final EntregadorCadastroModel? perfil;
  final EntregaAtivaModel? entrega;
  final List<OfertaEntregaModel> ofertas;
  EstadoEntregadorModel({this.perfil, this.entrega, this.ofertas = const []});
  factory EstadoEntregadorModel.fromJson(Map<String, dynamic> json) =>
      EstadoEntregadorModel(
        perfil: json['perfil'] == null
            ? null
            : EntregadorCadastroModel.fromJson(json['perfil']),
        entrega: json['entrega'] == null
            ? null
            : EntregaAtivaModel.fromJson(json['entrega']),
        ofertas: (json['ofertas'] as List? ?? [])
            .map((e) => OfertaEntregaModel.fromJson(e))
            .toList(),
      );
}
