import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nhac_motoboy/utils/validators.dart';
import 'package:nhac_motoboy/utils/formatters.dart';
import 'package:nhac_motoboy/services/auth_service.dart';

void main() {
  test('aceita e-mails com aliases e preserva telefone internacional', () {
    for (final email in [
      'nome+teste@exemplo.com',
      'nome_sobrenome@exemplo.com',
      'nome-teste@exemplo.com',
    ]) {
      expect(Validators.validarEmail(email), isNull);
    }
    expect(Validators.validarEmail('nome@@exemplo.com'), isNotNull);
    expect(telefoneNacional('+5511999991234'), '11999991234');
    expect(telefoneE164('(11) 99999-1234'), '+5511999991234');
    expect(telefoneE164('+5511999991234'), '+5511999991234');
  });
  test(
    'autenticação bloqueia requisições simultâneas e libera após falha',
    () async {
      final pending = Completer<http.Response>();
      final first = AuthService(client: MockClient((_) => pending.future));
      final next = AuthService(
        client: MockClient((_) async => http.Response('{"existe":true}', 200)),
      );
      final operation = first.checarEmail('nome@exemplo.com');
      await expectLater(
        next.checarEmail('outro@exemplo.com'),
        throwsStateError,
      );
      pending.complete(http.Response('{"message":"Falha"}', 503));
      await expectLater(operation, throwsA(isA<Exception>()));
      expect(await next.checarEmail('outro@exemplo.com'), true);
    },
  );
}
