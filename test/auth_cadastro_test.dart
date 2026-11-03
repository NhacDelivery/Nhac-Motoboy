import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nhac_motoboy/controllers/cadastro_controller.dart';
import 'package:nhac_motoboy/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CadastroController', () {
    test('gerencia tokenCadastro e reseta em limparDados', () {
      final controller = CadastroController();
      expect(controller.tokenCadastro, '');

      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.setTokenCadastro('token-123');
      expect(controller.tokenCadastro, 'token-123');
      expect(notifications, 1);

      controller.limparDados();
      expect(controller.tokenCadastro, '');
      expect(notifications, 2);
    });
  });

  group('AuthService', () {
    test('confirmarEmailCadastro retorna tokenCadastro do backend', () async {
      final auth = AuthService(
        client: MockClient((request) async {
          expect(request.url.path, '/api/v1/auth/confirmar-email-cadastro');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['email'], 'teste@nhac.com');
          expect(body['codigo'], '123456');

          return http.Response(
            jsonEncode({'tokenCadastro': 'tok-cad-xyz'}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      final token = await auth.confirmarEmailCadastro('teste@nhac.com', '123456');
      expect(token, 'tok-cad-xyz');
    });

    test('registrar envia tokenCadastro sem id e retorna Map com token e usuarioId', () async {
      final auth = AuthService(
        client: MockClient((request) async {
          expect(request.url.path, '/api/v1/auth/registrar');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body.containsKey('id'), false);
          expect(body['nome'], 'João Motoboy');
          expect(body['email'], 'joao@nhac.com');
          expect(body['telefone'], '+5511999999999');
          expect(body['senha'], 'Senha@123');
          expect(body['tokenCadastro'], 'tok-cad-xyz');

          return http.Response(
            jsonEncode({
              'token': 'jwt-token-abc',
              'usuarioId': 'usr-789',
            }),
            201,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      final resp = await auth.registrar(
        nome: 'João Motoboy',
        email: 'joao@nhac.com',
        telefone: '+5511999999999',
        senha: 'Senha@123',
        tokenCadastro: 'tok-cad-xyz',
      );

      expect(resp['token'], 'jwt-token-abc');
      expect(resp['usuarioId'], 'usr-789');
    });
  });
}
