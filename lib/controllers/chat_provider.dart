import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/mensagem_model.dart';
import '../services/chat_service.dart';
import '../services/realtime_service.dart';
import '../services/api_config.dart';

class ChatProvider extends ChangeNotifier {
  final ChatService service;
  final RealtimeService realtime;
  ChatProvider({ChatService? service, RealtimeService? realtime})
    : service = service ?? ChatService(),
      realtime = realtime ?? RealtimeService() {
    ApiConfig.session.addListener(_session);
  }
  final List<MensagemModel> mensagens = [];
  String? conversaId, erro;
  bool loading = false, enviando = false, ultima = false, _disposed = false;
  bool _loadingHistory = false;
  bool _pendingHistoryReset = false;
  Completer<void>? _historyCompletion;
  Completer<void>? _pendingResetCompletion;
  int _generation = 0;
  int _page = 0;
  Timer? _timeout;
  String? _pendingId, _pendingText;
  bool get envioSemConfirmacao => _pendingId != null && !enviando;
  bool get connected => realtime.connected;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _session() {
    realtime.dispose();
    _timeout?.cancel();
    _generation++;
    _loadingHistory = false;
    conversaId = null;
    mensagens.clear();
    enviando = false;
    loading = false;
    ultima = false;
    _page = 0;
    _pendingId = null;
    _pendingText = null;
    _pendingHistoryReset = false;
    _pendingResetCompletion?.complete();
    _pendingResetCompletion = null;
    if (!ApiConfig.temSessaoSalva) erro = 'Sessão encerrada.';
    _notify();
  }

  Future<void> abrir(String loja) async {
    final generation = ++_generation;
    realtime.dispose();
    _loadingHistory = false;
    _pendingHistoryReset = false;
    _pendingResetCompletion?.complete();
    _pendingResetCompletion = null;
    mensagens.clear();
    _page = 0;
    ultima = false;
    loading = true;
    erro = null;
    _notify();
    try {
      final id = await service.abrir(loja);
      if (_disposed || generation != _generation) return;
      conversaId = id;
      realtime.listen('/topic/conversas/$conversaId', (body) {
        try {
          final m = MensagemModel.fromJson(jsonDecode(body));
          receber(m);
          service.marcarLida(conversaId!).catchError((Object e) {
            erro = e.toString();
            _notify();
          });
        } catch (_) {
          erro = 'Mensagem inválida recebida.';
          _notify();
        }
      });
      realtime.listen('/user/queue/erros', (body) {
        try {
          erro = (jsonDecode(body) as Map)['erro']?.toString();
        } catch (_) {
          erro = 'Não foi possível enviar a mensagem.';
        }
        enviando = false;
        _timeout?.cancel();
        _notify();
      });
      realtime.onConnected = () {
        erro = null;
        carregar(reset: true);
        _notify();
      };
      realtime.onError = (message) {
        erro = message;
        _notify();
      };
      realtime.connect();
      await carregar(reset: true);
    } catch (e) {
      if (generation == _generation && !_disposed) erro = e.toString();
    } finally {
      if (generation == _generation) {
        loading = false;
        _notify();
      }
    }
  }

  void receber(MensagemModel m, {bool notify = true}) {
    if (_disposed || m.conversaId != conversaId) return;
    mensagens.removeWhere((old) => old.id == m.id);
    mensagens.add(m);
    if (notify) mensagens.sort((a, b) => a.enviadaEm.compareTo(b.enviadaEm));
    if (_pendingId != null && m.id == 'msg_$_pendingId') {
      enviando = false;
      _pendingId = null;
      _pendingText = null;
      _timeout?.cancel();
      erro = null;
    }
    if (notify) _notify();
  }

  Future<void> carregar({bool reset = false}) async {
    if (conversaId == null || _disposed) return;
    if (_loadingHistory) {
      if (reset) {
        _pendingHistoryReset = true;
        _pendingResetCompletion ??= Completer<void>();
        await _pendingResetCompletion!.future;
      } else {
        await _historyCompletion?.future;
      }
      return;
    }
    _loadingHistory = true;
    final completion = Completer<void>();
    _historyCompletion = completion;
    final generation = _generation;
    final id = conversaId!;
    try {
      final result = await service.historico(id, reset ? 0 : _page);
      if (_disposed || generation != _generation || conversaId != id) return;
      if (reset) _page = 0;
      for (final m in result.mensagens) {
        receber(m, notify: false);
      }
      mensagens.sort((a, b) => a.enviadaEm.compareTo(b.enviadaEm));
      _page++;
      ultima = result.last;
      await service.marcarLida(id);
    } catch (e) {
      if (generation == _generation && !_disposed) erro = e.toString();
    } finally {
      if (generation == _generation && !_disposed) {
        _loadingHistory = false;
        _notify();
      }
      completion.complete();
      if (identical(_historyCompletion, completion)) _historyCompletion = null;
      if (generation == _generation && !_disposed && _pendingHistoryReset) {
        _pendingHistoryReset = false;
        final pending = _pendingResetCompletion;
        _pendingResetCompletion = null;
        try {
          await carregar(reset: true);
        } finally {
          if (pending != null && !pending.isCompleted) pending.complete();
        }
      }
    }
  }

  Future<void> tentarNovamente(String loja) async {
    if (conversaId == null) {
      await abrir(loja);
      return;
    }
    realtime.reconnect();
    await carregar(reset: true);
  }

  bool reenviarPendente() {
    if (_pendingId == null ||
        _pendingText == null ||
        !connected ||
        enviando ||
        conversaId == null) {
      return false;
    }
    return _enviarComId(_pendingText!, _pendingId!);
  }

  bool enviar(String text) {
    final value = text.trim();
    if (!connected ||
        enviando ||
        conversaId == null ||
        value.isEmpty ||
        value.length > 4000) {
      return false;
    }
    if (_pendingId != null) return false;
    return _enviarComId(value, const Uuid().v4());
  }

  bool _enviarComId(String value, String id) {
    try {
      realtime.send('/app/conversas/$conversaId/enviar', {
        'conteudo': value,
        'clientMessageId': id,
      });
      _pendingId = id;
      _pendingText = value;
      enviando = true;
      erro = null;
      _timeout?.cancel();
      _timeout = Timer(const Duration(seconds: 15), () {
        enviando = false;
        erro =
            'Confirmação incerta. Atualize o histórico e, se necessário, reenvie a mesma mensagem.';
        _notify();
      });
      _notify();
      return true;
    } catch (e) {
      erro = e.toString();
      _notify();
      return false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timeout?.cancel();
    realtime.dispose();
    if (_pendingResetCompletion case final pending?) {
      if (!pending.isCompleted) pending.complete();
    }
    ApiConfig.session.removeListener(_session);
    super.dispose();
  }
}
