import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/mensagem_model.dart';
import '../services/chat_service.dart';
import '../services/realtime_service.dart';
import '../services/api_config.dart';

class ChatProvider extends ChangeNotifier {
  final ChatService service;
  final RealtimeService realtime;
  ChatProvider({ChatService? service, RealtimeService? realtime})
    : service = service ?? ChatService(), realtime = realtime ?? RealtimeService() {
    ApiConfig.session.addListener(_session);
  }
  final List<MensagemModel> mensagens = [];
  String? conversaId, erro;
  bool loading = false, enviando = false, ultima = false, _disposed = false;
  int _page = 0;
  Timer? _timeout;
  String? _pending;
  bool get connected => realtime.connected;
  void _notify() { if (!_disposed) notifyListeners(); }
  void _session() {
    realtime.dispose();
    _timeout?.cancel();
    conversaId = null;
    mensagens.clear();
    enviando = false;
    loading = false;
    ultima = false;
    _page = 0;
    _pending = null;
    if (!ApiConfig.temSessaoSalva) erro = 'Sessão encerrada.';
    _notify();
  }
  Future<void> abrir(String loja) async {
    loading = true; erro = null; _notify();
    try {
      conversaId = await service.abrir(loja);
      if (_disposed) return;
      realtime.listen('/topic/conversas/$conversaId', (body) {
        try {
          final m = MensagemModel.fromJson(jsonDecode(body));
          receber(m);
          service.marcarLida(conversaId!).catchError((Object e) { erro = e.toString(); _notify(); });
        } catch (_) { erro = 'Mensagem inválida recebida.'; _notify(); }
      });
      realtime.listen('/user/queue/erros', (body) {
        try { erro = (jsonDecode(body) as Map)['erro']?.toString(); }
        catch (_) { erro = 'Não foi possível enviar a mensagem.'; }
        enviando = false; _timeout?.cancel(); _notify();
      });
      realtime.onConnected = () { erro = null; carregar(reset: true); _notify(); };
      realtime.onError = (message) { erro = message; _notify(); };
      realtime.connect();
      await carregar(reset: true);
    } catch (e) { erro = e.toString(); }
    finally { loading = false; _notify(); }
  }
  void receber(MensagemModel m) {
    if (_disposed || m.conversaId != conversaId) return;
    mensagens.removeWhere((old) => old.id == m.id);
    mensagens.add(m); mensagens.sort((a, b) => a.enviadaEm.compareTo(b.enviadaEm));
    if (_pending == m.conteudo) { enviando = false; _pending = null; _timeout?.cancel(); }
    _notify();
  }
  Future<void> carregar({bool reset = false}) async {
    if (conversaId == null || _disposed) return;
    try {
      final result = await service.historico(conversaId!, reset ? 0 : _page);
      if (_disposed) return;
      for (final m in result.mensagens) { receber(m); }
      _page = reset ? 1 : _page + 1; ultima = result.last;
      await service.marcarLida(conversaId!);
    } catch (e) { erro = e.toString(); }
    _notify();
  }
  bool enviar(String text) {
    final value = text.trim();
    if (!connected || enviando || conversaId == null || value.isEmpty || value.length > 4000) return false;
    try {
      realtime.send('/app/conversas/$conversaId/enviar', {'conteudo': value});
      _pending = value; enviando = true; erro = null;
      _timeout = Timer(const Duration(seconds: 15), () {
        enviando = false;
        erro = 'Sem confirmação do envio. Atualize o histórico antes de tentar novamente.';
        _notify();
      });
      _notify(); return true;
    } catch (e) { erro = e.toString(); _notify(); return false; }
  }
  @override
  void dispose() {
    _disposed = true; _timeout?.cancel(); realtime.dispose();
    ApiConfig.session.removeListener(_session); super.dispose();
  }
}