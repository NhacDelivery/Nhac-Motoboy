import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'api_config.dart';
import 'api_client.dart';

class UserService {
  final ApiClient api;
  UserService({ApiClient? api}) : api = api ?? ApiClient();
  String get userId {
    // O JWT fornece apenas o identificador; permissão é sempre validada pelo servidor.
    try {
      final parts = ApiConfig.authToken!.split('.');
      return (jsonDecode(
            utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
          ) as Map)['sub']
          as String;
    } catch (_) {
      throw const ApiException(401, 'Sessão inválida. Entre novamente.');
    }
  }

  Future<Map<String, dynamic>> obterUsuario() async =>
      Map<String, dynamic>.from(
        await api.request(
          'GET',
          '/api/v1/usuarios/${Uri.encodeComponent(userId)}',
        ),
      );
  Future<void> atualizar(Map<String, dynamic> fields) async {
    final data = await api.request(
      'PUT',
      '/api/v1/usuarios/${Uri.encodeComponent(userId)}',
      body: fields,
    );
    if (data is Map && data['token'] is String)
      await ApiConfig.setAuthToken(data['token']);
  }

  Future<String> enviarFotoPerfil(File imagem) async {
    if (await imagem.length() > 5 * 1024 * 1024) {
      throw StateError('Escolha uma foto de até 5 MB.');
    }
    final extension = imagem.path.split('.').last.toLowerCase();
    if (!{'jpg', 'jpeg', 'png', 'webp'}.contains(extension)) {
      throw StateError('Escolha uma foto JPEG, PNG ou WEBP.');
    }
    final token = ApiConfig.authToken;
    final contentType = extension == 'png'
        ? 'image/png'
        : extension == 'webp'
        ? 'image/webp'
        : 'image/jpeg';
    final request =
        http.MultipartRequest(
            'POST',
            Uri.parse('${ApiConfig.baseUrl}/api/v1/uploads/imagem'),
          )
          ..headers.addAll({
            'Authorization': 'Bearer $token',
            'X-App-Origin': 'motoboy',
          })
          ..fields['pasta'] = 'usuarios'
          ..files.add(
            await http.MultipartFile.fromPath(
              'arquivo',
              imagem.path,
              contentType: MediaType.parse(contentType),
            ),
          );
    final client = http.Client();
    try {
      final response = await (() async => http.Response.fromStream(
        await client.send(request),
      ))().timeout(const Duration(seconds: 25));
      if (token != ApiConfig.authToken)
        throw StateError('Sessão alterada durante o envio.');
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError(
          'Não foi possível enviar a foto (${response.statusCode}).',
        );
      }
      final url = (jsonDecode(response.body) as Map)['url']?.toString();
      if (url == null || url.isEmpty)
        throw StateError('Resposta inválida ao enviar a foto.');
      return url;
    } finally {
      client.close();
    }
  }

  Future<void> confirmarTelefone(String telefone, String codigo) async {
    await api.request(
      'PUT',
      '/api/v1/usuarios/me/telefone',
      body: {'telefone': telefone, 'codigo': codigo},
    );
  }

  Future<void> alterarSenha(String atual, String nova) async {
    await api.request(
      'PUT',
      '/api/v1/auth/alterar-senha',
      body: {'senhaAtual': atual, 'novaSenha': nova},
    );
  }

  Future<Map<String, bool>>
  obterPreferenciasNotificacao() async => Map<String, bool>.from(
    await api.request(
      'GET',
      '/api/v1/usuarios/${Uri.encodeComponent(userId)}/preferencias-notificacao',
    ),
  );
  Future<Map<String, bool>> atualizarPreferenciasNotificacao(
    Map<String, bool> fields,
  ) async => Map<String, bool>.from(
    await api.request(
      'PUT',
      '/api/v1/usuarios/${Uri.encodeComponent(userId)}/preferencias-notificacao',
      body: fields,
    ),
  );
}
