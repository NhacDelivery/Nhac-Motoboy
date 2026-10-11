import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:nhac_motoboy/controllers/entrega_provider.dart';
import 'package:nhac_motoboy/controllers/user_provider.dart';
import 'package:nhac_motoboy/globals/app_theme.dart';
import 'package:nhac_motoboy/services/api_client.dart';
import 'package:nhac_motoboy/services/api_config.dart';
import 'package:nhac_motoboy/services/auth_service.dart';
import 'package:nhac_motoboy/services/entregador_service.dart';
import 'package:nhac_motoboy/services/location_service.dart';
import 'package:nhac_motoboy/services/user_service.dart';

// Flutter normalmente devolve HTTP 400 em testWidgets. Este binding permite
// tráfego real exclusivamente nesta suíte opt-in, com destino loopback.
class BackendIntegrationBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

// A fronteira com o hardware é controlada; provider, HTTP, JWT, regras,
// transações, repositórios e telas são os componentes reais.
class IntegrationLocation extends LocationService {
  double latitude = -23.550520, longitude = -46.633308;
  @override
  Future<String?> solicitarPermissao({bool request = true}) async => null;
  @override
  Future<Position?> obterPosicaoAtual({bool emEntrega = false}) async =>
      Position(
        latitude: latitude,
        longitude: longitude,
        timestamp: DateTime.now(),
        accuracy: 5,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
}

const integrationEnabled = bool.fromEnvironment('RUN_INTEGRATION');
const integrationPassword = 'NhacIntegration#123';
void requireLoopback() {
  final uri = Uri.parse(ApiConfig.baseUrl);
  if (uri.scheme != 'http' || uri.host != '127.0.0.1' || uri.port != 18080) {
    throw StateError(
      'A suíte exige backend H2 isolado em http://127.0.0.1:18080.',
    );
  }
}

class IntegrationScenario {
  final String id;
  final http.Client client = http.Client();
  final tokens = <String, String>{};
  late Map<String, dynamic> data;
  late final api = ApiClient(client: client);
  late final service = EntregadorService(client: client);
  late final auth = AuthService(client: client);
  late final users = UserService(api: api);
  final providers = <EntregaProvider>[];
  final userProviders = <UserProvider>[];
  IntegrationScenario(this.id);
  String actorId([String actor = 'a']) => data[actor]['id'] as String;
  String email([String actor = 'a']) => data[actor]['email'] as String;
  String cpf([String actor = 'a']) => data[actor]['cpf'] as String;
  String phone([String actor = 'a']) => data[actor]['telefone'] as String;
  String get order => data['pedidoId'] as String;
  String get secondOrder => data['segundoPedidoId'] as String;
  String get shop => data['lojaId'] as String;

  Future<dynamic> request(
    String actor,
    String method,
    String path, {
    Object? body,
    int? status,
    String? token,
    String? origin,
  }) async {
    final req = http.Request(method, Uri.parse('${ApiConfig.baseUrl}$path'));
    req.headers.addAll({
      'Content-Type': 'application/json',
      'X-App-Origin': origin ?? (actor == 'lojista' ? 'lojista' : 'motoboy'),
      if (token != null || tokens[actor] != null)
        'Authorization': 'Bearer ${token ?? tokens[actor]}',
    });
    if (body != null) req.body = jsonEncode(body);
    final response = await http.Response.fromStream(
      await client.send(req),
    ).timeout(const Duration(seconds: 15));
    expect(
      response.statusCode,
      status ?? inInclusiveRange(200, 299),
      reason: '$id: $actor $method $path: ${response.body}',
    );
    return response.body.isEmpty ? null : jsonDecode(response.body);
  }

  Future<void> init() async {
    requireLoopback();
    await ApiConfig.limparSessao();
    tokens['admin'] = (await request(
      'admin',
      'POST',
      '/api/v1/auth/login',
      body: {
        'email': 'integracao-admin@integration.nhac.local',
        'senha': integrationPassword,
      },
    ))['token'];
    data = Map<String, dynamic>.from(await control('/cenarios/$id'));
    for (final actor in ['a', 'b', 'cliente']) {
      tokens[actor] = (await request(
        actor,
        'POST',
        '/api/v1/auth/login',
        body: {'email': email(actor), 'senha': integrationPassword},
      ))['token'];
    }
    tokens['lojista'] = (await request(
      'lojista',
      'POST',
      '/api/v1/auth/login',
      body: {'email': email('lojista'), 'senha': integrationPassword},
    ))['token'];
    await use('a');
  }

  Future<void> use(String actor) => ApiConfig.setAuthToken(tokens[actor]!);
  Future<dynamic> control(String path, {String method = 'POST'}) =>
      request('admin', method, '/api/v1/suporte/motoboy-it$path');
  Future<String> code({String? email, String? phone}) async => (await control(
    '/codigo?${email != null ? 'email=${Uri.encodeQueryComponent(email)}' : 'telefone=${Uri.encodeQueryComponent(phone!)}'}',
    method: 'GET',
  ))['codigo'];
  Future<EntregaProvider> driver({
    String actor = 'a',
    bool online = true,
    String vehicle = 'MOTO',
  }) async {
    await use(actor);
    await service.cadastrarEntregador(
      cnh: vehicle == 'BICICLETA' ? '' : '12345678901',
      placaVeiculo: vehicle == 'BICICLETA' ? '' : 'ABC1D23',
      tipoVeiculo: vehicle,
      cpf: cpf(actor),
    );
    final p = EntregaProvider(
      service: service,
      locationService: IntegrationLocation(),
      automatic: false,
    );
    providers.add(p);
    await p.sincronizar();
    if (online) {
      await p.alternarStatusOnline(true);
      expect(p.erro, isNull);
      expect(p.estaOnline, true);
    }
    return p;
  }

  Future<void> dispatch([String? pedido]) async => request(
    'lojista',
    'POST',
    '/api/v1/entregas/despachar/${pedido ?? order}',
  );
  Future<void> accept(EntregaProvider p, {bool collect = false}) async {
    await dispatch();
    await p.sincronizar();
    final offer = p.ofertas.singleWhere((o) => o.pedidoId == order);
    expect(await p.aceitarOferta(offer.id), true, reason: p.erro);
    if (collect) expect(await p.confirmarColeta(), true, reason: p.erro);
  }

  Future<UserProvider> profile() async {
    final p = UserProvider(service: users);
    userProviders.add(p);
    await p.carregarDadosReais();
    expect(p.erro, isNull);
    return p;
  }

  Future<void> close() async {
    for (final p in providers) {
      p.dispose();
    }
    for (final p in userProviders) {
      p.dispose();
    }
    try {
      await control('/cenarios/$id/encerrar');
    } finally {
      await ApiConfig.limparSessao();
      EntregadorService.invalidarConsultas();
      client.close();
    }
  }
}

Widget integrationApp(
  IntegrationScenario h,
  Widget page, {
  EntregaProvider? delivery,
  UserProvider? user,
}) => ScreenUtilInit(
  designSize: const Size(390, 844),
  builder: (_, _) => MultiProvider(
    providers: [
      Provider<IntegrationScenario>.value(value: h),
      if (delivery != null) ChangeNotifierProvider.value(value: delivery),
      if (user != null) ChangeNotifierProvider.value(value: user),
    ],
    child: MaterialApp(theme: nhacTheme, home: page),
  ),
);

Future<void> waitForUi(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 400; i++) {
    await tester.pump();
    if (ready()) {
      expect(tester.takeException(), isNull);
      return;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
  }
  fail(
    'Timeout de UI. Textos: ${tester.allWidgets.whereType<Text>().map((w) => w.data ?? w.textSpan?.toPlainText()).toList()}',
  );
}
