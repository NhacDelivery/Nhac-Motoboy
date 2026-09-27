import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class ApiException implements Exception {
  final int status;
  final String? code;
  final String message;
  final Object? details;
  const ApiException(this.status, this.message, {this.code, this.details});
  @override
  String toString() => message;
}

class ApiClient {
  final http.Client client;
  ApiClient({http.Client? client}) : client = client ?? http.Client();
  Future<dynamic> request(String method, String path, {
    Object? body, Map<String, String>? query, bool authenticated = true,
    Set<int> emptyStatuses = const {},
  }) async {
    final token = ApiConfig.authToken;
    final uri = Uri.parse('${ApiConfig.baseUrl}$path').replace(queryParameters: query);
    final request = http.Request(method, uri);
    request.headers.addAll(ApiConfig.headers);
    if (!authenticated) request.headers.remove('Authorization');
    if (body != null) request.body = jsonEncode(body);
    http.Response response;
    try {
      response = await http.Response.fromStream(await client.send(request))
          .timeout(const Duration(seconds: 25));
    } on TimeoutException {
      throw const ApiException(0, 'A conexão demorou demais. Tente novamente.');
    } on http.ClientException {
      throw const ApiException(0, 'Não foi possível conectar. Verifique sua internet.');
    }
    if (authenticated && token != ApiConfig.authToken) {
      throw const ApiException(401, 'A sessão foi alterada.');
    }
    if (response.statusCode == 401 && authenticated) await ApiConfig.limparSessao();
    if (emptyStatuses.contains(response.statusCode)) return null;
    dynamic data;
    if (response.bodyBytes.isNotEmpty) {
      try { data = jsonDecode(utf8.decode(response.bodyBytes)); } on FormatException {
        if (response.statusCode < 300) throw const ApiException(0, 'Resposta inválida do servidor.');
      }
    }
    if (response.statusCode >= 200 && response.statusCode < 300) return data;
    final error = data is Map ? data : <String, dynamic>{};
    throw ApiException(response.statusCode,
      error['message']?.toString() ?? (response.statusCode == 403
          ? 'Você não tem acesso a esta operação.'
          : response.statusCode == 401 ? 'Sessão expirada. Entre novamente.'
          : 'Não foi possível concluir a operação. Tente novamente.'),
      code: error['error']?.toString(), details: error['details']);
  }
}
