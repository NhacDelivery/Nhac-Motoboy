import 'dart:convert';
import 'api_config.dart';
import 'api_client.dart';

class UserService {
  final ApiClient api;
  UserService({ApiClient? api}) : api = api ?? ApiClient();
  String get userId {
    // O JWT fornece apenas o identificador; permissão é sempre validada pelo servidor.
    try {
      final parts = ApiConfig.authToken!.split('.');
      return (jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1])))) as Map)['sub'] as String;
    } catch (_) { throw const ApiException(401, 'Sessão inválida. Entre novamente.'); }
  }
  Future<Map<String, dynamic>> obterUsuario() async =>
      Map<String, dynamic>.from(await api.request('GET', '/api/v1/usuarios/${Uri.encodeComponent(userId)}'));
  Future<void> atualizar(Map<String, dynamic> fields) async {
    final data = await api.request('PUT', '/api/v1/usuarios/${Uri.encodeComponent(userId)}', body: fields);
    if (data is Map && data['token'] is String) await ApiConfig.setAuthToken(data['token']);
  }
  Future<void> alterarSenha(String atual, String nova) async {
    await api.request('PUT', '/api/v1/auth/alterar-senha', body: {'senhaAtual': atual, 'novaSenha': nova});
  }
  Future<Map<String, bool>> obterPreferenciasNotificacao() async =>
      Map<String, bool>.from(await api.request('GET',
        '/api/v1/usuarios/${Uri.encodeComponent(userId)}/preferencias-notificacao'));
  Future<Map<String, bool>> atualizarPreferenciasNotificacao(Map<String, bool> fields) async =>
      Map<String, bool>.from(await api.request('PUT',
        '/api/v1/usuarios/${Uri.encodeComponent(userId)}/preferencias-notificacao', body: fields));
}
