import 'dart:io';
import 'package:flutter/foundation.dart';
import '../services/user_service.dart';
import '../services/api_config.dart';

class UserProvider extends ChangeNotifier {
  final UserService service;
  UserProvider({UserService? service}) : service = service ?? UserService() {
    ApiConfig.session.addListener(_sessionChanged);
  }
  String usuarioId = '', nome = '', email = '', telefone = '';
  String? fotoPerfil, erro;
  bool isLoading = false;
  int _generation = 0;
  bool _disposed = false;
  int _requestVersion = 0;
  Future<void>? _loadingFuture;
  DateTime? _loadedAt;
  void _sessionChanged() {
    _generation++;
    _requestVersion++;
    _loadingFuture = null;
    _loadedAt = null;
    limparUsuario();
  }

  Future<void> carregarDadosReais({bool force = false}) {
    if (!force &&
        _loadedAt != null &&
        DateTime.now().difference(_loadedAt!) < const Duration(minutes: 3)) {
      return Future.value();
    }
    if (!force && _loadingFuture != null) return _loadingFuture!;
    final requestVersion = ++_requestVersion;
    late final Future<void> operation;
    operation = _carregar(requestVersion).whenComplete(() {
      if (identical(_loadingFuture, operation)) _loadingFuture = null;
    });
    _loadingFuture = operation;
    return operation;
  }

  Future<void> _carregar(int requestVersion) async {
    final generation = _generation;
    isLoading = true;
    erro = null;
    notifyListeners();
    try {
      final data = await service.obterUsuario();
      final id = data['id']?.toString() ?? '';
      if (_disposed ||
          generation != _generation ||
          requestVersion != _requestVersion) {
        return;
      }
      usuarioId = id;
      nome = data['nome'] ?? '';
      email = data['email'] ?? '';
      telefone = data['telefone'] ?? '';
      fotoPerfil = data['imagemUrl'];
      _loadedAt = DateTime.now();
    } catch (e) {
      if (!_disposed &&
          generation == _generation &&
          requestVersion == _requestVersion) {
        erro = e.toString();
      }
    } finally {
      if (!_disposed &&
          generation == _generation &&
          requestVersion == _requestVersion) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> atualizarNome(String nome) => atualizar({'nome': nome.trim()});
  Future<void> atualizarEmail(String email) =>
      atualizar({'email': email.trim()});
  Future<void> atualizarTelefone(String telefone) =>
      atualizar({'telefone': telefone.trim()});
  Future<void> atualizar(Map<String, dynamic> fields) async {
    final generation = _generation;
    _requestVersion++;
    _loadedAt = null;
    _loadingFuture = null;
    try {
      await service.atualizar(fields);
      if (_disposed || generation != _generation) return;
      await carregarDadosReais(force: true);
    } finally {
      if (!_disposed && generation == _generation) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> atualizarSenha(String atual, String nova) =>
      service.alterarSenha(atual, nova);
  Future<void> atualizarFotoPerfil(File imagem) async {
    if (usuarioId.isEmpty) {
      throw StateError('Carregue seu perfil antes de salvar a foto.');
    }
    final generation = _generation;
    final owner = usuarioId;
    final url = await service.enviarFotoPerfil(imagem);
    if (_disposed || generation != _generation || usuarioId != owner) return;
    await service.atualizar({'imagemUrl': url});
    if (_disposed || generation != _generation || usuarioId != owner) return;
    _requestVersion++;
    _loadedAt = null;
    fotoPerfil = url;
    notifyListeners();
  }

  void setUsuario({
    String? id,
    String? nome,
    String? email,
    String? telefone,
    String? foto,
  }) {
    usuarioId = id ?? usuarioId;
    this.nome = nome ?? this.nome;
    this.email = email ?? this.email;
    this.telefone = telefone ?? this.telefone;
    fotoPerfil = foto ?? fotoPerfil;
    notifyListeners();
  }

  void limparUsuario() {
    _loadedAt = null;
    _requestVersion++;
    _loadingFuture = null;
    usuarioId = '';
    nome = '';
    email = '';
    telefone = '';
    fotoPerfil = null;
    erro = null;
    isLoading = false;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    ApiConfig.session.removeListener(_sessionChanged);
    super.dispose();
  }
}
