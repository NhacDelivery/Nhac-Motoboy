import '../models/mensagem_model.dart';
import 'api_client.dart';
class ChatService {
  final ApiClient api;
  ChatService({ApiClient? api}) : api = api ?? ApiClient();
  Future<String> abrir(String lojaId) async =>
    (await api.request('POST', '/api/v1/entregador/conversas/lojas/${Uri.encodeComponent(lojaId)}'))['id'] as String;
  Future<({List<MensagemModel> mensagens, bool last})> historico(String id, int page) async {
    final data = await api.request('GET', '/api/v1/entregador/conversas/${Uri.encodeComponent(id)}/mensagens',
      query: {'page': '$page', 'size': '30'});
    return (mensagens: (data['content'] as List).map((e) => MensagemModel.fromJson(e)).toList(), last: data['last'] == true);
  }
  Future<void> marcarLida(String id) async {
    await api.request('PATCH', '/api/v1/entregador/conversas/${Uri.encodeComponent(id)}/lida');
  }
}