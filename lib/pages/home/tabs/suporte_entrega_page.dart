import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/api_config.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../services/api_client.dart';
import '../../../globals/theme_colors.dart';

class SuporteEntregaPage extends StatefulWidget {
  final String pedidoId;
  const SuporteEntregaPage({super.key, required this.pedidoId});
  @override
  State<SuporteEntregaPage> createState() => _SuporteEntregaPageState();
}

class _SuporteEntregaPageState extends State<SuporteEntregaPage> {
  final _api = ApiClient();
  final _texto = TextEditingController();
  final _form = GlobalKey<FormState>();
  String _motivo = 'OUTRO';
  String _id = const Uuid().v4();
  bool _busy = false, _loading = true, _falhaRestauracao = false;
  late final String _key;
  Map<String, dynamic>? _pendente;

  String? _error;
  List<Map<String, dynamic>> _tickets = [];
  String get _path =>
      '/api/v1/entregas/${Uri.encodeComponent(widget.pedidoId)}/suporte';
  @override
  void initState() {
    super.initState();
    _key =
        'suporte:${ApiConfig.baseUrl}:${ApiConfig.usuarioId}:${widget.pedidoId}';
    _restaurar();
  }

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  Future<void> _restaurar() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_key);
      if (!mounted) return;
      if (raw != null) {
        _pendente = Map<String, dynamic>.from(jsonDecode(raw));
        _id = _pendente!['id'];
        _motivo = _pendente!['motivo'];
        _texto.text = _pendente!['descricao'];
      }
    } catch (_) {
      if (mounted) {
        _falhaRestauracao = true;
        setState(
          () => _error =
              'Não foi possível recuperar a solicitação. Reabra esta tela.',
        );
      }
    }
    await _load();
  }

  Future<void> _load() async {
    try {
      final data = await _api.request('GET', _path) as List;
      if (_pendente != null && data.any((t) => t['id'] == _id)) {
        await (await SharedPreferences.getInstance()).remove(_key);
        _pendente = null;
        _id = const Uuid().v4();
        if (mounted) _texto.clear();
      }
      if (mounted) {
        setState(() {
          _tickets = data.map((e) => Map<String, dynamic>.from(e)).toList();
          if (!_falhaRestauracao) _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    if (_busy || _falhaRestauracao || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _pendente ??= {
        'id': _id,
        'motivo': _motivo,
        'descricao': _texto.text.trim(),
      };
      if (!await (await SharedPreferences.getInstance()).setString(
        _key,
        jsonEncode(_pendente),
      )) {
        throw StateError(
          'Não foi possível guardar a solicitação. Ela não foi enviada.',
        );
      }
      await _api.request('POST', _path, body: _pendente);
      await (await SharedPreferences.getInstance()).remove(_key);
      _pendente = null;
      if (!mounted) return;
      _texto.clear();
      _id = const Uuid().v4();
      await _load();
    } catch (e) {
      if (e is ApiException &&
          e.status >= 400 &&
          e.status < 500 &&
          e.status != 408) {
        await (await SharedPreferences.getInstance()).remove(_key);
        _pendente = null;
      }
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ajuda durante a entrega')),
    body: RefreshIndicator(
      onRefresh: _load,
      child: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(24),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Text('Pedido #${widget.pedidoId}', style: AppTextStyles.titulo()),
            const SizedBox(height: 16),
            const Text(
              'Solicitar ajuda não transfere a corrida. Você continua responsável até receber uma confirmação do atendimento. Após a coleta, preserve o pedido e aguarde instruções.',
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _motivo,
              decoration: const InputDecoration(labelText: 'Motivo'),
              items: const [
                DropdownMenuItem(
                  value: 'RETIRADA',
                  child: Text('Solicitar retirada da corrida'),
                ),
                DropdownMenuItem(
                  value: 'TRANSFERENCIA',
                  child: Text('Solicitar transferência'),
                ),
                DropdownMenuItem(
                  value: 'ACIDENTE',
                  child: Text('Acidente ou problema no veículo'),
                ),
                DropdownMenuItem(
                  value: 'ENDERECO',
                  child: Text('Problema no endereço'),
                ),
                DropdownMenuItem(
                  value: 'OUTRO',
                  child: Text('Outro atendimento'),
                ),
              ],
              onChanged: _busy || _pendente != null
                  ? null
                  : (value) => setState(() => _motivo = value!),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _texto,
              readOnly: _busy || _pendente != null,
              maxLines: 4,
              maxLength: 2000,
              decoration: const InputDecoration(
                labelText: 'Descreva o problema',
              ),
              validator: (value) => (value?.trim().length ?? 0) < 5
                  ? 'Descreva o problema com pelo menos 5 caracteres.'
                  : null,
            ),
            FilledButton(
              onPressed: _busy || _loading || _falhaRestauracao ? null : _send,
              child: Text(
                _busy
                    ? 'Enviando…'
                    : _pendente != null
                    ? 'Confirmar solicitação anterior'
                    : 'Abrir solicitação',
              ),
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: AppColors.erro)),
            TextButton(
              onPressed: _loading ? null : _load,
              child: const Text('Atualizar atendimento'),
            ),
            if (_loading) const Center(child: CircularProgressIndicator()),
            for (final ticket in _tickets)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Protocolo ${ticket['id']}'),
                      Text('${ticket['status']} • ${ticket['etapa']}'),
                      Text('${ticket['descricao']}'),
                      const SizedBox(height: 8),
                      Text('${ticket['resposta'] ?? 'Aguardando atendimento'}'),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
