import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:nhac_motoboy/services/api_config.dart';

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nhac_motoboy/controllers/chat_provider.dart';
import 'package:nhac_motoboy/models/mensagem_model.dart';
import 'package:nhac_motoboy/services/chat_service.dart';
import 'package:nhac_motoboy/services/realtime_service.dart';

class _ChatService extends ChatService {
  int historyCalls = 0;
  String conversation = 'conv_1';
  Completer<void>? historyGate;
  int? gatedCall;
  @override
  Future<String> abrir(String lojaId) async => conversation;
  @override
  Future<({List<MensagemModel> mensagens, bool last})> historico(
    String id,
    int page,
  ) async {
    historyCalls++;
    if (historyGate != null && historyCalls == gatedCall)
      await historyGate!.future;
    return (mensagens: <MensagemModel>[], last: true);
  }

  @override
  Future<void> marcarLida(String id) async {}
}

class _Realtime extends RealtimeService {
  final List<Map<String, dynamic>> sent = [];
  int reconnects = 0;
  @override
  bool get connected => true;
  @override
  void listen(String topic, void Function(String) callback) {}
  @override
  void connect() {
    onConnected?.call();
  }

  @override
  void reconnect() {
    reconnects++;
    onConnected?.call();
  }

  @override
  void send(String destination, Map<String, dynamic> body) {
    sent.add(body);
  }

  @override
  void dispose() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'recupera pendente após fechar chat e reenvia com mesmo identificador',
    () async {
      SharedPreferences.setMockInitialValues({});
      final payload = base64Url.encode(
        utf8.encode(jsonEncode({'sub': 'usuario-pendente'})),
      );
      await ApiConfig.setAuthToken('header.$payload.signature');
      final socket = _Realtime();
      final first = ChatProvider(service: _ChatService(), realtime: socket);
      await first.abrir('loja');
      expect(first.enviar('Não perder esta mensagem'), true);
      await Future<void>.delayed(Duration.zero);
      final id = first.idPendente;
      first.dispose();
      final second = ChatProvider(
        service: _ChatService(),
        realtime: _Realtime(),
      );
      await second.abrir('loja');
      expect(second.textoPendente, 'Não perder esta mensagem');
      expect(second.idPendente, id);
      expect(second.reenviarPendente(), true);
      await Future<void>.delayed(Duration.zero);
      second.receber(
        MensagemModel.fromJson({
          'id': 'msg_$id',
          'conversaId': 'conv_1',
          'remetenteUsuarioId': 'usuario-pendente',
          'conteudo': 'Não perder esta mensagem',
          'enviadaEm': DateTime.now().toIso8601String(),
        }),
      );
      expect(second.textoPendente, isNull);
      await Future<void>.delayed(Duration.zero);
      second.dispose();
      await ApiConfig.limparSessao();
    },
  );
  test('pendente fica vinculado à conversa ao trocar de loja', () async {
    SharedPreferences.setMockInitialValues({});
    final service = _ChatService();
    final provider = ChatProvider(service: service, realtime: _Realtime());
    addTearDown(provider.dispose);
    await provider.abrir('primeira');
    expect(provider.enviar('Só pertence à primeira'), true);
    await Future<void>.delayed(Duration.zero);
    service.conversation = 'conv_2';
    await provider.abrir('segunda');
    expect(provider.textoPendente, isNull);
    expect(provider.idPendente, isNull);
    expect(provider.enviando, false);
  });
  test(
    'mensagens iguais são confirmadas pelo ID e reconexão refaz socket',
    () async {
      final service = _ChatService();
      final realtime = _Realtime();
      final provider = ChatProvider(service: service, realtime: realtime);
      addTearDown(provider.dispose);
      await provider.abrir('loja');
      expect(provider.erro, isNull);

      expect(provider.enviar('Olá'), true);
      await Future<void>.delayed(Duration.zero);
      final first = realtime.sent.single['clientMessageId'] as String;
      provider.receber(
        MensagemModel.fromJson({
          'id': 'msg_$first',
          'conversaId': 'conv_1',
          'remetenteUsuarioId': 'me',
          'conteudo': 'Olá',
          'enviadaEm': DateTime.now().toUtc().toIso8601String(),
        }),
      );
      expect(provider.enviando, false);
      expect(provider.enviar('Olá'), true);
      await Future<void>.delayed(Duration.zero);
      expect(realtime.sent.last['clientMessageId'], isNot(first));

      await provider.tentarNovamente('loja');
      expect(realtime.reconnects, 1);
      expect(service.historyCalls, greaterThanOrEqualTo(2));
    },
  );
  test('reconexão durante a carga executa reset sem espera circular', () async {
    final service = _ChatService();
    final realtime = _Realtime();
    final provider = ChatProvider(service: service, realtime: realtime);
    addTearDown(provider.dispose);
    await provider.abrir('loja');
    service.historyGate = Completer<void>();
    service.gatedCall = service.historyCalls + 1;
    final first = provider.carregar();
    final reset = provider.carregar(reset: true);
    service.historyGate!.complete();
    await Future.wait([first, reset]).timeout(const Duration(seconds: 2));
    expect(service.historyCalls, service.gatedCall! + 1);
  });
}
