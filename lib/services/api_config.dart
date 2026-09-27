import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  static const _chaveToken = 'nhac_motoboy_auth_token';
  static String? _authToken;
  static final session = ValueNotifier<String?>(null);
  static String get baseUrl {
    const configured = String.fromEnvironment('API_BASE_URL');
    final value = configured.isNotEmpty ? configured : 'https://backend-nhac.onrender.com';
    final semBarra = value.replaceFirst(RegExp(r'/+$'), '');
    // Os services já incluem /api/v1 em cada rota. Aceitar também uma
    // API_BASE_URL terminando em /api/v1 evita duplicar o prefixo no CI/E2E.
    return semBarra.replaceFirst(RegExp(r'/api/v1$'), '');
  }
  static String get wsUrl {
    final uri = Uri.parse(baseUrl);
    return uri.replace(scheme: uri.scheme == 'https' ? 'wss' : 'ws',
      path: '${uri.path}/ws-native').toString();
  }
  static Future<void> init() async {
    _authToken = (await SharedPreferences.getInstance()).getString(_chaveToken);
    session.value = _authToken;
  }
  static Future<void> setAuthToken(String token) async {
    await (await SharedPreferences.getInstance()).setString(_chaveToken, token);
    final previous = _authToken;
    _authToken = token;
    // Renovar o JWT da mesma conta não deve descartar corrida, chat e perfil.
    if (_subject(previous) != _subject(token) || _subject(token) == null) {
      session.value = token;
    }
  }
  static String? _subject(String? token) {
    try {
      final part = token!.split('.')[1];
      return (jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(part)))) as Map)['sub']?.toString();
    } catch (_) { return null; }
  }
  static Future<void> limparSessao() async {
    _authToken = null;
    session.value = null;
    await (await SharedPreferences.getInstance()).remove(_chaveToken);
  }
  static String? get authToken => _authToken;
  static bool get temSessaoSalva => _authToken?.isNotEmpty == true;
  static Map<String, String> get headers => {
    'Content-Type': 'application/json', 'Accept': 'application/json',
    'X-App-Origin': 'motoboy',
    if (temSessaoSalva) 'Authorization': 'Bearer $_authToken',
  };
}
