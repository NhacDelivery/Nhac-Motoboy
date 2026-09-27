import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  void _sessionChanged() {
    _generation++;
    if (!ApiConfig.temSessaoSalva) limparUsuario();
  }
  Future<void> carregarDadosReais() async {
    final generation = _generation;
    isLoading = true; erro = null; notifyListeners();
    try {
      final data = await service.obterUsuario();
      final id = data['id']?.toString() ?? '';
      final prefs = await SharedPreferences.getInstance();
      final localPath = id.isEmpty ? null : prefs.getString('motoboy_profile_photo_$id');
      final localPhoto = localPath != null && await File(localPath).exists()
          ? localPath : null;
      if (_disposed || generation != _generation) return;
      usuarioId = id; nome = data['nome'] ?? '';
      email = data['email'] ?? ''; telefone = data['telefone'] ?? '';
      fotoPerfil = localPhoto ?? data['imagemUrl'];
    } catch (e) {
      if (!_disposed && generation == _generation) erro = e.toString();
    } finally {
      if (!_disposed && generation == _generation) { isLoading = false; notifyListeners(); }
    }
  }
  Future<void> atualizarNome(String nome) => atualizar({'nome': nome.trim()});
  Future<void> atualizarEmail(String email) => atualizar({'email': email.trim()});
  Future<void> atualizarTelefone(String telefone) => atualizar({'telefone': telefone.trim()});
  Future<void> atualizar(Map<String, dynamic> fields) async {
    await service.atualizar(fields);
    await carregarDadosReais();
  }
  Future<void> atualizarSenha(String atual, String nova) => service.alterarSenha(atual, nova);
  /// Mantém a foto somente neste aparelho; ainda não há upload de foto na API.
  Future<void> atualizarFotoPerfil(File imagem) async {
    if (usuarioId.isEmpty) throw StateError('Carregue seu perfil antes de salvar a foto.');
    final generation = _generation;
    final owner = usuarioId;
    final directory = await getApplicationSupportDirectory();
    final safeId = owner.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final destination = File(
        '${directory.path}/nhac-profile-$safeId-${DateTime.now().microsecondsSinceEpoch}.jpg');
    await imagem.copy(destination.path);
    if (_disposed || generation != _generation || usuarioId != owner) return;
    final prefs = await SharedPreferences.getInstance();
    if (_disposed || generation != _generation || usuarioId != owner) return;
    final key = 'motoboy_profile_photo_$owner';
    final previous = prefs.getString(key);
    await prefs.setString(key, destination.path);
    if (_disposed || generation != _generation || usuarioId != owner) return;
    fotoPerfil = destination.path;
    notifyListeners();
    if (previous != null &&
        previous.startsWith('${directory.path}/nhac-profile-$safeId-') &&
        previous != destination.path) {
      try { await File(previous).delete(); } on FileSystemException { /* Foto anterior já removida. */ }
    }
  }
  void setUsuario({String? id, String? nome, String? email, String? telefone, String? foto}) {
    usuarioId = id ?? usuarioId; this.nome = nome ?? this.nome;
    this.email = email ?? this.email; this.telefone = telefone ?? this.telefone;
    fotoPerfil = foto ?? fotoPerfil; notifyListeners();
  }
  void limparUsuario() {
    usuarioId = ''; nome = ''; email = ''; telefone = '';
    fotoPerfil = null; erro = null; isLoading = false;
    if (!_disposed) notifyListeners();
  }
  @override
  void dispose() {
    _disposed = true; _generation++;
    ApiConfig.session.removeListener(_sessionChanged);
    super.dispose();
  }
}
