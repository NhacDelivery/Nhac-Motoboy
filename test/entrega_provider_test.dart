import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nhac_motoboy/controllers/entrega_provider.dart';
import 'package:nhac_motoboy/models/entrega_ativa_model.dart';
import 'package:nhac_motoboy/models/entregador_cadastro_model.dart';
import 'package:nhac_motoboy/models/oferta_entrega_model.dart';
import 'package:nhac_motoboy/models/rota_model.dart';
import 'package:nhac_motoboy/models/status.dart';
import 'package:nhac_motoboy/services/api_config.dart';
import 'package:nhac_motoboy/services/api_client.dart';
import 'package:nhac_motoboy/services/entregador_service.dart';
import 'fixtures.dart';

class FakeEntregaService extends EntregadorService {
  String operational = 'ONLINE';
  EntregaAtivaModel? current;
  List<OfertaEntregaModel> pending = [];
  Object? acceptError, collectError, statusError;
  int acceptCalls = 0, collectCalls = 0, finishCalls = 0, refuseCalls = 0;
  Completer<EntregaAtivaModel>? acceptGate;
  @override Future<EntregadorCadastroModel?> obterPerfil() async => profile(operational);
  @override Future<EntregaAtivaModel?> obterEntregaAtiva() async => current;
  @override Future<List<OfertaEntregaModel>> buscarOfertasPendentes() async => pending;
  @override Future<RotaModel> obterRota(String id) async => route();
  @override Future<EntregadorCadastroModel> atualizarStatus(StatusOperacional status) async {
    if (statusError != null) throw statusError!;
    operational = status.api; return profile(operational);
  }
  @override Future<EntregaAtivaModel> aceitarOferta(String id) async {
    acceptCalls++;
    if (acceptError != null) { pending = []; throw acceptError!; }
    current = acceptGate == null ? active() : await acceptGate!.future;
    operational = 'EM_ENTREGA'; return current!;
  }
  @override Future<void> recusarOferta(String id) async { refuseCalls++; pending = []; }
  @override Future<EntregaAtivaModel> coletarPedido(String id) async {
    collectCalls++;
    if (collectError != null) throw collectError!;
    current = active('SAIU_ENTREGA'); return current!;
  }
  @override Future<void> concluirEntrega(String id) async {
    finishCalls++; current = null; operational = 'ONLINE';
  }
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeEntregaService service;
  late EntregaProvider provider;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiConfig.setAuthToken('token');
    service = FakeEntregaService();
    provider = EntregaProvider(service: service, automatic: false);
  });
  tearDown(() => provider.dispose());
  test('restaura corrida e EM_ENTREGA ao abrir', () async {
    service.current = active(); service.operational = 'EM_ENTREGA';
    await provider.sincronizar();
    expect(provider.entregaAtiva?.pedidoId, 'p1');
    expect(provider.emEntrega, true); expect(provider.ofertas, isEmpty);
  });
  test('aceite só muda estado após resposta e bloqueia clique duplicado', () async {
    service.pending = [offer()]; await provider.sincronizar();
    service.acceptGate = Completer();
    final first = provider.aceitarOfertaAtual();
    expect(provider.entregaAtiva, isNull);
    expect(provider.isLoading, true);
    expect(await provider.aceitarOfertaAtual(), false);
    service.acceptGate!.complete(active());
    expect(await first, true);
    expect(service.acceptCalls, 1); expect(provider.status, StatusOperacional.emEntrega);
    expect(provider.ofertas, isEmpty);
  });
  test('oferta expirada não chega ao aceite', () async {
    await provider.sincronizar(); provider.receberOferta(offer(expired: true));
    expect(await provider.aceitarOfertaAtual(), false);
    expect(service.acceptCalls, 0);
  });
  test('ignora oferta atrasada durante corrida', () async {
    service.current = active(); service.operational = 'EM_ENTREGA'; await provider.sincronizar();
    provider.receberOferta(offer()); expect(provider.ofertas, isEmpty);
  });
  test('perda da disputa libera loading e mantém online', () async {
    service.pending = [offer()]; await provider.sincronizar();
    service.acceptError = const ApiException(400, 'Outro entregador já aceitou.');
    expect(await provider.aceitarOfertaAtual(), false);
    expect(provider.isLoading, false); expect(provider.estaOnline, true);
    expect(provider.ofertas, isEmpty); expect(provider.aviso, contains('outro entregador'));
  });
  test('coleta segue PREPARANDO para SAIU_ENTREGA', () async {
    service.current = active(); service.operational = 'EM_ENTREGA'; await provider.sincronizar();
    expect(await provider.confirmarColeta(), true);
    expect(provider.entregaColetada, true);
    expect(await provider.confirmarColeta(), false);
    expect(service.collectCalls, 1);
  });
  test('conclusão antes de coleta é bloqueada', () async {
    service.current = active(); await provider.sincronizar();
    expect(await provider.concluirEntregaAtual(), false); expect(service.finishCalls, 0);
  });
  test('conclusão limpa corrida e rota e retorna online', () async {
    service.current = active('SAIU_ENTREGA'); service.operational = 'EM_ENTREGA';
    await provider.sincronizar(); expect(provider.rotaAtual, isNotNull);
    expect(await provider.concluirEntregaAtual(), true);
    expect(provider.entregaAtiva, isNull); expect(provider.rotaAtual, isNull);
    expect(provider.status, StatusOperacional.online);
  });
  test('cancelamento reconciliado remove corrida antiga', () async {
    service.current = active(); service.operational = 'EM_ENTREGA';
    await provider.sincronizar();
    service.current = null; service.operational = 'ONLINE';
    await provider.sincronizar();
    expect(provider.entregaAtiva, isNull); expect(provider.rotaAtual, isNull);
    expect(provider.podeColetar, false); expect(provider.status, StatusOperacional.online);
  });
  test('falha offline não muda disponibilidade', () async {
    await provider.sincronizar(); service.statusError = const ApiException(500, 'Falhou');
    await provider.alternarStatusOnline(false); expect(provider.estaOnline, true);
  });
  test('não permite status manual durante corrida', () async {
    service.current = active(); service.operational = 'EM_ENTREGA';
    await provider.sincronizar(); await provider.alternarStatusOnline(false);
    expect(service.operational, 'EM_ENTREGA');
  });
  test('logout limpa corrida e ignora resposta atrasada de aceite', () async {
    service.pending = [offer()]; await provider.sincronizar();
    service.acceptGate = Completer(); final result = provider.aceitarOfertaAtual();
    await ApiConfig.limparSessao(); service.acceptGate!.complete(active());
    expect(await result, false);
    expect(provider.entregaAtiva, isNull); expect(provider.isCadastrado, false);
  });
  test('recusa confirma backend antes de remover oferta', () async {
    service.pending = [offer()]; await provider.sincronizar();
    expect(await provider.recusarOferta('o1'), true);
    expect(service.refuseCalls, 1); expect(provider.ofertas, isEmpty);
  });
}