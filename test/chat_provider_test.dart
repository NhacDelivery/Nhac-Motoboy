import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nhac_motoboy/controllers/chat_provider.dart';
import 'package:nhac_motoboy/models/mensagem_model.dart';
import 'package:nhac_motoboy/services/chat_service.dart';
import 'package:nhac_motoboy/services/realtime_service.dart';

class _ChatService extends ChatService {
  int historyCalls = 0;
  Completer<void>? historyGate;
  int? gatedCall;
  @override Future<String> abrir(String lojaId) async => 'conv_1';
  @override Future<({List<MensagemModel> mensagens, bool last})> historico(String id, int page) async {
    historyCalls++;
    if (historyGate != null && historyCalls == gatedCall) await historyGate!.future;
    return (mensagens: <MensagemModel>[], last: true);
  }
  @override Future<void> marcarLida(String id) async {}
}

class _Realtime extends RealtimeService {
  final List<Map<String, dynamic>> sent = [];
  int reconnects = 0;
  @override bool get connected => true;
  @override void listen(String topic, void Function(String) callback) {}
  @override void connect() { onConnected?.call(); }
  @override void reconnect() { reconnects++; onConnected?.call(); }
  @override void send(String destination, Map<String, dynamic> body) { sent.add(body); }
  @override void dispose() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('mensagens iguais são confirmadas pelo ID e reconexão refaz socket', () async {
    final service = _ChatService();
    final realtime = _Realtime();
    final provider = ChatProvider(service: service, realtime: realtime);
    addTearDown(provider.dispose);
    await provider.abrir('loja');
    expect(provider.erro, isNull);

    expect(provider.enviar('Olá'), true);
    final first = realtime.sent.single['clientMessageId'] as String;
    provider.receber(MensagemModel.fromJson({
      'id': 'msg_$first', 'conversaId': 'conv_1', 'remetenteUsuarioId': 'me',
      'conteudo': 'Olá', 'enviadaEm': DateTime.now().toUtc().toIso8601String(),
    }));
    expect(provider.enviando, false);
    expect(provider.enviar('Olá'), true);
    expect(realtime.sent.last['clientMessageId'], isNot(first));

    await provider.tentarNovamente('loja');
    expect(realtime.reconnects, 1);
    expect(service.historyCalls, greaterThanOrEqualTo(2));
  });
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
