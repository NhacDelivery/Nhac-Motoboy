import '../models/estado_entregador_model.dart';
import 'session_query_cache.dart';
import 'api_config.dart';
import 'package:http/http.dart' as http;

import '../models/entregador_cadastro_model.dart';
import '../models/entrega_ativa_model.dart';
import '../models/oferta_entrega_model.dart';
import '../models/rota_model.dart';
import '../models/ganhos_entregador_model.dart';
import '../models/historico_entrega_model.dart';
import '../models/status.dart';
import 'api_client.dart';
import '../models/avaliacoes_entregador_model.dart';

/// Repositório HTTP do domínio de entregas. Ausência (404) e erro são distintos.
class EntregadorService {
  final ApiClient api;
  EntregadorService({http.Client? client, ApiClient? api})
    : api = api ?? ApiClient(client: client);
  DateTime? _tentarEstadoDepois;
  static void invalidarConsultas() => SessionQueryCache.shared.clear();

  Future<EstadoEntregadorModel> obterEstado() async {
    if (_tentarEstadoDepois == null ||
        DateTime.now().isAfter(_tentarEstadoDepois!)) {
      try {
        return EstadoEntregadorModel.fromJson(
          await api.request('GET', '/api/v1/entregador/estado'),
        );
      } on ApiException catch (e) {
        if (e.status != 404) rethrow;
        // Compatibilidade enquanto o backend novo ainda não foi implantado.
        _tentarEstadoDepois = DateTime.now().add(const Duration(minutes: 5));
      }
    }
    final profile = await obterPerfil();
    if (profile?.ativo != true) return EstadoEntregadorModel(perfil: profile);
    final active = await obterEntregaAtiva();
    final offers = active == null && profile!.statusOperacional == 'ONLINE'
        ? await buscarOfertasPendentes()
        : <OfertaEntregaModel>[];
    return EstadoEntregadorModel(
      perfil: profile,
      entrega: active,
      ofertas: offers,
    );
  }

  String _key(String resource) => '${ApiConfig.baseUrl}:$resource';
  // O recorte de fretes da API usa America/Sao_Paulo (UTC-3 atualmente).
  String get _diaFrete => DateTime.now()
      .toUtc()
      .subtract(const Duration(hours: 3))
      .toIso8601String()
      .substring(0, 10);

  Future<EntregadorCadastroModel> cadastrarEntregador({
    required String cnh,
    required String placaVeiculo,
    required String tipoVeiculo,
    required String cpf,
    String? corVeiculo,
    String? modeloVeiculo,
  }) async => EntregadorCadastroModel.fromJson(
    await api.request(
      'POST',
      '/api/v1/entregador/cadastro',
      body: {
        'cnh': cnh,
        'placaVeiculo': placaVeiculo,
        'tipoVeiculo': tipoVeiculo,
        'cpf': cpf,
        'corVeiculo': ?corVeiculo,
        'modeloVeiculo': ?modeloVeiculo,
      },
    ),
  );
  Future<EntregadorCadastroModel?> obterPerfil() async {
    final data = await api.request(
      'GET',
      '/api/v1/entregador/perfil',
      emptyStatuses: {404},
    );
    return data == null ? null : EntregadorCadastroModel.fromJson(data);
  }

  Future<EntregadorCadastroModel> atualizarVeiculo({
    required String tipoVeiculo,
    required String placaVeiculo,
    String? modeloVeiculo,
    String? corVeiculo,
  }) async => EntregadorCadastroModel.fromJson(
    await api.request(
      'PATCH',
      '/api/v1/entregador/veiculo',
      body: {
        'tipoVeiculo': tipoVeiculo,
        'placaVeiculo': placaVeiculo,
        'modeloVeiculo': modeloVeiculo,
        'corVeiculo': corVeiculo,
      },
    ),
  );
  Future<EntregadorCadastroModel> atualizarDocumentos({
    required String cpf,
    required String cnh,
  }) async => EntregadorCadastroModel.fromJson(
    await api.request(
      'PATCH',
      '/api/v1/entregador/documentos',
      body: {'cpf': cpf, 'cnh': cnh},
    ),
  );
  Future<EntregadorCadastroModel> atualizarDadosBancarios({
    required String tipoChavePix,
    required String chavePix,
  }) async => EntregadorCadastroModel.fromJson(
    await api.request(
      'PATCH',
      '/api/v1/entregador/dados-bancarios',
      body: {'tipoChavePix': tipoChavePix, 'chavePix': chavePix},
    ),
  );
  Future<EntregadorCadastroModel> atualizarStatus(
    StatusOperacional status,
  ) async {
    if (status != StatusOperacional.online &&
        status != StatusOperacional.offline) {
      throw ArgumentError('O status é controlado pelo backend.');
    }
    return EntregadorCadastroModel.fromJson(
      await api.request(
        'PATCH',
        '/api/v1/entregador/status',
        body: {'statusOperacional': status.api},
      ),
    );
  }

  Future<void> enviarLocalizacao(double latitude, double longitude) async {
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude.abs() > 90 ||
        longitude.abs() > 180) {
      throw ArgumentError('Localização inválida.');
    }
    await api.request(
      'PATCH',
      '/api/v1/entregador/localizacao',
      body: {'latitude': latitude, 'longitude': longitude},
    );
  }

  Future<List<OfertaEntregaModel>> buscarOfertasPendentes() async =>
      ((await api.request('GET', '/api/v1/entregas/ofertas/pendentes')) as List)
          .map((e) => OfertaEntregaModel.fromJson(e))
          .toList();
  Future<EntregaAtivaModel> aceitarOferta(String id) async =>
      EntregaAtivaModel.fromJson(
        await api.request(
          'POST',
          '/api/v1/entregas/ofertas/${Uri.encodeComponent(id)}/aceitar',
        ),
      );
  Future<void> recusarOferta(String id) async {
    await api.request(
      'POST',
      '/api/v1/entregas/ofertas/${Uri.encodeComponent(id)}/recusar',
    );
  }

  Future<EntregaAtivaModel?> obterEntregaAtiva() async {
    final data = await api.request(
      'GET',
      '/api/v1/entregas/ativa',
      emptyStatuses: {404},
    );
    return data == null ? null : EntregaAtivaModel.fromJson(data);
  }

  Future<RotaModel> obterRota(String id) async => RotaModel.fromJson(
    await api.request(
      'GET',
      '/api/v1/entregas/${Uri.encodeComponent(id)}/rota',
    ),
  );
  Future<EntregaAtivaModel> coletarPedido(String id) async =>
      EntregaAtivaModel.fromJson(
        await api.request(
          'POST',
          '/api/v1/entregas/${Uri.encodeComponent(id)}/coletar',
        ),
      );
  Future<void> concluirEntrega(String id, {required String codigo}) async {
    if (!RegExp(r'^\d{4}$').hasMatch(codigo.trim())) {
      throw ArgumentError('Informe os quatro números do código de entrega.');
    }
    await api.request(
      'POST',
      '/api/v1/entregas/${Uri.encodeComponent(id)}/concluir',
      body: {'codigo': codigo.trim()},
    );
  }

  Future<AvaliacoesEntregadorPagina> buscarAvaliacoes({
    int page = 0,
    int size = 20,
    bool force = false,
  }) => SessionQueryCache.shared.load(
    _key('avaliacoes:$page:$size'),
    const Duration(minutes: 1),
    () async => AvaliacoesEntregadorPagina.fromJson(
      await api.request(
        'GET',
        '/api/v1/entregador/avaliacoes',
        query: {'page': '$page', 'size': '$size', 'sort': 'criadoEm,desc'},
      ),
    ),
    force: force,
  );
  Future<HistoricoEntregasPagina> buscarHistorico({
    String? status,
    int page = 0,
    int size = 20,
    bool force = false,
  }) => SessionQueryCache.shared.load(
    _key('historico:$status:$page:$size'),
    const Duration(seconds: 45),
    () async => HistoricoEntregasPagina.fromJson(
      await api.request(
        'GET',
        '/api/v1/entregador/entregas',
        query: {'page': '$page', 'size': '$size', 'status': ?status},
      ),
    ),
    force: force,
  );
  Future<GanhosEntregadorModel?> buscarGanhos({
    String periodo = 'HOJE',
    bool force = false,
  }) async {
    try {
      return await SessionQueryCache.shared.load(
        _key('frete:$_diaFrete:$periodo'),
        const Duration(seconds: 45),
        () async => GanhosEntregadorModel.fromJson(
          await api.request(
            'GET',
            '/api/v1/entregador/ganhos',
            query: {'periodo': periodo},
          ),
        ),
        force: force,
      );
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
