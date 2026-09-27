import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nhac_motoboy/services/api_config.dart';
import 'package:nhac_motoboy/services/api_client.dart';
import 'package:nhac_motoboy/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiConfig.setAuthToken('token');
  });
  test('401 autenticado limpa sessão', () async {
    final api = ApiClient(client: MockClient((_) async => http.Response('{"message":"Expirou"}', 401)));
    await expectLater(api.request('GET', '/perfil'), throwsA(isA<ApiException>()));
    expect(ApiConfig.authToken, isNull);
  });
  test('403 preserva sessão e código estruturado', () async {
    final api = ApiClient(client: MockClient((_) async => http.Response('{"error":"ACESSO_NEGADO","message":"Sem acesso","details":["x"]}', 403)));
    await expectLater(api.request('GET', '/perfil'), throwsA(isA<ApiException>()
      .having((e) => e.code, 'code', 'ACESSO_NEGADO').having((e) => e.details, 'details', ['x'])));
    expect(ApiConfig.authToken, 'token');
  });
  test('falha de login não invalida outra sessão', () async {
    final auth = AuthService(client: MockClient((request) async {
      expect(request.headers.containsKey('Authorization'), false);
      return http.Response('{"message":"Senha incorreta"}', 401);
    }));
    await expectLater(auth.login('m@example.com', 'bad'), throwsA(isA<ApiException>()));
    expect(ApiConfig.authToken, 'token');
  });
  test('erro HTTP não JSON tem mensagem legível', () async {
    final api = ApiClient(client: MockClient((_) async => http.Response('<html>bad gateway</html>', 502)));
    await expectLater(api.request('GET', '/perfil'), throwsA(isA<ApiException>().having((e) => e.status, 'status', 502)));
  });
  test('resposta de sessão antiga não altera sessão nova', () async {
    final api = ApiClient(client: MockClient((_) async {
      await ApiConfig.setAuthToken('new'); return http.Response('{}', 401);
    }));
    await expectLater(api.request('GET', '/perfil'), throwsA(isA<ApiException>()));
    expect(ApiConfig.authToken, 'new');
  });
  test('header de origem e bearer acompanham requests autenticados', () async {
    final api = ApiClient(client: MockClient((request) async {
      expect(request.headers['Authorization'], 'Bearer token');
      expect(request.headers['X-App-Origin'], 'motoboy');
      expect(jsonDecode(request.body), {'x': 1});
      return http.Response('', 204);
    }));
    expect(await api.request('PATCH', '/localizacao', body: {'x': 1}), isNull);
  });
  test('checar email usa existe', () async {
    final auth = AuthService(client: MockClient((_) async => http.Response('{"existe":true}', 200)));
    expect(await auth.checarEmail('m@example.com'), true);
  });
}