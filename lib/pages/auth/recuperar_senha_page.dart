import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_service.dart';
import '../../utils/validators.dart';
class RecuperarSenhaPage extends StatefulWidget {
  const RecuperarSenhaPage({super.key});
  @override
  State<RecuperarSenhaPage> createState() => _RecuperarSenhaPageState();
}
class _RecuperarSenhaPageState extends State<RecuperarSenhaPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController(), _code = TextEditingController(), _password = TextEditingController();
  final _service = AuthService();
  bool _sent = false, _busy = false;
  String? _error;
  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    try {
      if (_sent) {
        await _service.redefinirSenha(_email.text.trim(), _code.text.trim(), _password.text);
        if (mounted) context.go('/email-motoca');
      } else {
        await _service.recuperarSenha(_email.text.trim());
        if (mounted) setState(() => _sent = true);
      }
    } catch (e) { if (mounted) setState(() => _error = e.toString()); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  @override
  void dispose() { _email.dispose(); _code.dispose(); _password.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Recuperar senha')),
    body: Form(key: _form, child: ListView(padding: const EdgeInsets.all(24), children: [
      TextFormField(controller: _email, readOnly: _sent, keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(labelText: 'E-mail'), validator: Validators.validarEmail),
      if (_sent) ...[
        const Text('Se este e-mail estiver cadastrado, você receberá um código.'),
        TextFormField(controller: _code, decoration: const InputDecoration(labelText: 'Código'),
          keyboardType: TextInputType.number, maxLength: 6,
          validator: Validators.validarCodigoRecuperacao),
        TextFormField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'Nova senha'),
          validator: Validators.validarSenhaRedefinicao),
      ],
      if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
      FilledButton(onPressed: _busy ? null : _submit, child: Text(_busy ? 'Aguarde…' : _sent ? 'Redefinir senha' : 'Enviar código')),
    ])));
}