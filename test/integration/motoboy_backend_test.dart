import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nhac_motoboy/controllers/entrega_provider.dart';
import 'package:nhac_motoboy/globals/app_theme.dart';
import 'package:nhac_motoboy/models/status.dart';
import 'package:nhac_motoboy/pages/home/tabs/avaliacoes_page.dart';
import 'package:nhac_motoboy/pages/home/tabs/confirmar_entrega_page.dart';
import 'package:nhac_motoboy/services/api_client.dart';
import 'package:nhac_motoboy/services/api_config.dart';
import 'package:nhac_motoboy/services/entregador_service.dart';

import 'integration_support.dart';

const enabled = bool.fromEnvironment('RUN_INTEGRATION');

void main() {
  if (!enabled) {
    test(
      'integração com backend: executar tool/run_integration.sh',
      () {},
      skip: 'Requer backend isolado; não usa produção.',
    );
    return;
  }
  BackendIntegrationBinding();
  final base = Uri.parse(ApiConfig.baseUrl);
  if (base.scheme != 'http' || base.host != '127.0.0.1' || base.port != 18080) {
    throw StateError('A suíte deve apontar para http://127.0.0.1:18080.');
  }

  late http.Client client;
  late EntregadorService service;
  final tokens = <String, String>{};
  final locations = <String, IntegrationLocation>{};
  Future<dynamic> actor(
    String name,
    String method,
    String path, {
    Object? body,
  }) async {
    final request = http.Request(
      method,
      Uri.parse('${ApiConfig.baseUrl}$path'),
    );
    request.headers.addAll({
      'Content-Type': 'application/json',
      'X-App-Origin': name == 'lojista' ? 'lojista' : 'cliente',
      if (tokens[name] != null) 'Authorization': 'Bearer ${tokens[name]}',
    });
    if (body != null) request.body = jsonEncode(body);
    final response = await http.Response.fromStream(
      await client.send(request),
    ).timeout(const Duration(seconds: 15));
    expect(
      response.statusCode,
      inInclusiveRange(200, 299),
      reason: '$method $path: ${response.body}',
    );
    return response.body.isEmpty ? null : jsonDecode(response.body);
  }

  Future<void> login(String name) async {
    final data = await actor(
      name,
      'POST',
      '/api/v1/auth/login',
      body: {
        'email': '$name@integration.nhac.local',
        'senha': 'NhacIntegration#123',
      },
    );
    tokens[name] = data['token'] as String;
  }

  Future<EntregaProvider> driver(String name) async {
    await ApiConfig.setAuthToken(tokens[name]!);
    await service.cadastrarEntregador(
      cnh: '12345678901',
      placaVeiculo: 'ITF1A23',
      tipoVeiculo: 'MOTO',
      cpf: name == 'motoboy' ? '52998224725' : '11144477735',
    );
    final location = IntegrationLocation();
    locations[name] = location;
    final p = EntregaProvider(
      service: service,
      locationService: location,
      automatic: false,
    );
    addTearDown(p.dispose);
    await p.sincronizar();
    await p.alternarStatusOnline(true);
    expect(p.erro, isNull);
    expect(p.estaOnline, true);
    expect(p.localizacaoRecente, true);
    return p;
  }

  Future<void> accept(
    EntregaProvider p,
    String order, {
    bool remoteCollect = false,
  }) async {
    await actor('lojista', 'POST', '/api/v1/entregas/despachar/$order');
    await p.sincronizar();
    expect(p.ofertas.where((o) => o.pedidoId == order), hasLength(1));
    expect(
      await p.aceitarOferta(
        p.ofertas.singleWhere((o) => o.pedidoId == order).id,
      ),
      true,
    );
    expect(p.entregaAtiva!.statusPedido, StatusPedido.preparando);
    expect(p.podeConcluir, false);
    // A rota é carregada em paralelo ao aceite; sincronizar também aguarda os dados.
    for (var i = 0; i < 100 && p.rotaAtual == null && p.erroRota == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(p.erroRota, isNull);
    expect(p.rotaAtual!.pedidoId, order);
    expect(p.rotaAtual!.waypoints, isNotEmpty);
    expect(p.entregaAtiva!.clienteTelefone, isNotEmpty);
    final pickupRoute = p.rotaAtual;
    if (remoteCollect) {
      // A coleta foi confirmada no servidor, mas a resposta se perdeu no app.
      await service.coletarPedido(order);
      expect(p.entregaAtiva!.statusPedido, StatusPedido.preparando);
      await p.sincronizar();
      expect(identical(p.rotaAtual, pickupRoute), false);
      expect(p.rotaAtual!.destino.latitude, closeTo(-23.551000, 0.000001));
      expect(p.rotaAtual!.destino.longitude, closeTo(-46.634000, 0.000001));
    } else {
      expect(await p.confirmarColeta(), true);
    }
    expect(p.entregaAtiva!.statusPedido, StatusPedido.saiuEntrega);
  }

  Future<void> until(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 200; i++) {
      await tester.pump();
      if (done()) return;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
    }
    fail('Timeout aguardando resposta real do backend e atualização da tela.');
  }

  Future<void> submit(WidgetTester tester, String code) async {
    await tester.scrollUntilVisible(
      find.byKey(const Key('entrega-codigo')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(find.byKey(const Key('entrega-codigo')), code);
    await tester.ensureVisible(find.byKey(const Key('entrega-confirmar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('entrega-confirmar')));
    await tester.pump();
  }

  Widget app(EntregaProvider p, GoRouter router) => ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (_, _) => ChangeNotifierProvider.value(
      value: p,
      child: MaterialApp.router(theme: nhacTheme, routerConfig: router),
    ),
  );
  GoRouter router() => GoRouter(
    initialLocation: '/confirmar-entrega',
    routes: [
      GoRoute(
        path: '/confirmar-entrega',
        builder: (_, _) => const ConfirmarEntregaPage(),
      ),
      GoRoute(
        path: '/home-motoca',
        builder: (_, _) => const Scaffold(body: Text('Corrida finalizada')),
      ),
    ],
  );

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    client = http.Client();
    service = EntregadorService(client: client);
    for (final name in ['cliente', 'lojista', 'motoboy', 'bloqueio', 'outro']) {
      await login(name);
    }
    client.close();
  });
  setUp(() {
    client = http.Client();
    service = EntregadorService(client: client);
  });
  tearDown(() => client.close());

  testWidgets(
    'IT-MOTO-001 oferta → coleta → localização → código → avaliação',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      late EntregaProvider p;
      final initialized = await tester.runAsync(() async {
        p = await driver('motoboy');
        await accept(p, 'it-pedido', remoteCollect: true);
        final freshProvider = EntregaProvider(
          service: service,
          automatic: false,
        );
        try {
          await freshProvider.sincronizar();
          expect(
            freshProvider.entregaAtiva!.pedidoId,
            'it-pedido',
            reason: 'A entrega deve ser recuperável após recriar o provider.',
          );
        } finally {
          freshProvider.dispose();
        }
        locations['motoboy']!
          ..latitude = -23.551000
          ..longitude = -46.634000;
        expect(await p.atualizarLocalizacao(), true);
        final location = await actor(
          'cliente',
          'GET',
          '/api/v1/entregas/it-pedido/localizacao-entregador',
        );
        expect(location['latitude'], closeTo(-23.551000, 0.000001));
        expect(
          DateTime.parse(
            location['atualizadaEm'],
          ).difference(DateTime.now()).abs().inSeconds,
          lessThan(30),
        );
        final order = await actor(
          'cliente',
          'GET',
          '/api/v1/pedidos/it-pedido',
        );
        expect(order['status'], 'SAIU_ENTREGA');
        expect(order['codigoEntrega'], '0123');
        return true;
      });
      if (initialized != true) return;
      final navigation = router();
      addTearDown(() {
        navigation.dispose();
      });
      await tester.pumpWidget(app(p, navigation));
      await tester.pumpAndSettle();
      await submit(tester, '9999');
      await until(
        tester,
        () => p.erroConclusao != null && !p.isLoading && !p.isSyncing,
      );
      expect(find.textContaining('Tentativas restantes: 4'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('entrega-codigo')))
            .controller!
            .text,
        isEmpty,
      );
      expect(p.entregaAtiva, isNotNull);
      await submit(tester, '0123');
      await until(
        tester,
        () => find.text('Corrida finalizada').evaluate().isNotEmpty,
      );
      expect(p.entregaAtiva, isNull);
      expect(p.estaOnline, true);
      await tester.runAsync(() async {
        expect(await service.obterEntregaAtiva(), isNull);
        expect((await service.obterPerfil())!.statusOperacional, 'ONLINE');
        expect(
          (await actor(
            'cliente',
            'GET',
            '/api/v1/pedidos/it-pedido',
          ))['status'],
          'ENTREGUE',
        );
        // Repetir a conclusão não cria outra entrega no histórico.
        await service.concluirEntrega('it-pedido', codigo: '0123');
        final history = await service.buscarHistorico(status: 'ENTREGUE');
        expect(
          history.itens.where((e) => e.pedidoId == 'it-pedido'),
          hasLength(1),
        );
        expect(history.itens.single.entregueEm, isNotNull);
        expect(history.itens.single.enderecoEntrega, isNotNull);
        final estado = await service.obterEstado();
        expect(estado.entrega, isNull);
        expect(estado.perfil!.statusOperacional, 'ONLINE');
        await actor(
          'cliente',
          'POST',
          '/api/v1/pedidos/it-pedido/avaliacao-entregador',
          body: {'nota': 5, 'comentario': 'Entrega de integração confirmada.'},
        );
        final reviews = await service.buscarAvaliacoes(size: 1);
        expect(reviews.media, 5);
        expect(reviews.total, 1);
        expect(reviews.itens.single.pedidoId, 'it-pedido');
        expect(
          (await service.buscarAvaliacoes(page: 1, size: 1)).itens,
          isEmpty,
        );
      });
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, _) => MaterialApp(
            theme: nhacTheme,
            home: AvaliacoesPage(service: service),
          ),
        ),
      );
      await until(
        tester,
        () => find
            .text('Entrega de integração confirmada.')
            .evaluate()
            .isNotEmpty,
      );
      expect(find.text('Integração'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        await p.sair();
        expect(ApiConfig.authToken, isNull);
        expect(
          (await actor(
            'motoboy',
            'GET',
            '/api/v1/entregador/perfil',
          ))['statusOperacional'],
          'OFFLINE',
        );
      });
      client.close();
    },
  );

  testWidgets(
    'IT-MOTO-002 cinco códigos errados persistem e bloqueiam nova tentativa',
    (tester) async {
      late EntregaProvider p;
      final initialized = await tester.runAsync(() async {
        p = await driver('bloqueio');
        await accept(p, 'it-bloqueio');
        for (var attempt = 1; attempt <= 4; attempt++) {
          expect(await p.concluirEntregaAtual(codigo: '9999'), false);
          expect(p.erroConclusao!.code, 'CODIGO_ENTREGA_INVALIDO');
          expect(
            (p.erroConclusao!.details as Map)['tentativasRestantes'],
            5 - attempt,
            reason:
                'O contador deve sobreviver ao rollback da requisição inválida.',
          );
        }
        return true;
      });
      if (initialized != true) return;
      final navigation = router();
      addTearDown(() {
        navigation.dispose();
      });
      await tester.pumpWidget(app(p, navigation));
      await tester.pumpAndSettle();
      await submit(tester, '9999');
      await until(
        tester,
        () =>
            p.erroConclusao?.code == 'CODIGO_ENTREGA_BLOQUEADO' &&
            !p.isLoading &&
            !p.isSyncing,
      );
      expect(find.textContaining('Tentativas bloqueadas'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('entrega-codigo')))
            .enabled,
        false,
      );
      final untilServer = DateTime.parse(
        (p.erroConclusao!.details as Map)['tentativaLiberadaEm'],
      );
      expect(untilServer.isAfter(DateTime.now()), true);
      await tester.runAsync(() async {
        await expectLater(
          service.concluirEntrega('it-bloqueio', codigo: '0123'),
          throwsA(isA<ApiException>().having((e) => e.status, 'status', 429)),
        );
        expect(
          (await service.obterEntregaAtiva())!.statusPedido,
          StatusPedido.saiuEntrega,
        );
        expect((await service.obterPerfil())!.statusOperacional, 'EM_ENTREGA');
      });
      client.close();
      await tester.pumpWidget(const SizedBox());
    },
  );

  test(
    'IT-MOTO-003 cliente sem vínculo não acessa entregas ou localização alheia',
    () async {
      await ApiConfig.setAuthToken(tokens['outro']!);
      await expectLater(
        service.buscarOfertasPendentes(),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 403)),
      );
      await expectLater(
        service.obterRota('it-bloqueio'),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 403)),
      );
    },
  );
}
