import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'package:nhac_motoboy/services/entregador_service.dart';
import 'package:nhac_motoboy/controllers/entrega_provider.dart';
import 'package:nhac_motoboy/models/status.dart';
import 'package:nhac_motoboy/pages/home/tabs/avisos_page.dart';
import 'package:nhac_motoboy/pages/home/tabs/ganhos_tab.dart';
import 'package:nhac_motoboy/pages/home/tabs/pedidos_tab.dart';
import 'package:nhac_motoboy/pages/home/tabs/repasses_page.dart';
import 'package:nhac_motoboy/pages/home/tabs/suporte_entrega_page.dart';
import 'package:nhac_motoboy/services/api_client.dart';
import 'package:nhac_motoboy/services/api_config.dart';
import 'package:nhac_motoboy/services/chat_service.dart';
import 'package:nhac_motoboy/services/push_service.dart';

import 'integration_support.dart';

const uuid = Uuid();
Matcher apiError(int status) =>
    isA<ApiException>().having((e) => e.status, 'status', status);

// Interrompe somente o transporte da primeira consulta. A repetição consulta
// o backend real; nenhuma resposta de sucesso é fabricada.
class FailFirstGainsClient extends http.BaseClient {
  final http.Client delegate;
  bool failed = false;
  FailFirstGainsClient(this.delegate);
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (!failed && request.url.path.endsWith('/ganhos')) {
      failed = true;
      throw http.ClientException('Falha de rede controlada.', request.url);
    }
    return delegate.send(request);
  }
}

void main() {
  if (!integrationEnabled) {
    test(
      'todos os fluxos: executar tool/run_integration.sh',
      () {},
      skip: 'Requer backend H2 isolado; nenhuma chamada à produção.',
    );
    return;
  }
  BackendIntegrationBinding();
  setUpAll(() => SharedPreferences.setMockInitialValues({}));

  void scenario(
    String id,
    String description,
    Future<void> Function(IntegrationScenario) run,
  ) {
    test('$id $description', () async {
      final h = IntegrationScenario(id);
      await h.init();
      try {
        await run(h);
      } finally {
        await h.close();
      }
    }, timeout: const Timeout(Duration(minutes: 2)));
  }

  void screen(
    String id,
    String description,
    Future<void> Function(WidgetTester, IntegrationScenario) run,
  ) {
    testWidgets('$id $description', (tester) async {
      final h = IntegrationScenario(id);
      final initialized = await tester.runAsync(() async {
        await h.init();
        return true;
      });
      expect(initialized, true);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      try {
        await run(tester, h);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(h.close);
        // Os clientes HTTP das telas fecham conexões ociosas após 15 s.
        // Avança apenas o relógio fake, mantendo a verificação de timers ativa.
        await tester.pump(const Duration(seconds: 30));
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      }
    });
  }

  scenario(
    'it-moto-004',
    'cadastro de conta: código de e-mail, login e duplicidade',
    (h) async {
      final email = 'nova-${h.id}@integration.nhac.local';
      expect(await h.auth.checarEmail(email), false);
      await expectLater(
        h.auth.registrar(
          id: uuid.v4(),
          nome: 'Nova Entregadora',
          email: email,
          telefone: '+5511987654321',
          senha: integrationPassword,
        ),
        throwsA(apiError(400)),
      );
      await h.auth.enviarCodigoCadastro(email);
      final code = await h.code(email: email);
      await expectLater(
        h.auth.confirmarEmailCadastro(
          email,
          code == '000000' ? '111111' : '000000',
        ),
        throwsA(apiError(400)),
      );
      await h.auth.confirmarEmailCadastro(email, code);
      final token = await h.auth.registrar(
        id: uuid.v4(),
        nome: 'Nova Entregadora',
        email: email,
        telefone: '+5511987654321',
        senha: integrationPassword,
      );
      await ApiConfig.setAuthToken(token);
      expect((await h.users.obterUsuario())['nome'], 'Nova Entregadora');
      expect(await h.auth.checarEmail(email), true);
      await expectLater(
        h.auth.registrar(
          id: uuid.v4(),
          nome: 'Duplicada',
          email: email,
          telefone: '+5511987654322',
          senha: integrationPassword,
        ),
        throwsA(apiError(400)),
      );
      await expectLater(
        h.auth.login(email, 'SenhaIncorreta#123'),
        throwsA(apiError(401)),
      );
      expect(await h.auth.login(email, integrationPassword), isNotEmpty);
      expect(await h.service.obterPerfil(), isNull);
    },
  );

  scenario(
    'it-moto-005',
    'recuperar e alterar senha, código consumido e senha antiga rejeitada',
    (h) async {
      await h.auth.recuperarSenha(h.email());
      final code = await h.code(email: h.email());
      await h.auth.redefinirSenha(h.email(), code, 'NovaSenha#987');
      await expectLater(
        h.auth.redefinirSenha(h.email(), code, 'OutraSenha#456'),
        throwsA(apiError(400)),
      );
      await expectLater(
        h.auth.login(h.email(), integrationPassword),
        throwsA(apiError(401)),
      );
      await ApiConfig.setAuthToken(
        await h.auth.login(h.email(), 'NovaSenha#987'),
      );
      await expectLater(
        h.users.alterarSenha('Errada#123', 'Definitiva#321'),
        throwsA(apiError(401)),
      );
      await ApiConfig.setAuthToken(
        await h.auth.login(h.email(), 'NovaSenha#987'),
      );
      await h.users.alterarSenha('NovaSenha#987', 'Definitiva#321');
      await expectLater(
        h.auth.login(h.email(), 'NovaSenha#987'),
        throwsA(apiError(401)),
      );
      expect(await h.auth.login(h.email(), 'Definitiva#321'), isNotEmpty);
    },
  );

  scenario(
    'it-moto-006',
    'SMS: código errado, login, troca de telefone e reuso rejeitado',
    (h) async {
      await h.auth.enviarCodigoTelefone(h.phone());
      final code = await h.code(phone: h.phone());
      await expectLater(
        h.auth.loginComSms(
          telefone: h.phone(),
          codigo: code == '000000' ? '111111' : '000000',
        ),
        throwsA(apiError(400)),
      );
      await ApiConfig.setAuthToken(
        await h.auth.loginComSms(telefone: h.phone(), codigo: code),
      );
      expect(ApiConfig.usuarioId, h.actorId());
      final newPhone = '+5511987654333';
      await expectLater(
        h.users.atualizar({'telefone': newPhone}),
        throwsA(apiError(400)),
      );
      await h.auth.enviarCodigoTelefone(newPhone);
      final changeCode = await h.code(phone: newPhone);
      await h.users.confirmarTelefone(newPhone, changeCode);
      expect((await h.users.obterUsuario())['telefone'], newPhone);
      await expectLater(
        h.users.confirmarTelefone(newPhone, changeCode),
        throwsA(apiError(400)),
      );
    },
  );

  scenario(
    'it-moto-007',
    'nome, e-mail e foto persistem sem trocar a conta ou perder a corrida',
    (h) async {
      final p = await h.driver();
      await h.accept(p);
      final user = await h.profile();
      await user.atualizarNome('Maria Integração');
      await user.atualizarEmail('editada-${h.id}@integration.nhac.local');
      expect(user.nome, 'Maria Integração');
      expect(ApiConfig.usuarioId, h.actorId());
      expect(p.entregaAtiva!.pedidoId, h.order);
      final dir = await Directory.systemTemp.createTemp('motoboy-avatar-');
      try {
        final file = File('${dir.path}/avatar.png');
        await file.writeAsBytes(
          base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Y9Zl1sAAAAASUVORK5CYII=',
          ),
        );
        await user.atualizarFotoPerfil(file);
        expect(user.fotoPerfil, isNotEmpty);
        expect((await h.users.obterUsuario())['imagemUrl'], user.fotoPerfil);
      } finally {
        await dir.delete(recursive: true);
      }
      await expectLater(
        h.users.atualizar({'email': h.email('b')}),
        throwsA(apiError(400)),
      );
      await h.request(
        'b',
        'PUT',
        '/api/v1/usuarios/${h.actorId()}',
        body: {'nome': 'Invasor'},
        status: 403,
      );
      expect((await h.users.obterUsuario())['nome'], 'Maria Integração');
    },
  );

  scenario(
    'it-moto-008',
    'cadastro bicicleta, validações, duplicidade e migração para moto',
    (h) async {
      expect(await h.service.obterPerfil(), isNull);
      await expectLater(
        h.service.cadastrarEntregador(
          cnh: '',
          placaVeiculo: '',
          tipoVeiculo: 'MOTO',
          cpf: h.cpf(),
        ),
        throwsA(apiError(400)),
      );
      await expectLater(
        h.service.cadastrarEntregador(
          cnh: '',
          placaVeiculo: '',
          tipoVeiculo: 'BICICLETA',
          cpf: '11111111111',
        ),
        throwsA(apiError(400)),
      );
      final p = await h.driver(online: false, vehicle: 'BICICLETA');
      expect(p.perfilEntregador!.cnh, isEmpty);
      expect(p.perfilEntregador!.placaVeiculo, isEmpty);
      await expectLater(
        h.service.cadastrarEntregador(
          cnh: '',
          placaVeiculo: '',
          tipoVeiculo: 'BICICLETA',
          cpf: h.cpf(),
        ),
        throwsA(apiError(400)),
      );
      await expectLater(
        h.service.atualizarVeiculo(
          tipoVeiculo: 'MOTO',
          placaVeiculo: 'ABC1D23',
        ),
        throwsA(apiError(400)),
      );
      final profile = await h.service.atualizarVeiculo(
        tipoVeiculo: 'MOTO',
        placaVeiculo: 'abc-1234',
        cnh: '12345678901',
        corVeiculo: 'Azul',
        modeloVeiculo: 'Teste',
      );
      expect(profile.placaVeiculo, 'ABC1234');
      expect(profile.tipoVeiculo, 'MOTO');
      await h.service.atualizarDocumentos(cpf: h.cpf(), cnh: '98765432101');
      expect((await h.service.obterPerfil())!.cnh, '98765432101');
      await h.use('b');
      await expectLater(
        h.service.cadastrarEntregador(
          cnh: '',
          placaVeiculo: '',
          tipoVeiculo: 'BICICLETA',
          cpf: h.cpf(),
        ),
        throwsA(apiError(400)),
      );
    },
  );

  scenario(
    'it-moto-009',
    'Pix: CPF, celular, e-mail e aleatória; chave inválida não substitui a salva',
    (h) async {
      await h.driver(online: false);
      for (final entry in {
        'CPF': h.cpf(),
        'CELULAR': h.phone(),
        'EMAIL': h.email(),
        'ALEATORIA': uuid.v4(),
      }.entries) {
        final p = await h.service.atualizarDadosBancarios(
          tipoChavePix: entry.key,
          chavePix: entry.value,
        );
        expect(p.chavePix, entry.value);
        expect((await h.service.obterPerfil())!.tipoChavePix, entry.key);
      }
      final saved = (await h.service.obterPerfil())!.chavePix;
      await expectLater(
        h.service.atualizarDadosBancarios(
          tipoChavePix: 'CPF',
          chavePix: '11111111111',
        ),
        throwsA(apiError(400)),
      );
      expect((await h.service.obterPerfil())!.chavePix, saved);
    },
  );

  scenario(
    'it-moto-010',
    'disponibilidade exige GPS recente; cadastro inativo não recebe oferta',
    (h) async {
      final p = await h.driver(online: false);
      await expectLater(
        h.service.atualizarStatus(StatusOperacional.online),
        throwsA(apiError(400)),
      );
      await h.request(
        'a',
        'PATCH',
        '/api/v1/entregador/status',
        body: {'statusOperacional': 'EM_ENTREGA'},
        status: 400,
      );
      await h.request(
        'a',
        'PATCH',
        '/api/v1/entregador/localizacao',
        body: {'latitude': 91, 'longitude': 0},
        status: 400,
      );
      await p.alternarStatusOnline(true);
      expect(p.erro, isNull);
      await h.control('/usuarios/${h.actorId()}/gps-antigo');
      await h.dispatch();
      expect(await h.service.buscarOfertasPendentes(), isEmpty);
      await p.atualizarLocalizacao();
      await h.control('/usuarios/${h.actorId()}/inativar');
      await p.sincronizar();
      expect(p.cadastroAtivo, false);
      expect(p.ofertas, isEmpty);
      await expectLater(
        h.service.atualizarStatus(StatusOperacional.online),
        throwsA(apiError(400)),
      );
    },
  );

  scenario(
    'it-moto-011',
    'recusa, expiração, oferta inexistente e oferta alheia',
    (h) async {
      final a = await h.driver();
      await h.driver(actor: 'b');
      await h.use('a');
      await h.dispatch();
      await a.sincronizar();
      final offer = a.ofertas.singleWhere((o) => o.pedidoId == h.order);
      await h.request(
        'b',
        'POST',
        '/api/v1/entregas/ofertas/${offer.id}/aceitar',
        status: 404,
      );
      await h.service.recusarOferta(offer.id);
      await a.sincronizar();
      expect(a.ofertas, isEmpty);
      expect(await h.service.obterEntregaAtiva(), isNull);
      await h.dispatch(h.secondOrder);
      await a.sincronizar();
      final expired = a.ofertas.singleWhere((o) => o.pedidoId == h.secondOrder);
      await h.control('/pedidos/${h.secondOrder}/expirar-ofertas');
      await expectLater(
        h.service.aceitarOferta(expired.id),
        throwsA(apiError(400)),
      );
      await a.sincronizar();
      expect(a.ofertas, isEmpty);
      await expectLater(
        h.service.aceitarOferta('inexistente'),
        throwsA(apiError(404)),
      );
    },
  );

  scenario('it-moto-012', 'aceite concorrente: apenas um motoboy assume o pedido', (
    h,
  ) async {
    await h.driver();
    await h.driver(actor: 'b');
    await h.dispatch();
    final offers = <String, String>{};
    for (final actor in ['a', 'b']) {
      final list =
          await h.request(actor, 'GET', '/api/v1/entregas/ofertas/pendentes')
              as List;
      offers[actor] = list.singleWhere((e) => e['pedidoId'] == h.order)['id'];
    }
    // Clientes independentes mantêm os JWTs; não alteramos ApiConfig entre envios.
    final results = await Future.wait(
      ['a', 'b'].map((actor) async {
        final req = await h.client.post(
          Uri.parse(
            '${ApiConfig.baseUrl}/api/v1/entregas/ofertas/${offers[actor]}/aceitar',
          ),
          headers: {
            'Authorization': 'Bearer ${h.tokens[actor]}',
            'X-App-Origin': 'motoboy',
          },
        );
        return (actor: actor, status: req.statusCode, body: req.body);
      }),
    );
    expect(results.where((r) => r.status == 200), hasLength(1));
    expect(
      results.where((r) => r.status == 400 || r.status == 409),
      hasLength(1),
      reason: '$results',
    );
    final winner = results.singleWhere((r) => r.status == 200).actor;
    final loser = winner == 'a' ? 'b' : 'a';
    expect(
      (await h.request(winner, 'GET', '/api/v1/entregas/ativa'))['pedidoId'],
      h.order,
    );
    await h.request(loser, 'GET', '/api/v1/entregas/ativa', status: 404);
    expect(
      (await h.request(loser, 'GET', '/api/v1/entregador/estado'))['entrega'],
      isNull,
    );
  });

  scenario(
    'it-moto-013',
    'corrida ativa bloqueia veículo/status; coleta e conclusão são idempotentes',
    (h) async {
      final p = await h.driver();
      await h.accept(p);
      expect(p.podeColetar, true);
      expect(p.podeConcluir, false);
      await expectLater(
        h.service.concluirEntrega(h.order, codigo: '0123'),
        throwsA(apiError(400)),
      );
      await expectLater(
        h.service.atualizarStatus(StatusOperacional.offline),
        throwsA(apiError(400)),
      );
      await expectLater(
        h.service.atualizarVeiculo(tipoVeiculo: 'BICICLETA', placaVeiculo: ''),
        throwsA(apiError(400)),
      );
      await h.request(
        'b',
        'POST',
        '/api/v1/entregas/${h.order}/coletar',
        status: 403,
      );
      await h.service.coletarPedido(h.order);
      await h.service.coletarPedido(h.order);
      await p.sincronizar();
      expect(p.entregaColetada, true);
      expect(p.podeColetar, false);
      expect(await p.concluirEntregaAtual(codigo: '0123'), true);
      await h.service.concluirEntrega(h.order, codigo: '0123');
      expect(
        (await h.service.buscarHistorico(
          status: 'ENTREGUE',
          force: true,
        )).itens,
        hasLength(1),
      );
      expect((await h.service.buscarGanhos(force: true))!.totalEntregas, 1);
    },
  );

  scenario(
    'it-moto-014',
    'rota nova: GPS antigo gera 422, recuperação e correção autorizada do destino',
    (h) async {
      final p = await h.driver();
      await h.accept(p);
      // Força cálculo novo por uma mudança real do destino; a main tem cache de rota.
      await h.service.corrigirDestino(h.order, -23.552, -46.635);
      await h.control('/usuarios/${h.actorId()}/gps-antigo');
      await expectLater(h.service.obterRota(h.order), throwsA(apiError(422)));
      await p.atualizarLocalizacao();
      await p.carregarRota(h.order, tentarNovamente: true);
      expect(p.erroRota, isNull);
      expect(p.rotaAtual!.destino.latitude, closeTo(-23.550520, 0.000001));
      await h.request(
        'b',
        'PUT',
        '/api/v1/entregas/${h.order}/coordenadas-destino',
        body: {'latitude': -23.552, 'longitude': -46.635},
        status: 403,
      );
      await h.request(
        'a',
        'PUT',
        '/api/v1/entregas/${h.order}/coordenadas-destino',
        body: {'latitude': 100, 'longitude': 0},
        status: 400,
      );
      await p.corrigirDestino(-23.552, -46.635);
      expect(p.entregaAtiva!.entregaLatitude, -23.552);
      expect(await p.confirmarColeta(), true);
      expect(p.rotaAtual, isNotNull);
      // OSRM mock retorna destino fixo: coordenadas persistidas são a autoridade deste teste.
      expect((await h.service.obterEntregaAtiva())!.entregaLongitude, -46.635);
    },
  );

  scenario(
    'it-moto-015',
    'encerramento remoto limpa corrida e retomada recupera estado',
    (h) async {
      final p = await h.driver();
      await h.accept(p);
      await h.control('/pedidos/${h.order}/cancelamento-remoto');
      await p.sincronizar();
      expect(p.entregaAtiva, isNull);
      expect(p.rotaAtual, isNull);
      expect(p.estaOnline, true);
      expect(p.aviso, contains('encerrada'));
      expect(
        (await h.service.buscarHistorico(
          status: 'CANCELADO',
          force: true,
        )).itens.single.pedidoId,
        h.order,
      );
      await p.alternarStatusOnline(false);
      expect(p.erro, isNull);
      expect((await h.service.obterPerfil())!.statusOperacional, 'OFFLINE');
      await p.alternarStatusOnline(true);
      expect(p.erro, isNull);
      await p.sair();
      expect(ApiConfig.authToken, isNull);
      expect(
        (await h.request(
          'a',
          'GET',
          '/api/v1/entregador/perfil',
        ))['statusOperacional'],
        'OFFLINE',
      );
    },
  );

  scenario(
    'it-moto-016',
    'suporte: protocolo idempotente, resposta administrativa e isolamento',
    (h) async {
      final p = await h.driver();
      await h.accept(p);
      final path = '/api/v1/entregas/${h.order}/suporte';
      final payload = {
        'id': uuid.v4(),
        'motivo': 'ENDERECO',
        'descricao': 'Cliente informou endereço incorreto.',
      };
      final ticket = await h.request('a', 'POST', path, body: payload);
      expect(ticket['status'], 'ABERTO');
      expect(ticket['etapa'], 'ANTES_COLETA');
      expect(
        (await h.request('a', 'POST', path, body: payload))['id'],
        ticket['id'],
      );
      expect(await h.request('a', 'GET', path), hasLength(1));
      await h.request(
        'a',
        'POST',
        path,
        body: {...payload, 'descricao': 'Outro texto no mesmo protocolo.'},
        status: 400,
      );
      await h.driver(actor: 'b');
      await h.request(
        'b',
        'POST',
        path,
        body: {...payload, 'id': uuid.v4()},
        status: 403,
      );
      expect(await h.request('b', 'GET', path), isEmpty);
      await h.request(
        'a',
        'PUT',
        '/api/v1/suporte/entregas/${ticket['id']}/resposta',
        body: {'resposta': 'Retorne à loja.'},
        status: 403,
      );
      await h.request(
        'admin',
        'PUT',
        '/api/v1/suporte/entregas/${ticket['id']}/resposta',
        body: {'resposta': 'Aguarde confirmação do novo endereço.'},
      );
      final loaded = (await h.request('a', 'GET', path) as List).single;
      expect(loaded['status'], 'RESPONDIDO');
      expect(loaded['resposta'], contains('novo endereço'));
      await h.use('a');
      await p.sincronizar();
      expect(p.entregaAtiva!.pedidoId, h.order);
    },
  );

  scenario(
    'it-moto-017',
    'retirada antes da coleta libera a corrida só após confirmação administrativa',
    (h) async {
      final p = await h.driver();
      await h.accept(p);
      final ticket = await h.request(
        'a',
        'POST',
        '/api/v1/entregas/${h.order}/suporte',
        body: {
          'id': uuid.v4(),
          'motivo': 'RETIRADA',
          'descricao': 'Veículo indisponível antes da coleta.',
        },
      );
      await p.sincronizar();
      expect(p.entregaAtiva, isNotNull);
      final action = '/api/v1/suporte/entregas/${ticket['id']}/acao';
      final result = await h.request(
        'admin',
        'PUT',
        action,
        body: {'acao': 'RETIRAR', 'entregaFisicaConfirmada': false},
      );
      expect(result['status'], 'RETIRADO');
      expect(
        (await h.request(
          'admin',
          'PUT',
          action,
          body: {'acao': 'RETIRAR', 'entregaFisicaConfirmada': false},
        ))['id'],
        ticket['id'],
      );
      await p.sincronizar();
      expect(p.entregaAtiva, isNull);
      expect(p.status, StatusOperacional.offline);
      expect(
        (await h.request('a', 'GET', '/api/v1/entregas/${h.order}/suporte')
                as List)
            .single['status'],
        'RETIRADO',
      );
    },
  );

  scenario(
    'it-moto-018',
    'transferência após coleta exige entrega física e muda o responsável',
    (h) async {
      final a = await h.driver();
      await h.driver(actor: 'b');
      await h.use('a');
      await h.accept(a, collect: true);
      final ticket = await h.request(
        'a',
        'POST',
        '/api/v1/entregas/${h.order}/suporte',
        body: {
          'id': uuid.v4(),
          'motivo': 'TRANSFERENCIA',
          'descricao': 'Necessário transferir pedido para outra motoboy.',
        },
      );
      expect(ticket['etapa'], 'APOS_COLETA');
      final action = '/api/v1/suporte/entregas/${ticket['id']}/acao';
      await h.request(
        'admin',
        'PUT',
        action,
        body: {'acao': 'RETIRAR', 'entregaFisicaConfirmada': false},
        status: 400,
      );
      await h.request(
        'admin',
        'PUT',
        action,
        body: {
          'acao': 'TRANSFERIR',
          'novoUsuarioId': h.actorId('b'),
          'entregaFisicaConfirmada': false,
        },
        status: 400,
      );
      final result = await h.request(
        'admin',
        'PUT',
        action,
        body: {
          'acao': 'TRANSFERIR',
          'novoUsuarioId': h.actorId('b'),
          'entregaFisicaConfirmada': true,
        },
      );
      expect(result['status'], 'TRANSFERIDO');
      expect(result['responsavelUsuarioId'], h.actorId('b'));
      await a.sincronizar();
      expect(a.entregaAtiva, isNull);
      expect(a.status, StatusOperacional.offline);
      await h.request(
        'a',
        'POST',
        '/api/v1/entregas/${h.order}/concluir',
        body: {'codigo': '0123'},
        status: 403,
      );
      await h.use('b');
      expect(
        (await h.service.obterEntregaAtiva())!.statusPedido,
        StatusPedido.saiuEntrega,
      );
      await h.service.concluirEntrega(h.order, codigo: '0123');
      expect(
        (await h.service.buscarHistorico(force: true)).itens.single.pedidoId,
        h.order,
      );
    },
  );

  scenario(
    'it-moto-019',
    'histórico paginado, filtros, ganhos por período e avaliações vazias',
    (h) async {
      await h.driver(online: false);
      await h.control('/usuarios/${h.actorId()}/historico');
      final first = await h.service.buscarHistorico(
        status: 'ENTREGUE',
        size: 20,
        force: true,
      );
      final next = await h.service.buscarHistorico(
        status: 'ENTREGUE',
        page: 1,
        size: 20,
        force: true,
      );
      expect(first.itens, hasLength(20));
      expect(next.itens, hasLength(2));
      expect(next.ultima, true);
      expect({
        ...first.itens.map((e) => e.pedidoId),
        ...next.itens.map((e) => e.pedidoId),
      }, hasLength(22));
      expect(
        (await h.service.buscarHistorico(
          status: 'CANCELADO',
          force: true,
        )).itens,
        hasLength(1),
      );
      for (final period in ['HOJE', 'SETE_DIAS', 'TRINTA_DIAS']) {
        final gains = (await h.service.buscarGanhos(
          periodo: period,
          force: true,
        ))!;
        expect(gains.totalEntregas, 22);
        expect(gains.totalGanhos, 110);
      }
      expect((await h.service.buscarAvaliacoes(force: true)).total, 0);
      await h.driver(actor: 'b', online: false);
      expect((await h.service.buscarHistorico()).itens, isEmpty);
      expect((await h.service.buscarGanhos())!.totalEntregas, 0);
    },
  );

  scenario(
    'it-moto-020',
    'repasses: não apurado → pendente → pago; valor e permissão são validados',
    (h) async {
      final p = await h.driver();
      await h.accept(p, collect: true);
      expect(await p.concluirEntregaAtual(codigo: '0123'), true);
      Future<Map> repasse() async =>
          (await h.request(
                'a',
                'GET',
                '/api/v1/entregador/repasses',
              ))['content'].single
              as Map;
      expect((await repasse())['status'], 'NAO_APURADO');
      expect((await repasse())['valorDevido'], isNull);
      final path = '/api/v1/suporte/repasses/${h.order}';
      await h.request(
        'a',
        'PUT',
        '$path/apuracao',
        body: {'valorDevido': 4},
        status: 403,
      );
      await h.request(
        'admin',
        'PUT',
        '$path/apuracao',
        body: {'valorDevido': 4},
      );
      expect((await repasse())['status'], 'PENDENTE');
      expect((await repasse())['valorPago'], 0);
      final payment = {
        'referencia': 'pagamento-${h.id}',
        'valor': 4,
        'pagoEm': DateTime.now()
            .toUtc()
            .subtract(const Duration(minutes: 1))
            .toIso8601String(),
      };
      await h.request(
        'admin',
        'PUT',
        '$path/pagamento',
        body: {...payment, 'valor': 5},
        status: 400,
      );
      await h.request('admin', 'PUT', '$path/pagamento', body: payment);
      await h.request('admin', 'PUT', '$path/pagamento', body: payment);
      final paid = await repasse();
      expect(paid['status'], 'PAGO');
      expect(paid['valorPago'], 4);
      expect(paid['freteCalculado'], 5);
      await h.driver(actor: 'b', online: false);
      expect(
        (await h.request('b', 'GET', '/api/v1/entregador/repasses'))['content'],
        isEmpty,
      );
    },
  );

  scenario(
    'it-moto-021',
    'preferências e token de aparelho persistem e isolam notificações por conta',
    (h) async {
      await h.driver();
      final prefs = await h.users.obterPreferenciasNotificacao();
      expect(prefs.keys.toSet(), {
        'notificarNovoPedido',
        'notificarAvaliacoes',
        'notificarMensagens',
        'notificarNovidades',
      });
      final changed = {for (final key in prefs.keys) key: false};
      expect(await h.users.atualizarPreferenciasNotificacao(changed), changed);
      await h.auth.login(h.email(), integrationPassword);
      expect(await h.users.obterPreferenciasNotificacao(), changed);
      await h.users.atualizar({'fcmToken': 'token-dispositivo-${h.id}'});
      await h.users.atualizar({'fcmToken': ''});
      await h.users.atualizarPreferenciasNotificacao({
        for (final key in prefs.keys) key: true,
      });
      await h.dispatch();
      Map? aviso;
      for (var i = 0; i < 100; i++) {
        final list =
            (await h.request(
                  'a',
                  'GET',
                  '/api/v1/entregador/avisos',
                ))['content']
                as List;
        if (list.isNotEmpty) {
          aviso = list.first as Map;
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(aviso, isNotNull);
      expect(aviso!['usuarioId'], h.actorId());
      expect(aviso['pedidoId'], h.order);
      expect(PushService.pertenceConta(Map<String, dynamic>.from(aviso)), true);
      await h.driver(actor: 'b');
      expect(
        PushService.pertenceConta(Map<String, dynamic>.from(aviso)),
        false,
      );
      expect(
        (await h.request('b', 'GET', '/api/v1/entregador/avisos'))['content'],
        isEmpty,
      );
    },
  );

  scenario(
    'it-moto-022',
    'JWT rejeitado, logout limpa providers e cache não atravessa contas',
    (h) async {
      final p = await h.driver();
      final profile = await h.profile();
      await h.accept(p);
      expect(profile.usuarioId, h.actorId());
      final parts = h.tokens['a']!.split('.');
      await ApiConfig.setAuthToken(
        '${parts[0]}.${parts[1]}.assinatura-invalida',
      );
      // A main responde 403 para assinatura inválida; não confundir com
      // falta de permissão de uma sessão legítima nem deslogar em todo 403.
      await expectLater(h.users.obterUsuario(), throwsA(apiError(403)));
      expect(ApiConfig.authToken, isNotNull);
      await ApiConfig.limparSessao();
      expect(ApiConfig.authToken, isNull);
      expect(p.entregaAtiva, isNull);
      expect(profile.usuarioId, isEmpty);
      await h.use('a');
      await p.sincronizar();
      expect(p.entregaAtiva!.pedidoId, h.order);
      await h.use('b');
      expect(p.entregaAtiva, isNull);
      expect(p.ofertas, isEmpty);
      expect(await h.service.obterPerfil(), isNull);
    },
  );

  scenario(
    'it-moto-023',
    'chat real: dois participantes, reconexão, idempotência, paginação e leitura',
    (h) async {
      await h.driver();
      final chat = ChatService(api: h.api);
      final conversation = await chat.abrir(h.shop);
      expect(await chat.abrir(h.shop), conversation);
      final received = <Map<String, dynamic>>[];
      Future<StompClient> connect(String actor) async {
        final ready = Completer<void>();
        final socket = StompClient(
          config: StompConfig(
            url: ApiConfig.wsUrl,
            stompConnectHeaders: {'Authorization': 'Bearer ${h.tokens[actor]}'},
            reconnectDelay: Duration.zero,
            heartbeatOutgoing: Duration.zero,
            onConnect: (_) {
              if (!ready.isCompleted) ready.complete();
            },
            onStompError: (frame) {
              if (!ready.isCompleted) {
                ready.completeError(StateError(frame.body ?? 'STOMP'));
              }
            },
            onWebSocketError: (e) {
              if (!ready.isCompleted) ready.completeError(e);
            },
          ),
        );
        socket.activate();
        await ready.future.timeout(const Duration(seconds: 15));
        return socket;
      }

      var socket = await connect('a');
      final shopSocket = await connect('lojista');
      void subscribe() {
        socket.subscribe(
          destination: '/topic/conversas/$conversation',
          callback: (f) {
            if (f.body != null) {
              received.add(Map<String, dynamic>.from(jsonDecode(f.body!)));
            }
          },
        );
      }

      subscribe();
      Future<void> send(StompClient sender, String text, String id) async {
        sender.send(
          destination: '/app/conversas/$conversation/enviar',
          body: jsonEncode({'conteudo': text, 'clientMessageId': id}),
        );
        for (var i = 0; i < 150; i++) {
          final history = await chat.historico(conversation, 0);
          if (history.mensagens.any((m) => m.id == 'msg_$id')) return;
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        fail('Mensagem não persistida no backend após envio STOMP.');
      }

      try {
        final id = uuid.v4();
        await send(socket, 'Coleta em andamento', id);
        await send(socket, 'Coleta em andamento', id);
        expect(
          (await chat.historico(
            conversation,
            0,
          )).mensagens.where((m) => m.id == 'msg_$id'),
          hasLength(1),
        );
        socket.deactivate();
        socket = await connect('a');
        subscribe();
        await send(shopSocket, 'Pedido pronto para retirada', uuid.v4());
        expect(
          (await chat.historico(
            conversation,
            0,
          )).mensagens.any((m) => m.conteudo == 'Pedido pronto para retirada'),
          true,
        );
        await chat.marcarLida(conversation);
        final summary =
            (await h.request(
                  'a',
                  'GET',
                  '/api/v1/entregador/conversas',
                ))['content']
                as List;
        expect(
          summary.singleWhere((e) => e['id'] == conversation)['naoLidas'],
          0,
        );
        final paged = await h.request(
          'a',
          'GET',
          '/api/v1/entregador/conversas/$conversation/mensagens?page=0&size=1',
        );
        expect(paged['content'], hasLength(1));
        expect(paged['last'], false);
        await h.driver(actor: 'b');
        await h.request(
          'b',
          'GET',
          '/api/v1/entregador/conversas/$conversation/mensagens',
          status: 403,
        );
        expect(
          received.any((m) => m['conteudo'] == 'Coleta em andamento'),
          true,
        );
      } finally {
        socket.deactivate();
        shopSocket.deactivate();
      }
    },
  );

  scenario(
    'it-moto-028',
    'origem do app, e-mail existente e Google indisponível não criam sessão',
    (h) async {
      expect(await h.auth.checarEmail(h.email()), true);
      expect(
        await h.auth.checarEmail('ausente-${h.id}@integration.nhac.local'),
        false,
      );
      await h.request(
        'lojista',
        'POST',
        '/api/v1/auth/login',
        origin: 'motoboy',
        body: {'email': h.email('lojista'), 'senha': integrationPassword},
        status: 403,
      );
      final before = ApiConfig.authToken;
      await expectLater(
        h.auth.loginComGoogle('token-invalido'),
        throwsA(apiError(401)),
      );
      // AuthService devolve o erro; aplicar/encerrar sessão é responsabilidade da UI.
      expect(ApiConfig.authToken, before);
      await h.request(
        'a',
        'GET',
        '/api/v1/suporte/motoboy-it/codigo?email=${h.email()}',
        status: 403,
      );
    },
  );

  scenario(
    'it-moto-029',
    'segundo plano encerra disponibilidade e preserva corrida em andamento',
    (h) async {
      final p = await h.driver();
      Future<void> waitStatus(String value) async {
        for (var i = 0; i < 100; i++) {
          final perfil = await h.request(
            'a',
            'GET',
            '/api/v1/entregador/perfil',
          );
          if (perfil['statusOperacional'] == value) return;
          await Future<void>.delayed(const Duration(milliseconds: 25));
        }
        fail('O backend não confirmou o status $value.');
      }

      p.didChangeAppLifecycleState(AppLifecycleState.paused);
      await waitStatus('OFFLINE');
      await p.sincronizar();
      expect(p.estaOnline, false);
      p.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await waitStatus('OFFLINE');
      await p.alternarStatusOnline(true);
      await h.accept(p, collect: true);
      p.didChangeAppLifecycleState(AppLifecycleState.paused);
      await waitStatus('EM_ENTREGA');
      expect((await h.service.obterEntregaAtiva())!.pedidoId, h.order);
      p.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await p.sincronizar();
      expect(p.entregaAtiva!.pedidoId, h.order);
      expect(await p.concluirEntregaAtual(codigo: '0123'), true);
    },
  );

  screen(
    'it-moto-024',
    'suporte na tela: valida formulário, salva protocolo e mostra resposta real',
    (tester, h) async {
      await tester.runAsync(() async {
        final p = await h.driver();
        await h.accept(p);
      });
      await tester.pumpWidget(
        integrationApp(h, SuporteEntregaPage(pedidoId: h.order)),
      );
      await waitForUi(
        tester,
        () => find.byType(CircularProgressIndicator).evaluate().isEmpty,
      );
      expect(find.textContaining('continua responsável'), findsOneWidget);
      final submit = find.text('Abrir solicitação');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pump();
      expect(
        find.text('Descreva o problema com pelo menos 5 caracteres.'),
        findsOneWidget,
      );
      await tester.enterText(
        find.byType(TextFormField),
        'Preciso de ajuda com o endereço informado.',
      );
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await waitForUi(
        tester,
        () => find.textContaining('Protocolo ').evaluate().isNotEmpty,
      );
      final tickets =
          await tester.runAsync(
                () => h.request(
                  'a',
                  'GET',
                  '/api/v1/entregas/${h.order}/suporte',
                ),
              )
              as List;
      expect(tickets, hasLength(1));
      expect(
        tickets.single['descricao'],
        'Preciso de ajuda com o endereço informado.',
      );
      await tester.runAsync(
        () => h.request(
          'admin',
          'PUT',
          '/api/v1/suporte/entregas/${tickets.single['id']}/resposta',
          body: {'resposta': 'Endereço confirmado pelo cliente.'},
        ),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        integrationApp(h, SuporteEntregaPage(pedidoId: h.order)),
      );
      await waitForUi(
        tester,
        () => find
            .textContaining('Endereço confirmado pelo cliente.')
            .evaluate()
            .isNotEmpty,
      );
      expect(find.textContaining('RESPONDIDO'), findsOneWidget);
    },
  );

  screen(
    'it-moto-025',
    'tela de repasse distingue não apurado, pendente e pagamento efetivo',
    (tester, h) async {
      await tester.runAsync(() async {
        final p = await h.driver();
        await h.accept(p, collect: true);
        expect(await p.concluirEntregaAtual(codigo: '0123'), true);
      });
      Future<void> mount(String status) async {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(integrationApp(h, const RepassesPage()));
        await waitForUi(tester, () => find.text(status).evaluate().isNotEmpty);
        expect(find.text('Pedido #${h.order}'), findsOneWidget);
      }

      await mount('Aguardando apuração');
      expect(find.text('Valor devido: Não apurado'), findsOneWidget);
      await tester.runAsync(
        () => h.request(
          'admin',
          'PUT',
          '/api/v1/suporte/repasses/${h.order}/apuracao',
          body: {'valorDevido': 4},
        ),
      );
      await mount('Pagamento pendente');
      expect(
        find.textContaining(RegExp(r'Valor pago: R\$\s+0,00')),
        findsOneWidget,
      );
      await tester.runAsync(
        () => h.request(
          'admin',
          'PUT',
          '/api/v1/suporte/repasses/${h.order}/pagamento',
          body: {
            'referencia': 'repasse-tela',
            'valor': 4,
            'pagoEm': DateTime.now()
                .toUtc()
                .subtract(const Duration(minutes: 1))
                .toIso8601String(),
          },
        ),
      );
      await mount('Pago');
      expect(find.text('Referência: repasse-tela'), findsOneWidget);
      expect(find.textContaining('Valor pago: R\$'), findsOneWidget);
    },
  );

  screen(
    'it-moto-026',
    'histórico e frete mostram dados reais e troca de período',
    (tester, h) async {
      late EntregaProvider p;
      await tester.runAsync(() async {
        p = await h.driver(online: false);
        await h.control('/usuarios/${h.actorId()}/historico');
      });
      await tester.pumpWidget(
        integrationApp(h, const Scaffold(body: PedidosTab()), delivery: p),
      );
      await waitForUi(
        tester,
        () => find.textContaining('Loja integração').evaluate().isNotEmpty,
      );
      await tester.tap(find.textContaining('Loja integração').first);
      await tester.pumpAndSettle();
      expect(find.text('Detalhes da entrega'), findsOneWidget);
      expect(find.textContaining('Praça da Sé'), findsWidgets);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        integrationApp(h, const Scaffold(body: GanhosTab()), delivery: p),
      );
      await waitForUi(
        tester,
        () => find.textContaining('110,00').evaluate().isNotEmpty,
      );
      expect(find.text('7 dias'), findsOneWidget);
      await tester.tap(find.text('7 dias'));
      await tester.pump();
      await waitForUi(
        tester,
        () => find.byType(CircularProgressIndicator).evaluate().isEmpty,
      );
      expect(find.textContaining('110,00'), findsWidgets);
    },
  );

  screen(
    'it-moto-027',
    'avisos: vazio, oferta persistida e histórico recuperável ao reabrir',
    (tester, h) async {
      await tester.runAsync(() => h.driver());
      await tester.pumpWidget(integrationApp(h, const AvisosPage()));
      await waitForUi(
        tester,
        () =>
            find.text('Nenhuma notificação registrada.').evaluate().isNotEmpty,
      );
      await tester.runAsync(h.dispatch);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(integrationApp(h, const AvisosPage()));
      await waitForUi(
        tester,
        () => find
            .text('Nova oferta de corrida disponível.')
            .evaluate()
            .isNotEmpty,
      );
      expect(find.text('Nenhuma notificação registrada.'), findsNothing);
    },
  );
  screen(
    'it-moto-030',
    'falha de rede na tela de frete permite repetir e recuperar dados reais',
    (tester, h) async {
      late EntregaProvider p;
      await tester.runAsync(() async {
        p = await h.driver(online: false);
        await h.control('/usuarios/${h.actorId()}/historico');
        EntregadorService.invalidarConsultas();
      });
      final transport = FailFirstGainsClient(h.client);
      await tester.pumpWidget(
        integrationApp(
          h,
          Scaffold(
            body: GanhosTab(service: EntregadorService(client: transport)),
          ),
          delivery: p,
        ),
      );
      await waitForUi(
        tester,
        () => find.text('Tentar novamente').evaluate().isNotEmpty,
      );
      expect(transport.failed, true);
      expect(find.textContaining('110,00'), findsNothing);
      await tester.ensureVisible(find.text('Tentar novamente'));
      await tester.tap(find.text('Tentar novamente'));
      await waitForUi(
        tester,
        () => find.textContaining('110,00').evaluate().isNotEmpty,
      );
      expect(find.text('Tentar novamente'), findsNothing);
    },
  );
}
