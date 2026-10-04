import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nhac_motoboy/controllers/entrega_provider.dart';
import 'package:nhac_motoboy/services/api_config.dart';
import 'package:nhac_motoboy/services/location_service.dart';
import 'package:nhac_motoboy/services/realtime_service.dart';
import 'entrega_provider_test.dart' show FakeEntregaService;
import 'fixtures.dart';

class _Gps extends LocationService {
  final positions = StreamController<Position>.broadcast();
  bool cancelled = false;
  _Gps() {
    positions.onCancel = () {
      cancelled = true;
    };
  }
  @override
  bool get suportaSegundoPlano => true;
  @override
  Stream<Position> streamDePosicao() => positions.stream;
}

class _Service extends FakeEntregaService {
  int sent = 0;
  @override
  Future<void> enviarLocalizacao(double lat, double lng) async {
    sent++;
  }
}

class _Socket extends RealtimeService {
  @override
  bool get connected => true;
  @override
  void connect() {}
  @override
  void listen(String topic, void Function(String) callback) {}
  @override
  void dispose() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'GPS continua durante navegação externa e para ao concluir a corrida',
    () async {
      SharedPreferences.setMockInitialValues({});
      await ApiConfig.setAuthToken('motoboy');
      final gps = _Gps();
      final service = _Service()
        ..current = active('SAIU_ENTREGA')
        ..operational = 'EM_ENTREGA';
      final provider = EntregaProvider(
        service: service,
        locationService: gps,
        realtime: _Socket(),
      );
      addTearDown(() async {
        provider.dispose();
        await gps.positions.close();
      });
      await provider.sincronizar();
      provider.didChangeAppLifecycleState(AppLifecycleState.paused);
      gps.positions.add(
        Position(
          latitude: -23.55,
          longitude: -46.63,
          timestamp: DateTime.now(),
          accuracy: 5,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(service.sent, 1);
      expect(provider.localizacaoRecente, true);
      expect(gps.cancelled, false);
      await provider.concluirEntregaAtual(codigo: '0123');
      await Future<void>.delayed(Duration.zero);
      expect(gps.cancelled, true);
    },
  );
}
