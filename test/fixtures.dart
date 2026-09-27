import 'package:nhac_motoboy/models/entrega_ativa_model.dart';
import 'package:nhac_motoboy/models/entregador_cadastro_model.dart';
import 'package:nhac_motoboy/models/oferta_entrega_model.dart';
import 'package:nhac_motoboy/models/rota_model.dart';

Map<String, dynamic> profileJson([String status = 'ONLINE']) => {
  'id': 'e1', 'usuarioId': 'u1', 'statusOperacional': status, 'ativo': true,
  'nome': 'Maria', 'email': 'm@example.com', 'telefone': '+5511999999999',
  'cnh': '12345678900', 'placaVeiculo': 'ABC1D23', 'tipoVeiculo': 'MOTO',
};
EntregadorCadastroModel profile([String status = 'ONLINE']) => EntregadorCadastroModel.fromJson(profileJson(status));
Map<String, dynamic> activeJson([String status = 'PREPARANDO']) => {
  'pedidoId': 'p1', 'lojaId': 'l1', 'lojaNome': 'Loja', 'lojaEndereco': 'Rua A, 1',
  'clienteNome': 'Ana', 'taxaFrete': 8.5, 'valorTotal': 30, 'formaPagamento': 'PIX',
  'statusPedido': status, 'enderecoEntrega': {'rua': 'Rua B', 'numero': '2'},
};
EntregaAtivaModel active([String status = 'PREPARANDO']) => EntregaAtivaModel.fromJson(activeJson(status));
Map<String, dynamic> offerJson({bool expired = false}) => {
  'id': 'o1', 'pedidoId': 'p1', 'lojaNome': 'Loja', 'lojaEndereco': 'Rua A',
  'taxaFrete': 8.5, 'expiraEm': DateTime.now().add(Duration(seconds: expired ? -1 : 40)).toUtc().toIso8601String(),
  'tempoRestanteSegundos': 40,
};
OfertaEntregaModel offer({bool expired = false}) => OfertaEntregaModel.fromJson(offerJson(expired: expired));
Map<String, dynamic> routeJson() => {
  'pedidoId': 'p1', 'origem': {'latitude': -23.5, 'longitude': -46.6},
  'destino': {'latitude': -23.51, 'longitude': -46.61}, 'distanciaKm': 3.5,
  'distanciaMetros': 3500, 'duracaoEstimadaMinutos': 12, 'polyline': '',
  'waypoints': [{'latitude': -23.5, 'longitude': -46.6}, {'latitude': -23.51, 'longitude': -46.61}],
};
RotaModel route() => RotaModel.fromJson(routeJson());