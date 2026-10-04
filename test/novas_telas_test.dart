import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nhac_motoboy/controllers/entrega_provider.dart';
import 'package:nhac_motoboy/models/avaliacoes_entregador_model.dart';
import 'package:nhac_motoboy/pages/home/tabs/avaliacoes_page.dart';
import 'package:nhac_motoboy/pages/home/tabs/confirmar_entrega_page.dart';
import 'package:nhac_motoboy/services/api_client.dart';
import 'package:nhac_motoboy/services/api_config.dart';
import 'package:nhac_motoboy/services/entregador_service.dart';

import 'entrega_provider_test.dart' show FakeEntregaService;
import 'fixtures.dart';

import 'package:nhac_motoboy/globals/app_theme.dart';

class ReviewsService extends EntregadorService {
  int calls = 0;
  bool fail = false, empty = false;
  @override
  Future<AvaliacoesEntregadorPagina> buscarAvaliacoes({
    int page = 0,
    int size = 20,
    bool force = false,
  }) async {
    calls++;
    if (fail) throw const ApiException(503, 'Servidor indisponível.');
    return AvaliacoesEntregadorPagina(
      media: empty ? 0 : 5,
      total: empty ? 0 : 2,
      paginaAtual: page,
      ultima: empty || page == 1,
      itens: empty
          ? []
          : [
              AvaliacaoEntregadorModel(
                pedidoId: 'p$page',
                clienteNome: 'Cliente $page',
                nota: 5,
                comentario: 'Entrega cuidadosa.',
              ),
            ],
    );
  }
}

Widget app(Widget page, {EntregaProvider? provider}) => ScreenUtilInit(
  designSize: const Size(390, 844),
  minTextAdapt: true,
  builder: (_, _) => provider == null
      ? MaterialApp(theme: nhacTheme, home: page)
      : ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp(theme: nhacTheme, home: page),
        ),
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final loader = FontLoader('Roboto')
      ..addFont(rootBundle.load('assets/fonts/Roboto.ttf'));
    await loader.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiConfig.setAuthToken('token');
  });
  testWidgets('avaliações pagina, mantém dados no erro e permite recuperar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final service = ReviewsService();
    await tester.pumpWidget(app(AvaliacoesPage(service: service)));
    await tester.pumpAndSettle();
    expect(find.text('Cliente 0'), findsOneWidget);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/avaliacoes.png'),
    );
    service.fail = true;
    await tester.scrollUntilVisible(find.text('Carregar mais'), 200);
    await tester.tap(find.text('Carregar mais'));
    await tester.pumpAndSettle();
    expect(find.text('Cliente 0'), findsOneWidget);
    expect(find.text('Servidor indisponível.'), findsOneWidget);
    service.fail = false;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Cliente 1'), findsOneWidget);
    expect(find.text('Carregar mais'), findsNothing);
    expect(service.calls, 3);
  });
  testWidgets('avaliações vazias não inventam nota', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      app(AvaliacoesPage(service: ReviewsService()..empty = true)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sem nota ainda'), findsOneWidget);
    expect(find.text('Carregar mais'), findsNothing);
  });
  testWidgets('confirmação valida formato e mostra tentativas restantes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final service = FakeEntregaService();
    service.current = active('SAIU_ENTREGA');
    service.operational = 'EM_ENTREGA';
    service.finishError = const ApiException(
      400,
      'Código inválido.',
      code: 'CODIGO_ENTREGA_INVALIDO',
      details: {'tentativasRestantes': 4},
    );
    final provider = EntregaProvider(service: service, automatic: false);
    await provider.sincronizar();
    await tester.pumpWidget(
      app(const ConfirmarEntregaPage(), provider: provider),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/confirmar_entrega.png'),
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('entrega-confirmar')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.byKey(const Key('entrega-confirmar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('entrega-confirmar')));
    await tester.pump();
    expect(find.text('Informe os quatro números.'), findsOneWidget);
    expect(service.finishCalls, 0);
    await tester.enterText(find.byKey(const Key('entrega-codigo')), '0123');
    await tester.ensureVisible(find.byKey(const Key('entrega-confirmar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('entrega-confirmar')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Tentativas restantes: 4'), findsOneWidget);
    expect(service.finishCalls, 1);
    expect(provider.entregaAtiva, isNotNull);
    await tester.pumpWidget(const SizedBox());
    provider.dispose();
  });
  testWidgets(
    'bloqueio impede repetir requisição e desaparece no horário do servidor',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final service = FakeEntregaService();
      service.current = active('SAIU_ENTREGA');
      service.operational = 'EM_ENTREGA';
      service.finishError = ApiException(
        429,
        'Bloqueado.',
        code: 'CODIGO_ENTREGA_BLOQUEADO',
        details: {
          'tentativaLiberadaEm': DateTime.now()
              .add(const Duration(minutes: 10))
              .toUtc()
              .toIso8601String(),
        },
      );
      final provider = EntregaProvider(service: service, automatic: false);
      await provider.sincronizar();
      await tester.pumpWidget(
        app(const ConfirmarEntregaPage(), provider: provider),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('entrega-codigo')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(find.byKey(const Key('entrega-codigo')), '0123');
      await tester.scrollUntilVisible(
        find.byKey(const Key('entrega-confirmar')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.byKey(const Key('entrega-confirmar')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('entrega-confirmar')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Tentativas bloqueadas'), findsOneWidget);
      expect(service.finishCalls, 1);
      final field = tester.widget<TextFormField>(
        find.byKey(const Key('entrega-codigo')),
      );
      expect(field.enabled, false);
      await tester.pump(const Duration(minutes: 10));
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('entrega-codigo')))
            .enabled,
        true,
      );
      await tester.pumpWidget(const SizedBox());
      provider.dispose();
    },
  );
  testWidgets(
    'confirmação permanece operável com largura 320 e texto ampliado',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      final service = FakeEntregaService()
        ..current = active('SAIU_ENTREGA')
        ..operational = 'EM_ENTREGA';
      final provider = EntregaProvider(service: service, automatic: false);
      await provider.sincronizar();
      await tester.pumpWidget(
        app(const ConfirmarEntregaPage(), provider: provider),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('entrega-confirmar')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.byKey(const Key('entrega-confirmar')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('entrega-confirmar')));
      await tester.pumpAndSettle();
      expect(
        service.finishCalls,
        0,
      ); // validação funciona sem enviar código vazio.
      await tester.pumpWidget(const SizedBox());
      provider.dispose();
    },
  );
}
