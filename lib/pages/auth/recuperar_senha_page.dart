import '../../services/api_config.dart';

import 'dart:async';

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
  final _email = TextEditingController(),
      _code = TextEditingController(),
      _password = TextEditingController();
  final _service = AuthService();
  bool _sent = false, _busy = false;
  String? _error, _success;
  int _intervalo = 0;
  Timer? _timer;
  void _iniciarIntervalo() {
    _intervalo = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _intervalo--);
      if (_intervalo == 0) timer.cancel();
    });
  }

  Future<void> _reenviar() async {
    if (_busy || _intervalo > 0) return;
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });
    try {
      await _service.recuperarSenha(_email.text.trim());
      if (!mounted) return;
      setState(() {
        _success =
            'Se o e-mail estiver cadastrado, um novo código foi enviado.';
        _iniciarIntervalo();
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_sent) {
        await _service.redefinirSenha(
          _email.text.trim(),
          _code.text.trim(),
          _password.text,
        );
        if (mounted) {
          context.go(
            ApiConfig.temSessaoSalva ? '/home-motoca' : '/email-motoca',
          );
        }
      } else {
        await _service.recuperarSenha(_email.text.trim());
        if (mounted) {
          setState(() {
            _sent = true;
            _iniciarIntervalo();
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Recuperar senha')),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextFormField(
            controller: _email,
            readOnly: _sent,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'E-mail'),
            validator: Validators.validarEmail,
          ),
          if (_sent) ...[
            const Text(
              'Se este e-mail estiver cadastrado, você receberá um código.',
            ),
            TextButton(
              onPressed: _busy || _intervalo > 0 ? null : _reenviar,
              child: Text(
                _intervalo > 0
                    ? 'Reenviar em ${_intervalo}s'
                    : 'Reenviar código',
              ),
            ),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                      _sent = false;
                      _code.clear();
                      _error = null;
                      _success = null;
                    }),
              child: const Text('Alterar e-mail'),
            ),

            TextFormField(
              controller: _code,
              decoration: const InputDecoration(labelText: 'Código'),
              keyboardType: TextInputType.number,
              maxLength: 6,
              validator: Validators.validarCodigoRecuperacao,
            ),
            TextFormField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Nova senha'),
              validator: Validators.validarSenhaRedefinicao,
            ),
          ],
          if (_success != null) Text(_success!),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: Text(
              _busy
                  ? 'Aguarde…'
                  : _sent
                  ? 'Redefinir senha'
                  : 'Enviar código',
            ),
          ),
        ],
      ),
    ),
  );
}
