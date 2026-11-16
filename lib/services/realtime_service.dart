import 'dart:convert';

import 'package:stomp_dart_client/stomp_dart_client.dart';

import 'api_config.dart';

class RealtimeService {
  StompClient? _client;
  final Map<String, void Function(String)> _listeners = {};
  final Map<String, StompUnsubscribe> _subscriptions = {};
  void Function()? onConnected;
  void Function(String)? onError;
  void Function()? onDisconnected;
  bool get connected => _client?.connected == true;

  void connect() {
    if (_client != null || !ApiConfig.temSessaoSalva) return;

    // O token pode ser renovado enquanto o app permanece aberto. O mapa é
    // atualizado antes de cada tentativa, inclusive nas reconexões automáticas.
    final connectHeaders = <String, String>{};

    _client = StompClient(
      config: StompConfig(
        url: ApiConfig.wsUrl,
        stompConnectHeaders: connectHeaders,
        beforeConnect: () async {
          final token = ApiConfig.authToken;
          if (token == null || token.isEmpty) {
            throw StateError('Sessão expirada. Entre novamente.');
          }
          connectHeaders['Authorization'] = 'Bearer $token';
        },
        reconnectDelay: const Duration(seconds: 5),
        connectionTimeout: const Duration(seconds: 15),
        // Heartbeats STOMP detectam conexões que ficaram silenciosamente
        // interrompidas; ping WebSocket ajuda a manter o túnel ativo.
        heartbeatIncoming: const Duration(seconds: 20),
        heartbeatOutgoing: const Duration(seconds: 20),
        pingInterval: const Duration(seconds: 25),
        onConnect: (_) {
          _subscriptions.clear();
          for (final topic in _listeners.keys) {
            _subscribe(topic);
          }
          onConnected?.call();
        },
        onWebSocketDone: () => onDisconnected?.call(),
        onDisconnect: (_) => onDisconnected?.call(),
        onStompError: (frame) => onError?.call(
          frame.body ?? 'O servidor recusou a conexão em tempo real.',
        ),
        onWebSocketError: (_) => onError?.call(
          'Falha na conexão em tempo real. Tentando reconectar.',
        ),
      ),
    );
    _client!.activate();
  }

  void listen(String topic, void Function(String) callback) {
    _listeners[topic] = callback;
    if (connected && !_subscriptions.containsKey(topic)) _subscribe(topic);
  }

  void _subscribe(String topic) {
    _subscriptions[topic] = _client!.subscribe(
      destination: topic,
      callback: (frame) {
        if (frame.body != null) _listeners[topic]?.call(frame.body!);
      },
    );
  }

  void unlisten(String topic) {
    _listeners.remove(topic);
    final unsubscribe = _subscriptions.remove(topic);
    if (connected) unsubscribe?.call();
  }

  void send(String destination, Map<String, dynamic> body) {
    if (!connected) throw StateError('Aguarde a reconexão antes de enviar.');
    _client!.send(destination: destination, body: jsonEncode(body));
  }

  void disconnect() {
    _client?.deactivate();
    _client = null;
    _subscriptions.clear();
  }

  void reconnect() {
    disconnect();
    connect();
  }

  void dispose() {
    disconnect();
    _listeners.clear();
  }
}
