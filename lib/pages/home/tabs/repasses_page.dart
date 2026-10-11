import 'package:flutter/material.dart';

import '../../../services/api_client.dart';
import '../../../utils/formatters.dart';

class RepassesPage extends StatefulWidget {
  const RepassesPage({super.key});
  @override
  State<RepassesPage> createState() => _RepassesPageState();
}

class _RepassesPageState extends State<RepassesPage> {
  final _api = ApiClient();
  final _items = <Map<String, dynamic>>[];
  int _page = 0;
  bool _last = false, _loading = false;
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
        '/api/v1/entregador/repasses',
        query: {'page': '${reset ? 0 : _page}'},
      ) as Map;
      if (!mounted) return;
      setState(() {
        if (reset) _items.clear();
        _items.addAll(
          (data['content'] as List).map((e) => Map<String, dynamic>.from(e)),
        );
        _page = (data['number'] as int) + 1;
        _last = data['last'] == true;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _valor(Object? v) => v is num ? formatarReal(v) : 'Não apurado';
  String _data(Object? v) {
    final date = DateTime.tryParse(v?.toString() ?? '')?.toLocal();
    return date == null
        ? 'Não informado'
        : '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pagamentos e repasses')),
    body: RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: ListView(
        padding: const EdgeInsets.all(24),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const Text(
            'Frete calculado é uma estimativa. O valor devido depende da apuração; o valor pago só aparece depois de registrado um pagamento efetivo. A chave Pix não ativa transferências automáticas.',
          ),
          const SizedBox(height: 16),
          if (_error != null)
            TextButton(
              onPressed: () => _load(reset: _items.isEmpty),
              child: Text('$_error Tentar novamente'),
            ),
          if (!_loading && _items.isEmpty && _error == null)
            const Text('Nenhuma entrega concluída para consultar.'),
          for (final r in _items)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pedido #${r['pedidoId']}'),
                    Text(switch (r['status']) {
                      'PAGO' => 'Pago',
                      'PENDENTE' => 'Pagamento pendente',
                      _ => 'Aguardando apuração',
                    }),
                    Text('Frete calculado: ${_valor(r['freteCalculado'])}'),
                    Text('Valor devido: ${_valor(r['valorDevido'])}'),
                    Text('Valor pago: ${_valor(r['valorPago'])}'),
                    if (r['apuradoEm'] != null)
                      Text('Apurado em: ${_data(r['apuradoEm'])}'),
                    if (r['pagoEm'] != null)
                      Text('Pago em: ${_data(r['pagoEm'])}'),
                    if (r['referencia'] != null)
                      Text('Referência: ${r['referencia']}'),
                  ],
                ),
              ),
            ),
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (!_loading && !_last && _error == null)
            TextButton(onPressed: _load, child: const Text('Carregar mais')),
        ],
      ),
    ),
  );
}
