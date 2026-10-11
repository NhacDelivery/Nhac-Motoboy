import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nhac_motoboy/services/api_config.dart';
import 'package:nhac_motoboy/services/push_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'trocar a conta impede abrir o aviso antigo ou sem destinatário',
    () async {
      SharedPreferences.setMockInitialValues({});
      String token(String id) =>
          'header.${base64Url.encode(utf8.encode(jsonEncode({'sub': id})))}.signature';
      await ApiConfig.setAuthToken(token('primeira'));
      expect(PushService.pertenceConta({'usuarioId': 'primeira'}), isTrue);
      await ApiConfig.setAuthToken(token('segunda'));
      expect(PushService.pertenceConta({'usuarioId': 'primeira'}), isFalse);
      expect(PushService.pertenceConta({}), isFalse);
      expect(PushService.pertenceConta({'usuarioId': 'segunda'}), isTrue);
      await ApiConfig.limparSessao();
      expect(PushService.pertenceConta({'usuarioId': 'segunda'}), isFalse);
    },
  );
}
