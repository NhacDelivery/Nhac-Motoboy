import '../services/push_service.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

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
  final Duration offlineRetryDelay;
  EntregaProvider({
    EntregadorService? service,
    LocationService? locationService,
    RealtimeService? realtime,
    this.automatic = true,
    this.offlineRetryDelay = const Duration(seconds: 1),
  }) : _service = service ?? EntregadorService(),
       _location = locationService ?? LocationService(),
       _realtime = realtime ?? RealtimeService() {
    ApiConfig.session.addListener(_sessionChanged);
    if (automatic) WidgetsBinding.instance.addObserver(this);
  }
  EntregadorCadastroModel? _perfil;
  EntregaAtivaModel? _entrega;
  RotaModel? _rota;
  final List<OfertaEntregaModel> _ofertas = [];
  final List<({DateTime hora, String texto})> _avisosRecentes = [];
  List<({DateTime hora, String texto})> get avisosRecentes =>
      List.unmodifiable(_avisosRecentes);
  void _registrarAviso(String texto) {
    _avisosRecentes.insert(0, (hora: DateTime.now(), texto: texto));
    if (_avisosRecentes.length > 20) _avisosRecentes.removeLast();
    _notify();
  }

  bool _busy = false,
      _syncing = false,
      _gpsBusy = false,
      _disposed = false,
      _foreground = true;
  bool _changingStatus = false, _pendingOffline = false;
  String? _routeLoadingFor;
  int _routeRequestVersion = 0;
  Future<bool>? _offlineOperation;
  String? _routeRequestedFor;
  bool erroRotaDados = false;
  DateTime? ultimaLocalizacaoEm, ultimaSincronizacaoEm;
  int entregasConcluidasRevision = 0;
  bool inicializado = false;
  int _epoch = 0;
  int _availabilityVersion = 0;
  String? erro, aviso, erroRota, erroLocalizacao, avisoConexao;
  double? latitudeAtual, longitudeAtual;
  Timer? _refreshTimer, _gpsTimer, _clock;
  StreamSubscription<Position>? _deliveryGps;
  String? _pedidoTopic;
  Duration? _refreshInterval;
  bool _lastFresh = false;
  ApiException? erroConclusao;
  StatusOperacional _status = StatusOperacional.offline;
  StatusOperacional get status => _status;
  bool get estaOnline => _status == StatusOperacional.online;
  bool get emEntrega =>
      _status == StatusOperacional.emEntrega || _entrega != null;
  bool get isLoading => _busy;
  bool get isSyncing => _syncing;
  bool get isChangingStatus => _changingStatus;
  bool get localizacaoRecente =>
      ultimaLocalizacaoEm != null &&
      DateTime.now().difference(ultimaLocalizacaoEm!).inSeconds <= 120 &&
      erroLocalizacao == null;
  bool get isCadastrado => _perfil != null;
  bool get cadastroAtivo => _perfil?.ativo == true;
  EntregadorCadastroModel? get perfilEntregador => _perfil;
  EntregaAtivaModel? get entregaAtiva => _entrega;
  RotaModel? get rotaAtual => _rota;
  List<OfertaEntregaModel> get ofertas => List.unmodifiable(_ofertas);
  String? ofertaSelecionadaId;
  Future<void> selecionarOferta(String id) async {
    final epoch = _epoch;
    try {
      final novas = await _service.buscarOfertasPendentes();
      if (!_valid(epoch)) return;
      _ofertas
        ..clear()
        ..addAll(novas.where((o) => !o.expirada));
      ofertaSelecionadaId = _ofertas.any((o) => o.id == id) ? id : null;
      if (ofertaSelecionadaId == null) {
        aviso = 'Esta oferta não está mais disponível.';
      }
      _notify();
    } catch (e) {
      if (_valid(epoch)) {
        erro = e.toString();
        _notify();
      }
    }
  }

  OfertaEntregaModel? get ofertaAtual => _ofertas.isEmpty
      ? null
      : _ofertas.firstWhere(
          (o) => o.id == ofertaSelecionadaId,
          orElse: () => _ofertas.first,
        );
  int get segundosRestantes => ofertaAtual?.segundosEm(DateTime.now()) ?? 0;
  bool get entregaColetada =>
      _entrega?.statusPedido == StatusPedido.saiuEntrega;
  bool get podeColetar =>
      !_busy && _entrega?.statusPedido == StatusPedido.preparando;
  bool get podeConcluir => !_busy && entregaColetada;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  bool _valid(int epoch) => !_disposed && epoch == _epoch;
  void _sessionChanged() {
    _epoch++;
    _availabilityVersion++;
    _stop();
    _perfil = null;
    _entrega = null;
    _rota = null;
    ofertaSelecionadaId = null;
    _ofertas.clear();
    _avisosRecentes.clear();
    _status = StatusOperacional.offline;
    _busy = false;
    _syncing = false;
    _gpsBusy = false;
    _changingStatus = false;
    inicializado = false;
    _pendingOffline = false;
    _routeRequestedFor = null;
    _routeLoadingFor = null;
    latitudeAtual = null;
    longitudeAtual = null;
    ultimaLocalizacaoEm = null;
    ultimaSincronizacaoEm = null;
    erro = null;
    aviso = null;
    erroRota = null;
    erroLocalizacao = null;
    erroConclusao = null;
    avisoConexao = null;
    _notify();
  }

  void _applyProfile(EntregadorCadastroModel? profile) {
    _perfil = profile;
    _status = profile == null
        ? StatusOperacional.offline
        : StatusOperacional.parse(profile.statusOperacional);
    if (profile != null &&
        profile.latitudeAtual != null &&
        profile.longitudeAtual != null) {
      final timestamp = profile.ultimaAtualizacaoLocalizacao;
      if (timestamp != null &&
          (ultimaLocalizacaoEm == null ||
              timestamp.isAfter(ultimaLocalizacaoEm!))) {
        latitudeAtual = profile.latitudeAtual;
        longitudeAtual = profile.longitudeAtual;
        ultimaLocalizacaoEm = timestamp;
      }
    }
    if (!estaOnline || emEntrega || !cadastroAtivo) _ofertas.clear();
  }

  Future<void> verificarCadastro() => sincronizar();
  Future<void> sincronizar() async {
    if (_syncing || _busy || _pendingOffline || !ApiConfig.temSessaoSalva) {
      return;
    }
    _syncing = true;
    final epoch = _epoch;
    final availabilityVersion = _availabilityVersion;
    try {
      final state = await _service.obterEstado();
      final profile = state.perfil;
      if (!_valid(epoch) ||
          _busy ||
          _pendingOffline ||
          availabilityVersion != _availabilityVersion) {
        return;
      }
      _applyProfile(profile);
      if (profile?.ativo == true) {
        final active = state.entrega;
        if (!_valid(epoch) ||
            _busy ||
            _pendingOffline ||
            availabilityVersion != _availabilityVersion) {
          return;
        }
        final previous = _entrega?.pedidoId;
        final previousRoute = _routeKey;
        _entrega = active;
        if (previousRoute != _routeKey) {
          _rota = null;
          _routeRequestedFor = null;
          erroRota = null;
          erroRotaDados = false;
        }
        if (active == null) {
          _rota = null;
          _routeRequestedFor = null;
          erroRota = null;
          erroRotaDados = false;
          if (previous != null) {
            aviso = 'A corrida foi encerrada. Seu status foi atualizado.';
            entregasConcluidasRevision++;
            EntregadorService.invalidarConsultas();
          }
        } else {
          _status = StatusOperacional.emEntrega;
          _ofertas.clear();
        }
        if (estaOnline && active == null) {
          final offers = state.ofertas;
          if (!_valid(epoch) ||
              _busy ||
              _pendingOffline ||
              availabilityVersion != _availabilityVersion) {
            return;
          }
          _ofertas
            ..clear()
            ..addAll(offers.where((o) => !o.expirada));
        }
        _start();
        if (active != null &&
            (_rota == null || _rota!.pedidoId != active.pedidoId)) {
          await carregarRota(active.pedidoId);
        }
      } else {
        _entrega = null;
        _rota = null;
        _stop();
      }
      ultimaSincronizacaoEm = DateTime.now();
      erro = null;
    } catch (e) {
      if (_valid(epoch) && availabilityVersion == _availabilityVersion) {
        erro = e.toString();
      }
    } finally {
      if (_valid(epoch)) {
        _syncing = false;
        inicializado = true;
        _notify();
      }
    }
  }

  Future<EntregadorCadastroModel> cadastrarEntregador({
    required String cnh,
    required String placaVeiculo,
    required String tipoVeiculo,
    required String cpf,
    String? corVeiculo,
    String? modeloVeiculo,
  }) async {
    if (_busy) throw StateError('Aguarde a operação atual.');
    _busy = true;
    _notify();
    final epoch = _epoch;
    try {
      final profile = await _service.cadastrarEntregador(
        cnh: cnh,
        placaVeiculo: placaVeiculo,
        tipoVeiculo: tipoVeiculo,
        cpf: cpf,
        corVeiculo: corVeiculo,
        modeloVeiculo: modeloVeiculo,
      );
      if (_valid(epoch)) {
        _applyProfile(profile);
        inicializado = true;
      }
      return profile;
    } finally {
      if (_valid(epoch)) {
        _busy = false;
        _notify();
      }
    }
  }

  Future<void> atualizarVeiculo({
    required String tipoVeiculo,
    required String placaVeiculo,
    String? modeloVeiculo,
    String? corVeiculo,
    String? cnh,
  }) => _atualizarPerfil(
    () => _service.atualizarVeiculo(
      tipoVeiculo: tipoVeiculo,
      placaVeiculo: placaVeiculo,
      modeloVeiculo: modeloVeiculo,
      corVeiculo: corVeiculo,
      cnh: cnh,
    ),
  );
  Future<void> atualizarDocumentos({
    required String cpf,
    required String cnh,
  }) =>
      _atualizarPerfil(() => _service.atualizarDocumentos(cpf: cpf, cnh: cnh));
  Future<void> atualizarDadosBancarios({
    required String tipoChavePix,
    required String chavePix,
  }) => _atualizarPerfil(
    () => _service.atualizarDadosBancarios(
      tipoChavePix: tipoChavePix,
      chavePix: chavePix,
    ),
  );
  Future<void> _atualizarPerfil(
    Future<EntregadorCadastroModel> Function() salvar,
  ) async {
    if (_busy || !isCadastrado) {
      throw StateError('Aguarde o carregamento do perfil.');
    }
    // Descarta a resposta da consulta periódica que começou antes da edição.
    _availabilityVersion++;
    _busy = true;
    _notify();
    final epoch = _epoch;
    try {
      final profile = await salvar();
      if (!_valid(epoch)) return;
      _applyProfile(profile);
    } finally {
      if (_valid(epoch)) {
        _busy = false;
        _notify();
      }
    }
  }

  Future<void> alternarStatusOnline(bool online) async {
    if (!online) {
      await _ficarOffline();
      return;
    }
    if (_busy || _pendingOffline || emEntrega || !cadastroAtivo) return;
    _busy = true;
    _changingStatus = true;
    erro = null;
    _notify();
    final epoch = _epoch;
    try {
      if (online && !await atualizarLocalizacao(solicitar: true)) return;
      if (!_valid(epoch)) return;
      final profile = await _service.atualizarStatus(
        online ? StatusOperacional.online : StatusOperacional.offline,
      );
      if (!_valid(epoch)) return;
      _applyProfile(profile);
      _start();
    } catch (e) {
      if (_valid(epoch)) erro = e.toString();
    } finally {
      if (_valid(epoch)) {
        _busy = false;
        _changingStatus = false;
        _notify();
      }
    }
    if (_valid(epoch) && !_foreground && estaOnline) {
      await _ficarOffline();
    }
    if (_valid(epoch) && _foreground) await sincronizar();
  }

  Future<bool> _ficarOffline() =>
      _offlineOperation ??= _enviarOffline().whenComplete(() {
        _offlineOperation = null;
      });
  Future<bool> _enviarOffline() async {
    if (!estaOnline) return true;
    _availabilityVersion++;
    _pendingOffline = true;
    _changingStatus = true;
    _notify();
    final epoch = _epoch;
    try {
      for (var attempt = 0; attempt < 3; attempt++) {
        if (!_valid(epoch) || emEntrega) return false;
        try {
          final profile = await _service.atualizarStatus(
            StatusOperacional.offline,
          );
          if (!_valid(epoch)) return false;
          _applyProfile(profile);
          erro = null;
          return true;
        } catch (e) {
          if (_valid(epoch)) {
            erro = 'Não foi possível confirmar o status offline: $e';
          }
          if (attempt < 2) {
            await Future<void>.delayed(offlineRetryDelay * (attempt + 1));
          }
        }
      }
      return false;
    } finally {
      if (_valid(epoch)) {
        _pendingOffline = false;
        _changingStatus = false;
        _notify();
      }
    }
  }

  Future<bool> atualizarLocalizacao({bool solicitar = false}) async {
    if (_gpsBusy || !_foreground) return false;
    _gpsBusy = true;
    final epoch = _epoch;
    try {
      final permission = await _location.solicitarPermissao(request: solicitar);
      if (permission != null) throw StateError(permission);
      final position = await _location.obterPosicaoAtual(emEntrega: emEntrega);
      if (position == null) {
        throw StateError(
          'Localização indisponível. Ative o GPS e tente novamente.',
        );
      }
      if (!_valid(epoch) || !_foreground) return false;
      if (DateTime.now().difference(position.timestamp).inSeconds > 60) {
        throw StateError('A localização está desatualizada. Tente novamente.');
      }
      await _service.enviarLocalizacao(position.latitude, position.longitude);
      if (!_valid(epoch)) return false;
      latitudeAtual = position.latitude;
      longitudeAtual = position.longitude;
      ultimaLocalizacaoEm = position.timestamp;
      erroLocalizacao = null;
      return true;
    } catch (e) {
      if (_valid(epoch)) {
        erroLocalizacao = e.toString().replaceFirst('Bad state: ', '');
      }
      return false;
    } finally {
      if (_valid(epoch)) {
        _gpsBusy = false;
        _notify();
      }
    }
  }

  void receberOferta(OfertaEntregaModel offer) {
    if (!estaOnline || emEntrega || !cadastroAtivo || offer.expirada) return;
    final nova = !_ofertas.any((o) => o.id == offer.id);
    _ofertas.removeWhere((o) => o.id == offer.id || o.expirada);
    _ofertas.add(offer);
    _notify();
    if (nova) {
      _registrarAviso(
        'Nova oferta de ${offer.lojaNome}. Abra o início para responder.',
      );
    }
  }

  void _updateDeliveryGps() {
    if (automatic &&
        emEntrega &&
        _location.suportaSegundoPlano &&
        _foreground) {
      final epoch = _epoch;
      _deliveryGps ??= _location.streamDePosicao().listen(
        (position) {
          if (_valid(epoch) && emEntrega) {
            unawaited(_enviarPosicao(position, epoch));
          }
        },
        onError: (Object error) {
          if (!_valid(epoch)) return;
          erroLocalizacao = 'Não foi possível acompanhar o GPS. Abra o app e atualize sua localização.';
          _notify();
        },
      );
    } else if (!emEntrega) {
      unawaited(_deliveryGps?.cancel());
      _deliveryGps = null;
    }
  }

  Future<void> _enviarPosicao(Position position, int epoch) async {
    if (_gpsBusy || !_valid(epoch) || !emEntrega) return;
    if (DateTime.now().difference(position.timestamp).inSeconds > 60) return;
    _gpsBusy = true;
    try {
      await _service.enviarLocalizacao(position.latitude, position.longitude);
      if (!_valid(epoch)) return;
      latitudeAtual = position.latitude;
      longitudeAtual = position.longitude;
      ultimaLocalizacaoEm = position.timestamp;
      erroLocalizacao = null;
    } catch (e) {
      if (_valid(epoch)) erroLocalizacao = e.toString();
    } finally {
      if (_valid(epoch)) {
        _gpsBusy = false;
        _notify();
      }
    }
  }

  void _start() {
    _updateDeliveryGps();
    if (!automatic || !_foreground || !cadastroAtivo) return;
    // A oferta tem prazo curto; a consulta periódica recupera mensagens
    // perdidas quando o WebSocket cai ou o app volta ao primeiro plano.
    // Socket entrega eventos imediatamente; polling recupera perdas.
    final interval = Duration(
      seconds: estaOnline || emEntrega ? (_realtime.connected ? 30 : 10) : 60,
    );
    if (_refreshInterval != interval || _refreshTimer == null) {
      _refreshTimer?.cancel();
      _refreshInterval = interval;
      _refreshTimer = Timer.periodic(interval, (_) => sincronizar());
    }
    _clock ??= Timer.periodic(const Duration(seconds: 1), (_) {
      final before = _ofertas.length;
      _ofertas.removeWhere((o) => o.expirada);
      final fresh = localizacaoRecente;
      if (before != _ofertas.length || fresh != _lastFresh) {
        _lastFresh = fresh;
        _notify();
      }
    });
    if ((estaOnline || emEntrega) && _deliveryGps == null) {
      _gpsTimer ??= Timer.periodic(
        const Duration(seconds: 30),
        (_) => atualizarLocalizacao(),
      );
    } else {
      _gpsTimer?.cancel();
      _gpsTimer = null;
    }
    final connectionEpoch = _epoch;
    _realtime.onConnected = () {
      if (!_valid(connectionEpoch)) return;
      avisoConexao = null;
      _notify();
      sincronizar();
    };
    void disconnected() {
      if (!_foreground || !_valid(connectionEpoch)) return;
      avisoConexao = 'Atualizações em tempo real indisponíveis. As corridas continuam sendo consultadas automaticamente.';
      // Recalcula o intervalo de recuperação sem esperar o próximo polling.
      _start();
      _notify();
    }

    _realtime.onDisconnected = disconnected;
    _realtime.onError = (_) => disconnected();
    _realtime.listen('/topic/entregador/${_perfil!.id}/ofertas', (body) {
      try {
        receberOferta(OfertaEntregaModel.fromJson(jsonDecode(body)));
      } catch (_) {
        erro = 'Oferta inválida recebida. Atualize a lista.';
        _notify();
      }
    });
    final topic = _entrega == null
        ? null
        : '/topic/pedidos/${_entrega!.pedidoId}/status';
    if (topic != _pedidoTopic) {
      if (_pedidoTopic != null) _realtime.unlisten(_pedidoTopic!);
      _pedidoTopic = topic;
      if (topic != null) {
        _realtime.listen(topic, (body) {
          final state = StatusPedido.parse(body.replaceAll('"', ''));
          if (state == StatusPedido.cancelado ||
              state == StatusPedido.entregue) {
            final haviaEntrega = _entrega != null;
            _entrega = null;
            _rota = null;
            _ofertas.clear();
            if (haviaEntrega) entregasConcluidasRevision++;
            EntregadorService.invalidarConsultas();
            aviso = state == StatusPedido.cancelado
                ? 'O pedido foi cancelado.'
                : 'Entrega concluída.';
            _registrarAviso(aviso!);
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
    if (_busy ||
        _pendingOffline ||
        !estaOnline ||
        emEntrega ||
        matches.isEmpty ||
        matches.first.expirada) {
      return false;
    }
    return _action(
      () async {
        final epoch = _epoch;
        final active = await _service.aceitarOferta(id);
        if (!_valid(epoch)) return;
        _entrega = active;
        _status = StatusOperacional.emEntrega;
        _ofertas.clear();
        _start();
        _notify();
        // A rota é acessória: o aceite confirmado deve abrir a corrida imediatamente.
        unawaited(carregarRota(active.pedidoId));
      },
      onError: (e) {
        if (e is ApiException && [400, 404, 409, 422].contains(e.status)) {
          _ofertas.removeWhere((o) => o.id == id);
          aviso = 'Esta oferta não está mais disponível. Ela pode ter expirado ou sido aceita por outro entregador.';
        }
      },
    );
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
  // O backend troca o destino da loja para o cliente após a coleta e
  // recalcula a rota quando as coordenadas do pedido são corrigidas.
  String? get _routeKey => _entrega == null
      ? null
      : jsonEncode([
          _entrega!.pedidoId,
          _entrega!.statusPedido.api,
          _entrega!.lojaLatitude,
          _entrega!.lojaLongitude,
          _entrega!.entregaLatitude,
          _entrega!.entregaLongitude,
        ]);

  Future<void> carregarRota(String id, {bool tentarNovamente = false}) async {
    final key = _routeKey;
    if (key == null ||
        _entrega?.pedidoId != id ||
        _routeLoadingFor == key ||
        (!tentarNovamente && _routeRequestedFor == key))
      return;
    _routeLoadingFor = key;
    _routeRequestedFor = key;
    final version = ++_routeRequestVersion;
    final epoch = _epoch;
    bool current() =>
        _valid(epoch) && version == _routeRequestVersion && _routeKey == key;
    try {
      final route = await _service.obterRota(id);
      if (current()) {
        _rota = route;
        erroRota = null;
        erroRotaDados = false;
      }
    } catch (e) {
      if (current()) {
        erroRota = e.toString();
        erroRotaDados = e is ApiException && e.status == 422;
      }
    } finally {
      if (_valid(epoch) && version == _routeRequestVersion) {
        _routeLoadingFor = null;
        _notify();
      }
    }
  }

  Future<void> corrigirDestino(double latitude, double longitude) async {
    final active = _entrega;
    final epoch = _epoch;
    if (active == null) throw StateError('Sem corrida ativa.');
    await _service.corrigirDestino(active.pedidoId, latitude, longitude);
    if (!_valid(epoch)) return;
    await sincronizar();
    if (!_valid(epoch)) return;
    await carregarRota(active.pedidoId, tentarNovamente: true);
  }

  Future<bool> confirmarColeta() async {
    if (!podeColetar) return false;
    final id = _entrega!.pedidoId;
    return _action(() async {
      final epoch = _epoch;
      final active = await _service.coletarPedido(id);
      if (_valid(epoch)) {
        _entrega = active;
        _rota = null;
        _routeRequestedFor = null;
        await carregarRota(id, tentarNovamente: true);
      }
    });
  }

  Future<bool> concluirEntregaAtual({required String codigo}) async {
    if (!podeConcluir) return false;
    erroConclusao = null;
    if (!RegExp(r'^\d{4}$').hasMatch(codigo.trim())) {
      erro = 'Informe os quatro números do código de entrega.';
      _notify();
      return false;
    }
    final id = _entrega!.pedidoId;
    return _action(
      () async {
        final epoch = _epoch;
        await _service.concluirEntrega(id, codigo: codigo);
        if (!_valid(epoch)) return;
        _entrega = null;
        _rota = null;
        _routeRequestedFor = null;
        entregasConcluidasRevision++;
        EntregadorService.invalidarConsultas();
        _status = StatusOperacional.online;
        aviso = 'Entrega concluída!';
        _start();
        if (!_foreground) unawaited(_ficarOffline());
        _registrarAviso(aviso!);
      },
      onError: (e) {
        if (e is ApiException) erroConclusao = e;
      },
    );
  }

  Future<bool> _action(
    Future<void> Function() operation, {
    void Function(Object)? onError,
  }) async {
    _busy = true;
    erro = null;
    aviso = null;
    _notify();
    final epoch = _epoch;
    var success = false;
    try {
      await operation();
      success = _valid(epoch);
    } catch (e) {
      if (_valid(epoch)) {
        erro = e.toString();
        onError?.call(e);
      }
    } finally {
      if (_valid(epoch)) {
        _busy = false;
        _notify();
      }
    }
    if (!success && _valid(epoch)) {
      final message = erro;
      await sincronizar();
      if (_valid(epoch)) {
        erro = message;
        _notify();
      }
    }
    return success;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _foreground = true;
      if (_pendingOffline ||
          (estaOnline && erro?.contains('status offline') == true)) {
        unawaited(_ficarOffline().then((_) => sincronizar()));
      } else {
        sincronizar();
      }
      if (estaOnline || emEntrega) atualizarLocalizacao();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _foreground = false;
      _stop(preservarGps: emEntrega && state == AppLifecycleState.paused);
      if (estaOnline) unawaited(_ficarOffline());
    }
  }

  void _stop({bool preservarGps = false}) {
    if (!preservarGps) {
      unawaited(_deliveryGps?.cancel());
      _deliveryGps = null;
    }
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _refreshInterval = null;
    _gpsTimer?.cancel();
    _gpsTimer = null;
    _clock?.cancel();
    _clock = null;
    _realtime.dispose();
    _pedidoTopic = null;
  }

  Future<void> sair() async {
    if (emEntrega) {
      throw StateError(
        'Conclua a corrida ou peça ajuda antes de sair da conta.',
      );
    }
    if (estaOnline && !await _ficarOffline()) {
      throw StateError(
        'Não foi possível ficar offline no servidor. Verifique a conexão e tente sair novamente.',
      );
    }
    await PushService.shared.encerrar();
    await ApiConfig.limparSessao();
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    _stop();
    ApiConfig.session.removeListener(_sessionChanged);
    if (automatic) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
