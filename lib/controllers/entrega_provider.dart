import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/entrega_ativa_model.dart';
import '../models/oferta_entrega_model.dart';
import '../models/rota_model.dart';
import '../models/entregador_cadastro_model.dart';
import '../models/status.dart';
import '../services/api_config.dart';
import '../services/api_client.dart';
import '../services/entregador_service.dart';
import '../services/location_service.dart';
import '../services/realtime_service.dart';

class EntregaProvider extends ChangeNotifier with WidgetsBindingObserver {
  final EntregadorService _service;
  final LocationService _location;
  final RealtimeService _realtime;
  final bool automatic;
  EntregaProvider({EntregadorService? service, LocationService? locationService,
    RealtimeService? realtime, this.automatic = true})
      : _service = service ?? EntregadorService(),
        _location = locationService ?? LocationService(),
        _realtime = realtime ?? RealtimeService() {
    ApiConfig.session.addListener(_sessionChanged);
    if (automatic) WidgetsBinding.instance.addObserver(this);
  }
  EntregadorCadastroModel? _perfil;
  EntregaAtivaModel? _entrega;
  RotaModel? _rota;
  final List<OfertaEntregaModel> _ofertas = [];
  bool _busy = false, _syncing = false, _gpsBusy = false, _disposed = false, _foreground = true;
  bool _changingStatus = false;
  bool inicializado = false;
  int _epoch = 0;
  String? erro, aviso, erroRota, erroLocalizacao;
  double? latitudeAtual, longitudeAtual;
  Timer? _refreshTimer, _gpsTimer, _clock;
  String? _pedidoTopic;
  StatusOperacional _status = StatusOperacional.offline;
  StatusOperacional get status => _status;
  bool get estaOnline => _status == StatusOperacional.online;
  bool get emEntrega => _status == StatusOperacional.emEntrega || _entrega != null;
  bool get isLoading => _busy;
  bool get isSyncing => _syncing;
  bool get isChangingStatus => _changingStatus;
  bool get isCadastrado => _perfil != null;
  bool get cadastroAtivo => _perfil?.ativo == true;
  EntregadorCadastroModel? get perfilEntregador => _perfil;
  EntregaAtivaModel? get entregaAtiva => _entrega;
  RotaModel? get rotaAtual => _rota;
  List<OfertaEntregaModel> get ofertas => List.unmodifiable(_ofertas);
  OfertaEntregaModel? get ofertaAtual => _ofertas.isEmpty ? null : _ofertas.first;
  int get segundosRestantes => ofertaAtual?.segundosEm(DateTime.now()) ?? 0;
  bool get entregaColetada => _entrega?.statusPedido == StatusPedido.saiuEntrega;
  bool get podeColetar => !_busy && _entrega?.statusPedido == StatusPedido.preparando;
  bool get podeConcluir => !_busy && entregaColetada;
  void _notify() { if (!_disposed) notifyListeners(); }
  bool _valid(int epoch) => !_disposed && epoch == _epoch;
  void _sessionChanged() {
    _epoch++; _stop();
    _perfil = null; _entrega = null; _rota = null; _ofertas.clear();
    _status = StatusOperacional.offline;
    _busy = false; _syncing = false; _gpsBusy = false; _changingStatus = false; inicializado = false;
    latitudeAtual = null; longitudeAtual = null;
    erro = null; aviso = null; erroRota = null; erroLocalizacao = null;
    _notify();
  }
  void _applyProfile(EntregadorCadastroModel? profile) {
    _perfil = profile;
    _status = profile == null ? StatusOperacional.offline : StatusOperacional.parse(profile.statusOperacional);
    if (profile != null &&
        profile.latitudeAtual != null &&
        profile.longitudeAtual != null &&
        profile.ultimaAtualizacaoLocalizacao != null &&
        DateTime.now().difference(profile.ultimaAtualizacaoLocalizacao!).inSeconds <= 120) {
      latitudeAtual = profile.latitudeAtual;
      longitudeAtual = profile.longitudeAtual;
    }
    if (!estaOnline || emEntrega || !cadastroAtivo) _ofertas.clear();
  }
  Future<void> verificarCadastro() => sincronizar();
  Future<void> sincronizar() async {
    if (_syncing || _busy || !ApiConfig.temSessaoSalva) return;
    _syncing = true;
    final epoch = _epoch;
    try {
      final profile = await _service.obterPerfil();
      if (!_valid(epoch)) return;
      _applyProfile(profile);
      if (profile?.ativo == true) {
        final active = await _service.obterEntregaAtiva();
        if (!_valid(epoch)) return;
        final previous = _entrega?.pedidoId;
        _entrega = active;
        if (active == null) {
          _rota = null;
          if (previous != null) aviso = 'A corrida foi encerrada. Seu status foi atualizado.';
        } else {
          _status = StatusOperacional.emEntrega; _ofertas.clear();
        }
        if (estaOnline && active == null) {
          final offers = await _service.buscarOfertasPendentes();
          if (!_valid(epoch)) return;
          _ofertas..clear()..addAll(offers.where((o) => !o.expirada));
        }
        _start();
        if (active != null && (_rota == null || _rota!.pedidoId != active.pedidoId)) {
          await carregarRota(active.pedidoId);
        }
      } else { _entrega = null; _rota = null; _stop(); }
      erro = null;
    } catch (e) { if (_valid(epoch)) erro = e.toString(); }
    finally { if (_valid(epoch)) { _syncing = false; inicializado = true; _notify(); } }
  }
  Future<EntregadorCadastroModel> cadastrarEntregador({
    required String cnh, required String placaVeiculo, required String tipoVeiculo,
    required String cpf, String? corVeiculo, String? modeloVeiculo,
  }) async {
    if (_busy) throw StateError('Aguarde a operação atual.');
    _busy = true; _notify();
    final epoch = _epoch;
    try {
      final profile = await _service.cadastrarEntregador(cnh: cnh, placaVeiculo: placaVeiculo,
        tipoVeiculo: tipoVeiculo, cpf: cpf, corVeiculo: corVeiculo, modeloVeiculo: modeloVeiculo);
      if (_valid(epoch)) { _applyProfile(profile); inicializado = true; }
      return profile;
    } finally { if (_valid(epoch)) { _busy = false; _notify(); } }
  }
  Future<void> atualizarVeiculo({required String tipoVeiculo, required String placaVeiculo,
    String? modeloVeiculo, String? corVeiculo}) => _atualizarPerfil(() =>
      _service.atualizarVeiculo(tipoVeiculo: tipoVeiculo, placaVeiculo: placaVeiculo,
        modeloVeiculo: modeloVeiculo, corVeiculo: corVeiculo));
  Future<void> atualizarDocumentos({required String cpf, required String cnh}) =>
      _atualizarPerfil(() => _service.atualizarDocumentos(cpf: cpf, cnh: cnh));
  Future<void> atualizarDadosBancarios({required String tipoChavePix, required String chavePix}) =>
      _atualizarPerfil(() => _service.atualizarDadosBancarios(
        tipoChavePix: tipoChavePix, chavePix: chavePix));
  Future<void> _atualizarPerfil(Future<EntregadorCadastroModel> Function() salvar) async {
    if (_busy || _syncing || !isCadastrado) throw StateError('Aguarde o carregamento do perfil.');
    _busy = true; _notify();
    final epoch = _epoch;
    try {
      final profile = await salvar();
      if (!_valid(epoch)) return;
      _applyProfile(profile);
    } finally {
      if (_valid(epoch)) { _busy = false; _notify(); }
    }
  }
  Future<void> alternarStatusOnline(bool online) async {
    if (_busy || _syncing || emEntrega || !cadastroAtivo) return;
    _busy = true; _changingStatus = true; erro = null; _notify();
    final epoch = _epoch;
    try {
      if (online && !await atualizarLocalizacao(solicitar: true)) return;
      if (!_valid(epoch)) return;
      final profile = await _service.atualizarStatus(online ? StatusOperacional.online : StatusOperacional.offline);
      if (!_valid(epoch)) return;
      _applyProfile(profile); _start();
    } catch (e) { if (_valid(epoch)) erro = e.toString(); }
    finally { if (_valid(epoch)) { _busy = false; _changingStatus = false; _notify(); } }
    if (_valid(epoch) && _foreground) await sincronizar();
  }
  Future<bool> atualizarLocalizacao({bool solicitar = false}) async {
    if (_gpsBusy || !_foreground) return false;
    _gpsBusy = true;
    final epoch = _epoch;
    try {
      final permission = await _location.solicitarPermissao(request: solicitar);
      if (permission != null) throw StateError(permission);
      final position = await _location.obterPosicaoAtual();
      if (position == null) throw StateError('Localização indisponível. Ative o GPS e tente novamente.');
      if (!_valid(epoch) || !_foreground) return false;
      if (DateTime.now().difference(position.timestamp).inSeconds > 60) {
        throw StateError('A localização está desatualizada. Tente novamente.');
      }
      await _service.enviarLocalizacao(position.latitude, position.longitude);
      if (!_valid(epoch)) return false;
      latitudeAtual = position.latitude; longitudeAtual = position.longitude;
      erroLocalizacao = null; return true;
    } catch (e) {
      if (_valid(epoch)) erroLocalizacao = e.toString().replaceFirst('Bad state: ', '');
      return false;
    } finally { if (_valid(epoch)) { _gpsBusy = false; _notify(); } }
  }
  void receberOferta(OfertaEntregaModel offer) {
    if (!estaOnline || emEntrega || !cadastroAtivo || offer.expirada) return;
    _ofertas.removeWhere((o) => o.id == offer.id || o.expirada);
    _ofertas.add(offer); _notify();
  }
  void _start() {
    if (!automatic || !_foreground || !cadastroAtivo) return;
    // A oferta tem prazo curto; a consulta periódica recupera mensagens
    // perdidas quando o WebSocket cai ou o app volta ao primeiro plano.
    _refreshTimer ??= Timer.periodic(const Duration(seconds: 10), (_) => sincronizar());
    _clock ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (_ofertas.isNotEmpty) { _ofertas.removeWhere((o) => o.expirada); _notify(); }
    });
    if (estaOnline || emEntrega) {
      _gpsTimer ??= Timer.periodic(const Duration(seconds: 30), (_) => atualizarLocalizacao());
    } else { _gpsTimer?.cancel(); _gpsTimer = null; }
    _realtime.onConnected = () => sincronizar();
    _realtime.listen('/topic/entregador/${_perfil!.id}/ofertas', (body) {
      try { receberOferta(OfertaEntregaModel.fromJson(jsonDecode(body))); }
      catch (_) { erro = 'Oferta inválida recebida. Atualize a lista.'; _notify(); }
    });
    final topic = _entrega == null ? null : '/topic/pedidos/${_entrega!.pedidoId}/status';
    if (topic != _pedidoTopic) {
      if (_pedidoTopic != null) _realtime.unlisten(_pedidoTopic!);
      _pedidoTopic = topic;
      if (topic != null) {
        _realtime.listen(topic, (body) {
        final state = StatusPedido.parse(body.replaceAll('"', ''));
        if (state == StatusPedido.cancelado || state == StatusPedido.entregue) {
          _entrega = null; _rota = null; _ofertas.clear();
          aviso = state == StatusPedido.cancelado ? 'O pedido foi cancelado.' : 'Entrega concluída.';
          _notify();
        }
        sincronizar();
      });
      }
    }
    _realtime.connect();
  }
  Future<bool> aceitarOfertaAtual() async =>
    ofertaAtual == null ? false : aceitarOferta(ofertaAtual!.id);
  Future<bool> aceitarOferta(String id) async {
    final matches = _ofertas.where((o) => o.id == id);
    if (_busy || _syncing || !estaOnline || emEntrega || matches.isEmpty || matches.first.expirada) return false;
    return _action(() async {
      final epoch = _epoch;
      final active = await _service.aceitarOferta(id);
      if (!_valid(epoch)) return;
      _entrega = active; _status = StatusOperacional.emEntrega;
      _ofertas.clear(); _start(); await carregarRota(active.pedidoId);
    }, onError: (e) {
      if (e is ApiException && [400, 404, 409, 422].contains(e.status)) {
        _ofertas.removeWhere((o) => o.id == id);
        aviso = 'Esta oferta não está mais disponível. Ela pode ter expirado ou sido aceita por outro entregador.';
      }
    });
  }
  Future<void> recusarOfertaAtual() async {
    if (ofertaAtual != null) await recusarOferta(ofertaAtual!.id);
  }
  Future<bool> recusarOferta(String id) async {
    if (_busy || emEntrega) return false;
    return _action(() async {
      final epoch = _epoch;
      await _service.recusarOferta(id);
      if (_valid(epoch)) _ofertas.removeWhere((o) => o.id == id);
    });
  }
  Future<void> carregarEntregaAtiva() => sincronizar();
  Future<void> carregarRota(String id) async {
    final epoch = _epoch;
    try {
      final route = await _service.obterRota(id);
      if (_valid(epoch) && _entrega?.pedidoId == id) { _rota = route; erroRota = null; }
    } catch (e) { if (_valid(epoch)) erroRota = e.toString(); }
    _notify();
  }
  Future<bool> confirmarColeta() async {
    if (!podeColetar) return false;
    final id = _entrega!.pedidoId;
    return _action(() async {
      final epoch = _epoch;
      final active = await _service.coletarPedido(id);
      if (_valid(epoch)) _entrega = active;
    });
  }
  Future<bool> concluirEntregaAtual() async {
    if (!podeConcluir) return false;
    final id = _entrega!.pedidoId;
    return _action(() async {
      final epoch = _epoch;
      await _service.concluirEntrega(id);
      if (!_valid(epoch)) return;
      _entrega = null; _rota = null; _status = StatusOperacional.online;
      aviso = 'Entrega concluída!'; _start();
    });
  }
  Future<bool> _action(Future<void> Function() operation, {void Function(Object)? onError}) async {
    _busy = true; erro = null; aviso = null; _notify();
    final epoch = _epoch;
    var success = false;
    try { await operation(); success = _valid(epoch); }
    catch (e) { if (_valid(epoch)) { erro = e.toString(); onError?.call(e); } }
    finally { if (_valid(epoch)) { _busy = false; _notify(); } }
    if (!success && _valid(epoch)) {
      final message = erro;
      await sincronizar();
      if (_valid(epoch)) { erro = message; _notify(); }
    }
    return success;
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _foreground = true; sincronizar();
      if (estaOnline || emEntrega) atualizarLocalizacao();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _foreground = false; _stop();
      if (estaOnline) alternarStatusOnline(false);
    }
  }
  void _stop() {
    _refreshTimer?.cancel(); _refreshTimer = null;
    _gpsTimer?.cancel(); _gpsTimer = null;
    _clock?.cancel(); _clock = null;
    _realtime.dispose(); _pedidoTopic = null;
  }
  Future<void> sair() async {
    if (estaOnline) await alternarStatusOnline(false);
    await ApiConfig.limparSessao();
  }
  @override
  void dispose() {
    _disposed = true; _epoch++; _stop();
    ApiConfig.session.removeListener(_sessionChanged);
    if (automatic) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
