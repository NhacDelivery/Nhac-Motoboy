import 'dart:convert';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import 'api_config.dart';

class RealtimeService {
  StompClient? _client;
  final Map<String, void Function(String)> _listeners = {};
  final Map<String, StompUnsubscribe> _subscriptions = {};
  void Function()? onConnected;
  void Function(String)? onError;
  bool get connected => _client?.connected == true;
  void connect() {
    if (_client != null || !ApiConfig.temSessaoSalva) return;
    _client = StompClient(config: StompConfig(
      url: ApiConfig.wsUrl,
      stompConnectHeaders: {'Authorization': 'Bearer ${ApiConfig.authToken}'},
      reconnectDelay: const Duration(seconds: 5),
      connectionTimeout: const Duration(seconds: 15),
      heartbeatIncoming: Duration.zero,
      heartbeatOutgoing: const Duration(seconds: 10),
      onConnect: (_) {
        _subscriptions.clear();
        for (final topic in _listeners.keys) { _subscribe(topic); }
        onConnected?.call();
      },
      onStompError: (frame) => onError?.call(frame.body ?? 'Conexão em tempo real indisponível.'),
      onWebSocketError: (_) => onError?.call('Conexão em tempo real indisponível. Tentando reconectar.'),
    ));
    _client!.activate();
  }
  void listen(String topic, void Function(String) callback) {
    _listeners[topic] = callback;
    if (connected && !_subscriptions.containsKey(topic)) _subscribe(topic);
  }
  void _subscribe(String topic) {
    _subscriptions[topic] = _client!.subscribe(destination: topic, callback: (frame) {
      if (frame.body != null) _listeners[topic]?.call(frame.body!);
    });
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
  void dispose() {
    disconnect();
    _listeners.clear();
  }
}
