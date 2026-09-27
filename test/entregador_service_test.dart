import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nhac_motoboy/services/api_config.dart';
import 'package:nhac_motoboy/services/api_client.dart';
import 'package:nhac_motoboy/services/entregador_service.dart';
import 'package:nhac_motoboy/models/status.dart';
import 'fixtures.dart';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async { SharedPreferences.setMockInitialValues({}); await ApiConfig.setAuthToken('token'); });
  EntregadorService service(Future<http.Response> Function(http.Request) handler) => EntregadorService(client: MockClient(handler));
  test('cadastro inclui CPF obrigatório e contrato de veículo', () async {
    final s = service((r) async {
      expect(r.url.path, '/api/v1/entregador/cadastro'); expect(r.method, 'POST');
      expect(jsonDecode(r.body)['cpf'], '52998224725');
      return http.Response(jsonEncode(profileJson('OFFLINE')), 201);
    });
    expect((await s.cadastrarEntregador(cnh: '12345678900', placaVeiculo: 'ABC1D23', tipoVeiculo: 'MOTO', cpf: '52998224725')).statusOperacional, 'OFFLINE');
  });
  for (final status in [StatusOperacional.online, StatusOperacional.offline]) {
    test('solicita ${status.api} e utiliza resposta real', () async {
      final s = service((r) async {
        expect(r.method, 'PATCH'); expect(jsonDecode(r.body)['statusOperacional'], status.api);
        return http.Response(jsonEncode(profileJson(status.api)), 200);
      });
      expect((await s.atualizarStatus(status)).statusOperacional, status.api);
    });
  }
  test('impede EM_ENTREGA manual sem request', () async {
    final s = service((_) async => throw StateError('não chamar'));
    await expectLater(s.atualizarStatus(StatusOperacional.emEntrega), throwsArgumentError);
  });
  test('localização válida usa PATCH', () async {
    final s = service((r) async {
      expect(r.url.path, '/api/v1/entregador/localizacao');
      expect(jsonDecode(r.body), {'latitude': -23.5, 'longitude': -46.6});
      return http.Response('{}', 200);
    });
    await s.enviarLocalizacao(-23.5, -46.6);
  });
  for (final coords in [[91.0, 0.0], [0.0, -181.0], [double.nan, 0.0]]) {
    test('rejeita coordenadas $coords sem rede', () async {
      final s = service((_) async => throw StateError('não chamar'));
      await expectLater(s.enviarLocalizacao(coords[0], coords[1]), throwsArgumentError);
    });
  }
  test('perfil 404 significa sem cadastro; 500 propaga erro', () async {
    expect(await service((_) async => http.Response('{}', 404)).obterPerfil(), isNull);
    await expectLater(service((_) async => http.Response('{}', 500)).obterPerfil(), throwsA(isA<ApiException>()));
  });
  test('corrida 404 limpa cache; 403 não é ausência', () async {
    expect(await service((_) async => http.Response('{}', 404)).obterEntregaAtiva(), isNull);
    await expectLater(service((_) async => http.Response('{}', 403)).obterEntregaAtiva(), throwsA(isA<ApiException>()));
    expect(ApiConfig.temSessaoSalva, true);
  });
  test('lista ofertas e preserva prazo', () async {
    final offers = await service((r) async {
      expect(r.url.path, '/api/v1/entregas/ofertas/pendentes');
      return http.Response(jsonEncode([offerJson()]), 200);
    }).buscarOfertasPendentes();
    expect(offers.single.expirada, false);
  });
  test('aceite preserva PREPARANDO', () async {
    final result = await service((r) async {
      expect(r.method, 'POST'); expect(r.url.path, '/api/v1/entregas/ofertas/o1/aceitar');
      return http.Response(jsonEncode(activeJson()), 200);
    }).aceitarOferta('o1');
    expect(result.statusPedido, StatusPedido.preparando);
  });
  test('recusa e conclusão aceitam 204', () async {
    final paths = <String>[];
    final s = service((r) async { paths.add(r.url.path); return http.Response('', 204); });
    await s.recusarOferta('o1'); await s.concluirEntrega('p1');
    expect(paths, ['/api/v1/entregas/ofertas/o1/recusar', '/api/v1/entregas/p1/concluir']);
  });
  test('coleta interpreta resposta idempotente', () async {
    final s = service((r) async {
      expect(r.url.path, '/api/v1/entregas/p1/coletar');
      return http.Response(jsonEncode(activeJson('SAIU_ENTREGA')), 200);
    });
    expect((await s.coletarPedido('p1')).statusPedido, StatusPedido.saiuEntrega);
  });
  test('rota e histórico usam contratos reais', () async {
    final s = service((r) async {
      if (r.url.path.endsWith('/rota')) return http.Response(jsonEncode(routeJson()), 200);
      expect(r.url.queryParameters['page'], '2');
      expect(r.url.queryParameters['status'], 'ENTREGUE');
      return http.Response('{"content":[],"number":2,"last":true,"totalPages":3}', 200);
    });
    expect((await s.obterRota('p1')).duracaoEstimadaMinutos, 12);
    expect((await s.buscarHistorico(status: 'ENTREGUE', page: 2)).paginaAtual, 2);
  });
  test('erro no histórico não vira lista vazia', () async {
    await expectLater(service((_) async => http.Response('{}', 500)).buscarHistorico(), throwsA(isA<ApiException>()));
  });
}