import 'package:http/http.dart' as http;
import '../models/entregador_cadastro_model.dart';
import '../models/entrega_ativa_model.dart';
import '../models/oferta_entrega_model.dart';
import '../models/rota_model.dart';
import '../models/ganhos_entregador_model.dart';
import '../models/historico_entrega_model.dart';
import '../models/status.dart';
import 'api_client.dart';

/// Repositório HTTP do domínio de entregas. Ausência (404) e erro são distintos.
class EntregadorService {
  final ApiClient api;
  EntregadorService({http.Client? client, ApiClient? api}) : api = api ?? ApiClient(client: client);
  Future<EntregadorCadastroModel> cadastrarEntregador({
    required String cnh, required String placaVeiculo, required String tipoVeiculo,
    required String cpf, String? corVeiculo, String? modeloVeiculo,
  }) async => EntregadorCadastroModel.fromJson(await api.request('POST',
    '/api/v1/entregador/cadastro', body: {'cnh': cnh, 'placaVeiculo': placaVeiculo,
      'tipoVeiculo': tipoVeiculo, 'cpf': cpf,
      'corVeiculo': ?corVeiculo,
      'modeloVeiculo': ?modeloVeiculo}));
  Future<EntregadorCadastroModel?> obterPerfil() async {
    final data = await api.request('GET', '/api/v1/entregador/perfil', emptyStatuses: {404});
    return data == null ? null : EntregadorCadastroModel.fromJson(data);
  }
  Future<EntregadorCadastroModel> atualizarVeiculo({required String tipoVeiculo,
    required String placaVeiculo, String? modeloVeiculo, String? corVeiculo}) async =>
      EntregadorCadastroModel.fromJson(await api.request('PATCH', '/api/v1/entregador/veiculo',
        body: {'tipoVeiculo': tipoVeiculo, 'placaVeiculo': placaVeiculo,
          'modeloVeiculo': modeloVeiculo, 'corVeiculo': corVeiculo}));
  Future<EntregadorCadastroModel> atualizarDocumentos({required String cpf, required String cnh}) async =>
      EntregadorCadastroModel.fromJson(await api.request('PATCH', '/api/v1/entregador/documentos',
        body: {'cpf': cpf, 'cnh': cnh}));
  Future<EntregadorCadastroModel> atualizarDadosBancarios({required String tipoChavePix,
    required String chavePix}) async =>
      EntregadorCadastroModel.fromJson(await api.request('PATCH', '/api/v1/entregador/dados-bancarios',
        body: {'tipoChavePix': tipoChavePix, 'chavePix': chavePix}));
  Future<EntregadorCadastroModel> atualizarStatus(StatusOperacional status) async {
    if (status != StatusOperacional.online && status != StatusOperacional.offline) {
      throw ArgumentError('O status é controlado pelo backend.');
    }
    return EntregadorCadastroModel.fromJson(await api.request('PATCH',
      '/api/v1/entregador/status', body: {'statusOperacional': status.api}));
  }
  Future<void> enviarLocalizacao(double latitude, double longitude) async {
    if (!latitude.isFinite || !longitude.isFinite || latitude.abs() > 90 || longitude.abs() > 180) {
      throw ArgumentError('Localização inválida.');
    }
    await api.request('PATCH', '/api/v1/entregador/localizacao',
      body: {'latitude': latitude, 'longitude': longitude});
  }
  Future<List<OfertaEntregaModel>> buscarOfertasPendentes() async =>
    ((await api.request('GET', '/api/v1/entregas/ofertas/pendentes')) as List)
      .map((e) => OfertaEntregaModel.fromJson(e)).toList();
  Future<EntregaAtivaModel> aceitarOferta(String id) async => EntregaAtivaModel.fromJson(
    await api.request('POST', '/api/v1/entregas/ofertas/${Uri.encodeComponent(id)}/aceitar'));
  Future<void> recusarOferta(String id) async {
    await api.request('POST', '/api/v1/entregas/ofertas/${Uri.encodeComponent(id)}/recusar');
  }
  Future<EntregaAtivaModel?> obterEntregaAtiva() async {
    final data = await api.request('GET', '/api/v1/entregas/ativa', emptyStatuses: {404});
    return data == null ? null : EntregaAtivaModel.fromJson(data);
  }
  Future<RotaModel> obterRota(String id) async => RotaModel.fromJson(
    await api.request('GET', '/api/v1/entregas/${Uri.encodeComponent(id)}/rota'));
  Future<EntregaAtivaModel> coletarPedido(String id) async => EntregaAtivaModel.fromJson(
    await api.request('POST', '/api/v1/entregas/${Uri.encodeComponent(id)}/coletar'));
  Future<void> concluirEntrega(String id) async {
    await api.request('POST', '/api/v1/entregas/${Uri.encodeComponent(id)}/concluir');
  }
  Future<HistoricoEntregasPagina> buscarHistorico({String? status, int page = 0, int size = 20}) async =>
    HistoricoEntregasPagina.fromJson(await api.request('GET', '/api/v1/entregador/entregas',
      query: {'page': '$page', 'size': '$size', 'status': ?status}));
  Future<GanhosEntregadorModel?> buscarGanhos({String periodo = 'HOJE'}) async {
    try {
      return GanhosEntregadorModel.fromJson(await api.request('GET',
        '/api/v1/entregador/ganhos', query: {'periodo': periodo}));
    } on ApiException catch (e) {
      if (e.status == 404) throw EntregadorNaoCadastradoException();
      rethrow;
    }
  }
}
class EntregadorNaoCadastradoException implements Exception {
  @override
  String toString() => 'Complete seu cadastro de entregador.';
}
