import 'package:http/http.dart' as http;
import 'api_client.dart';

class AuthService {
  final ApiClient _api;
  AuthService({http.Client? client}) : _api = ApiClient(client: client);
  Future<dynamic> _post(String path, Object body) =>
      _api.request('POST', path, body: body, authenticated: false);
  Future<bool> checarEmail(String email) async =>
      (await _post('/api/v1/auth/checar-email', {'email': email}))['existe'] == true;
  Future<void> enviarCodigoCadastro(String email) async {
    await _post('/api/v1/auth/enviar-codigo-cadastro', {'email': email});
  }
  Future<void> confirmarEmailCadastro(String email, String codigo) async {
    await _post('/api/v1/auth/confirmar-email-cadastro', {'email': email, 'codigo': codigo});
  }
  Future<String> registrar({required String id, required String nome,
    required String email, required String telefone, required String senha}) async =>
      (await _post('/api/v1/auth/registrar', {'id': id, 'nome': nome,
        'email': email, 'telefone': telefone, 'senha': senha}))['token'] as String;
  Future<String> login(String email, String senha) async =>
      (await _post('/api/v1/auth/login', {'email': email, 'senha': senha}))['token'] as String;
  Future<void> enviarCodigoTelefone(String telefone) async {
    await _post('/api/v1/verificacao-telefone/enviar-codigo', {'telefone': telefone});
  }
  Future<String> loginComSms({required String telefone, required String codigo, String? nome}) async =>
      (await _post('/api/v1/auth/login-sms', {'telefone': telefone, 'codigo': codigo,
        'nome': ?nome}))['token'] as String;
  Future<void> recuperarSenha(String email) async {
    await _post('/api/v1/auth/esqueci-senha/email', {'email': email});
  }
  Future<void> redefinirSenha(String email, String codigo, String novaSenha) async {
    await _post('/api/v1/auth/redefinir-senha/email',
      {'email': email, 'codigo': codigo, 'novaSenha': novaSenha});
  }
}
