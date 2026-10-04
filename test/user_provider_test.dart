import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nhac_motoboy/controllers/user_provider.dart';
import 'package:nhac_motoboy/services/user_service.dart';
import 'package:nhac_motoboy/services/api_config.dart';

class _Users extends UserService {
  int reads = 0;
  final first = Completer<Map<String, dynamic>>();
  @override
  Future<Map<String, dynamic>> obterUsuario() async {
    reads++;
    return reads == 1 ? first.future : {'id': 'u1', 'nome': 'Nome novo'};
  }

  @override
  Future<void> atualizar(Map<String, dynamic> fields) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'consulta de perfil é deduplicada e resposta anterior não desfaz edição',
    () async {
      final service = _Users();
      final provider = UserProvider(service: service);
      addTearDown(provider.dispose);
      final first = provider.carregarDadosReais();
      final same = provider.carregarDadosReais();
      expect(service.reads, 1);
      await provider.atualizarNome('Nome novo');
      service.first.complete({'id': 'u1', 'nome': 'Nome antigo'});
      await Future.wait([first, same]);
      expect(provider.nome, 'Nome novo');
      expect(provider.isLoading, false);
      await provider.carregarDadosReais();
      expect(service.reads, 2);
      await ApiConfig.setAuthToken('outra-conta');
      expect(provider.nome, isEmpty);
    },
  );
}
