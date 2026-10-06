import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:nhac_motoboy/main.dart' as app;
import 'package:nhac_motoboy/services/api_config.dart';
import 'package:nhac_motoboy/controllers/entrega_provider.dart';
import 'package:nhac_motoboy/components/home/status_toggle_button.dart';
import 'package:provider/provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'DEVICE-MOTO-001 login, cadastro, GPS nativo, oferta, chat, coleta e conclusão',
    (tester) async {
      final uri = Uri.parse(ApiConfig.baseUrl);
      if (uri.scheme != 'http' ||
          !['127.0.0.1', '10.0.2.2'].contains(uri.host) ||
          uri.port != 18080) {
        throw StateError('Este teste exige backend isolado na porta 18080.');
      }
      Future<void> until(bool Function() ready) async {
        final end = DateTime.now().add(const Duration(seconds: 45));
        while (!ready()) {
          if (DateTime.now().isAfter(end)) {
            final textos = tester.allWidgets
                .whereType<Text>()
                .map((w) => w.data ?? w.textSpan?.toPlainText() ?? '')
                .toList();
            debugPrint('DEVICE_TIMEOUT_UI: $textos');
            fail('Etapa não concluída em 45s. Consulte DEVICE_TIMEOUT_UI.');
          }
          await tester.pump(const Duration(milliseconds: 250));
        }
      }

      Future<void> tap(Finder finder) async {
        await until(() => finder.evaluate().isNotEmpty);
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump(const Duration(milliseconds: 350));
        await tester.ensureVisible(finder.first);
        await tester.pump(const Duration(milliseconds: 350));
        await tester.tap(finder.first);
        await tester.pump();
      }

      Future<void> enter(Finder finder, String text) async {
        await until(() => finder.evaluate().isNotEmpty);
        await tester.ensureVisible(finder.first);
        await tester.enterText(finder.first, text);
        await tester.pump();
      }

      final client = http.Client();
      addTearDown(client.close);
      Future<String> actorToken(String who) async {
        final r = await client.post(
          Uri.parse('${ApiConfig.baseUrl}/api/v1/auth/login'),
          headers: {
            'Content-Type': 'application/json',
            'X-App-Origin': who == 'lojista' ? 'lojista' : 'cliente',
          },
          body: jsonEncode({
            'email': '$who@integration.nhac.local',
            'senha': 'NhacIntegration#123',
          }),
        );
        expect(r.statusCode, 200);
        return jsonDecode(r.body)['token'] as String;
      }

      await ApiConfig.limparSessao();
      await app.main();
      await tester.pump();
      await tap(find.text('Começar'));
      await enter(
        find.byType(TextFormField).first,
        'motoboy@integration.nhac.local',
      );
      await tap(find.text('Continuar'));
      await until(
        () => find.textContaining('Insira sua senha').evaluate().isNotEmpty,
      );
      await enter(find.byType(TextFormField).first, 'NhacIntegration#123');
      await tap(find.text('Continuar'));
      await tap(find.text('Comece seu cadastro'));
      await enter(find.byKey(const Key('cadastro-cpf')), '52998224725');
      await enter(find.byKey(const Key('cadastro-cnh')), '12345678900');
      await enter(find.byKey(const Key('cadastro-placa')), 'ABC1D23');
      await tap(find.byKey(const Key('cadastro-entregador-submit')));
      await until(() => find.byType(StatusToggleButton).evaluate().isNotEmpty);
      final permission = await Geolocator.checkPermission();
      expect(
        permission,
        anyOf(LocationPermission.always, LocationPermission.whileInUse),
        reason: 'O runner deve conceder a permissão nativa de localização.',
      );
      await tap(find.byType(StatusToggleButton));
      final homeContext = tester.element(find.byType(StatusToggleButton));
      final delivery = homeContext.read<EntregaProvider>();
      await until(() => delivery.estaOnline && delivery.localizacaoRecente);
      final loja = await actorToken('lojista');
      final response = await client.post(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/entregas/despachar/it-pedido'),
        headers: {'Authorization': 'Bearer $loja', 'X-App-Origin': 'lojista'},
      );
      expect(response.statusCode, 200);
      await until(() => delivery.ofertas.isNotEmpty);
      final oferta = delivery.ofertas.first;
      await tap(find.byKey(Key('oferta-aceitar-${oferta.id}')));
      await until(() => delivery.entregaAtiva != null);
      await tap(find.byKey(const Key('chat-button')));
      await until(() => find.text('Conectando ao chat…').evaluate().isEmpty);
      await enter(
        find.byKey(const Key('chat-message-input')),
        'Mensagem enviada no dispositivo',
      );
      await until(() => find.text('Conectando ao chat…').evaluate().isEmpty);
      await tap(find.byKey(const Key('chat-send-button')));
      await until(
        () =>
            find
                .text('Mensagem enviada no dispositivo')
                .evaluate()
                .isNotEmpty &&
            tester
                .widget<TextField>(find.byKey(const Key('chat-message-input')))
                .controller!
                .text
                .isEmpty,
      );
      await tester.pageBack();
      await tester.pump();
      await tap(find.byKey(const Key('corrida-coletar-button')));
      await tap(find.byKey(const Key('corrida-confirmar-dialog')));
      await until(() => delivery.entregaColetada);
      await tap(find.byKey(const Key('corrida-entregar-button')));
      await enter(find.byKey(const Key('entrega-codigo')), '0123');
      await tap(find.byKey(const Key('entrega-confirmar')));
      await until(() => delivery.entregaAtiva == null);
      expect(delivery.estaOnline, true);
    },
  );
}
