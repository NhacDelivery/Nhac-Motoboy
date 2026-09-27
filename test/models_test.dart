import 'package:flutter_test/flutter_test.dart';
import 'package:nhac_motoboy/models/status.dart';
import 'package:nhac_motoboy/models/oferta_entrega_model.dart';
import 'package:nhac_motoboy/models/rota_model.dart';
import 'package:nhac_motoboy/models/historico_entrega_model.dart';
import 'package:nhac_motoboy/models/entregador_cadastro_model.dart';
import 'package:nhac_motoboy/utils/validators.dart';
import 'fixtures.dart';
void main() {
  for (final status in StatusPedido.values) {
    test('interpreta status ${status.api}', () => expect(StatusPedido.parse(status.api), status));
  }
  test('status ausente nunca habilita conclusão', () {
    expect(active('INVALIDO').statusPedido, StatusPedido.desconhecido);
  });
  test('oferta expira pelo prazo absoluto mesmo com contador positivo', () {
    expect(offer(expired: true).expirada, true);
    expect(offer().expirada, false);
  });
  test('oferta sem expiraEm não pode ser aceita', () {
    final data = offerJson()..remove('expiraEm');
    expect(OfertaEntregaModel.fromJson(data).expirada, true);
  });
  test('perfil inclui ativo e status do backend', () {
    expect(profile('EM_ENTREGA').statusOperacional, 'EM_ENTREGA');
    expect(profile().ativo, true);
  });
  test('interpreta status operacional mesmo com caixa e espaços diferentes', () {
    expect(StatusOperacional.parse(' online '), StatusOperacional.online);
    expect(StatusOperacional.parse('OFFLINE'), StatusOperacional.offline);
  });
  test('perfil preserva localização e instante retornados pelo backend', () {
    final model = EntregadorCadastroModel.fromJson({
      ...profileJson(),
      'latitudeAtual': -23.5,
      'longitudeAtual': -46.6,
      'ultimaAtualizacaoLocalizacao': '2026-09-21T12:00:00Z',
    });
    expect(model.latitudeAtual, -23.5);
    expect(model.longitudeAtual, -46.6);
    expect(model.ultimaAtualizacaoLocalizacao, DateTime.parse('2026-09-21T12:00:00Z'));
  });
  test('código de recuperação exige exatamente seis dígitos', () {
    expect(Validators.validarCodigoRecuperacao('123456'), isNull);
    expect(Validators.validarCodigoRecuperacao('12345'), isNotNull);
    expect(Validators.validarCodigoRecuperacao('12A456'), isNotNull);
  });
  test('senha de redefinição segue mínimo de seis caracteres do backend', () {
    expect(Validators.validarSenhaRedefinicao('123456'), isNull);
    expect(Validators.validarSenhaRedefinicao('12345'), isNotNull);
  });
  test('rota não inventa coordenadas nem ETA', () {
    expect(route().distanciaKm, 3.5);
    expect(route().waypoints.length, 2);
    expect(() => RotaModel.fromJson({'pedidoId': 'p'}), throwsFormatException);
  });
  test('histórico interpreta paginação e status', () {
    final page = HistoricoEntregasPagina.fromJson({'content': [
      {'pedidoId': 'p', 'status': 'CANCELADO', 'taxaFrete': 8}
    ], 'number': 2, 'totalPages': 4, 'last': false});
    expect(page.itens.single.status, StatusPedido.cancelado);
    expect(page.paginaAtual, 2); expect(page.ultima, false);
  });
}
