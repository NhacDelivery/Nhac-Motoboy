import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../services/api_client.dart';
import '../../../services/push_service.dart';
import '../../chat_page.dart';

void abrirAviso(BuildContext context, Map<String, dynamic> aviso) {
  if (aviso['tipo'] == 'MENSAGEM' && aviso['lojaId'] != null) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(
          lojaId: aviso['lojaId'].toString(),
          lojaNome: aviso['lojaNome']?.toString() ?? 'Loja',
        ),
      ),
    );
  } else if (aviso['tipo'] == 'OFERTA') {
    context.go('/home-motoca');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Consultando ofertas disponíveis. Ofertas antigas podem ter expirado.',
        ),
      ),
    );
  } else {
    context.go('/rota-entrega');
  }
}

class AvisosPage extends StatefulWidget {
  const AvisosPage({super.key});
  @override
  State<AvisosPage> createState() => _AvisosPageState();
}

class _AvisosPageState extends State<AvisosPage> {
  final _api = ApiClient();
  final _items = <Map<String, dynamic>>[];
  bool _loading = false, _last = false;
  int _page = 0;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api.request(
        'GET',
        '/api/v1/entregador/avisos',
        query: {'page': '${reset ? 0 : _page}'},
      ) as Map;
      if (!mounted) return;
      setState(() {
        if (reset) _items.clear();
        for (final e in data['content'] as List) {
          final item = Map<String, dynamic>.from(e);
          if (!_items.any((v) => v['id'] == item['id'])) _items.add(item);
        }
        _page = (data['number'] as int) + 1;
        _last = data['last'] == true;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Histórico de notificações')),
    body: RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: ListView(
        padding: const EdgeInsets.all(24),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (PushService.shared.erro != null) Text(PushService.shared.erro!),
          if (_error != null)
            TextButton(
              onPressed: () => _load(reset: _items.isEmpty),
              child: Text('$_error Tentar novamente'),
            ),
          if (!_loading && _items.isEmpty && _error == null)
            const Text('Nenhuma notificação registrada.'),
          for (final aviso in _items)
            Card(
              child: ListTile(
                title: Text('${aviso['texto']}'),
                subtitle: Text('${aviso['criadoEm']}'),
                onTap: () => abrirAviso(context, aviso),
              ),
            ),
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (!_last && !_loading && _error == null)
            TextButton(onPressed: _load, child: const Text('Carregar mais')),
        ],
      ),
    ),
  );
}
