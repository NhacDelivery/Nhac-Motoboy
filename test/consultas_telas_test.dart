import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nhac_motoboy/controllers/entrega_provider.dart';
import 'package:nhac_motoboy/globals/app_theme.dart';
import 'package:nhac_motoboy/models/ganhos_entregador_model.dart';
import 'package:nhac_motoboy/models/historico_entrega_model.dart';
import 'package:nhac_motoboy/pages/home/tabs/ganhos_tab.dart';
import 'package:nhac_motoboy/pages/home/tabs/pedidos_tab.dart';
import 'package:nhac_motoboy/services/api_config.dart';
import 'package:nhac_motoboy/services/entregador_service.dart';

import 'entrega_provider_test.dart' show FakeEntregaService;

class _Queries extends EntregadorService {
  bool fail = false;
  String? filtro;
  @override
  Future<GanhosEntregadorModel?> buscarGanhos({
    String periodo = 'HOJE',
    bool force = false,
  }) async {
    if (fail) throw StateError('Conexão indisponível');
    return GanhosEntregadorModel.fromJson({
      'periodo': periodo,
      'totalGanhos': 12.5,
      'totalEntregas': 1,
      'ticketMedio': 12.5,
      'porDia': [
        {'data': '2026-10-04', 'valor': 12.5, 'entregas': 1},
      ],
    });
  }

  @override
  Future<HistoricoEntregasPagina> buscarHistorico({
    String? status,
    int page = 0,
    int size = 20,
    bool force = false,
  }) async {
    filtro = status;
    return HistoricoEntregasPagina.fromJson({
      'content': [],
      'number': 0,
      'last': true,
    });
  }
}

Widget app(Widget child, EntregaProvider provider) =>
    ChangeNotifierProvider.value(
      value: provider,
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => MaterialApp(
          theme: nhacTheme,
          home: Scaffold(body: child),
        ),
      ),
    );
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = FontLoader('Roboto')
      ..addFont(rootBundle.load('assets/fonts/Roboto.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiConfig.setAuthToken('teste');
  });
  testWidgets(
    'frete mantém resumo após falha e cabe em 320 com texto ampliado',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      final provider = EntregaProvider(
        service: FakeEntregaService(),
        automatic: false,
      );
      final queries = _Queries();
      await tester.pumpWidget(app(GanhosTab(service: queries), provider));
      await tester.pumpAndSettle();
      expect(find.textContaining('12,50'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('Frete calculado (hoje)'), 200);
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/frete_acessivel.png'),
      );
      queries.fail = true;
      final refresh = tester
          .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
          .show();
      await tester.pumpAndSettle();
      await refresh;
      expect(find.textContaining('12,50'), findsWidgets);
      expect(find.textContaining('Conexão indisponível'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      provider.dispose();
    },
  );
  testWidgets(
    'filtro de histórico consulta status real e informa ausência de resultados',
    (tester) async {
      final provider = EntregaProvider(
        service: FakeEntregaService(),
        automatic: false,
      );
      await provider.sincronizar();
      final queries = _Queries();
      await tester.pumpWidget(app(PedidosTab(service: queries), provider));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Concluídas'));
      await tester.pumpAndSettle();
      expect(queries.filtro, 'ENTREGUE');
      expect(find.text('Nenhuma corrida com este status.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      provider.dispose();
    },
  );
}
