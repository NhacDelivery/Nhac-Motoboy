import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'api_config.dart';
import 'user_service.dart';

@pragma('vm:entry-point')
Future<void> receberPushSegundoPlano(RemoteMessage message) async {
  // O sistema exibe o aviso. O histórico e a autorização pertencem ao servidor.
}

class PushService {
  static final shared = PushService();
  StreamSubscription<String>? _tokens;
  StreamSubscription<RemoteMessage>? _opened;
  void Function(Map<String, dynamic>)? onOpen;
  Map<String, dynamic>? _initial;
  String? erro;
  bool ativo = false;
  Future<void> init() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
    const appId = String.fromEnvironment('FIREBASE_APP_ID');
    const sender = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
    const project = String.fromEnvironment('FIREBASE_PROJECT_ID');
    if ([apiKey, appId, sender, project].any((v) => v.isEmpty)) {
      erro = 'As notificações do aparelho ainda não foram configuradas nesta versão.';
      return;
    }
    try {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: apiKey,
          appId: appId,
          messagingSenderId: sender,
          projectId: project,
        ),
      );
      FirebaseMessaging.onBackgroundMessage(receberPushSegundoPlano);
      _tokens = FirebaseMessaging.instance.onTokenRefresh.listen(
        (token) => unawaited(_register(token)),
      );
      _opened = FirebaseMessaging.onMessageOpenedApp.listen(
        (message) => _open(message.data),
      );
      // Em primeiro plano, a lista operacional e o histórico do servidor mostram os avisos.
      _initial = (await FirebaseMessaging.instance.getInitialMessage())?.data;
      ApiConfig.session.addListener(_session);
      ativo = true;
      _session();
    } catch (_) {
      erro = 'Não foi possível ativar as notificações do aparelho.';
    }
  }

  void _open(Map<String, dynamic> data) {
    if (!ApiConfig.temSessaoSalva) {
      _initial = data;
      return;
    }
    if (onOpen != null) {
      onOpen!(data);
    } else {
      _initial = data;
    }
  }

  void consumirInicial() {
    if (_initial != null && ApiConfig.temSessaoSalva && onOpen != null) {
      final data = _initial!;
      _initial = null;
      onOpen!(data);
    }
  }

  Future<void> _register(String token) async {
    if (!ApiConfig.temSessaoSalva) return;
    try {
      await UserService().atualizar({'fcmToken': token});
    } catch (_) {
      erro = 'Não foi possível registrar as notificações. Abra as preferências para tentar novamente.';
    }
  }

  void _session() {
    if (ApiConfig.temSessaoSalva) {
      unawaited(
        registrar().catchError((Object _) {
          erro = 'Não foi possível ativar os avisos do aparelho.';
        }),
      );
    } else {
      _initial = null;
      unawaited(
        FirebaseMessaging.instance.deleteToken().catchError((Object _) {}),
      );
    }
  }

  Future<void> registrar() async {
    if (!ativo || !ApiConfig.temSessaoSalva) return;
    final settings = await FirebaseMessaging.instance.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      erro =
          'Permita notificações nos ajustes do aparelho para receber avisos.';
      return;
    }
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await _register(token);
  }

  Future<void> encerrar() async {
    if (!ativo) return;
    try {
      await UserService().atualizar({'fcmToken': ''});
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {
      /* O aviso usa texto genérico, sem mensagem ou endereço pessoal. */
    }
  }

  Future<void> dispose() async {
    ApiConfig.session.removeListener(_session);
    await _tokens?.cancel();
    await _opened?.cancel();
  }
}
