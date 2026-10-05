import 'package:flutter/material.dart';

import '../../../globals/theme_colors.dart';
import '../../../models/avaliacoes_entregador_model.dart';
import '../../../services/entregador_service.dart';

class AvaliacoesPage extends StatefulWidget {
  final EntregadorService? service;
  const AvaliacoesPage({super.key, this.service});
  @override
  State<AvaliacoesPage> createState() => _AvaliacoesPageState();
}

class _AvaliacoesPageState extends State<AvaliacoesPage> {
  late final _service = widget.service ?? EntregadorService();
  final List<AvaliacaoEntregadorModel> _itens = [];
  bool _loading = false, _last = true, _loaded = false;
  int _page = 0, _total = 0;
  double _media = 0;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({bool reset = false, bool force = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _service.buscarAvaliacoes(
        page: reset ? 0 : _page,
        force: force,
      );
      if (!mounted) return;
      setState(() {
        if (reset) _itens.clear();
        _itens.addAll(result.itens);
        _page = result.paginaAtual + 1;
        _loaded = true;
        _last = result.ultima;
        _media = result.media;
        _total = result.total;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _date(DateTime? value) {
    if (value == null) return 'Data não informada';
    final d = value.toLocal();
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Minhas avaliações')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: RefreshIndicator(
            onRefresh: () => _load(reset: true, force: true),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              itemCount: _itens.length + 2,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Cada entrega conta', style: AppTextStyles.titulo()),
                      const SizedBox(height: 8),
                      Text(
                        'Veja o que os clientes acharam das suas entregas.',
                        style: AppTextStyles.subtitulo(),
                      ),
                      const SizedBox(height: 24),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                size: 48,
                                color: AppColors.texto,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      !_loaded
                                          ? (_error == null
                                                ? 'Carregando'
                                                : 'Indisponível')
                                          : _total == 0
                                          ? 'Sem nota ainda'
                                          : '${_media.toStringAsFixed(1).replaceAll('.', ',')} de 5',
                                      style: const TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      _loaded
                                          ? '$_total ${_total == 1 ? 'avaliação' : 'avaliações'}'
                                          : 'Avaliações dos clientes',
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  );
                }
                if (index == _itens.length + 1) {
                  return Column(
                    children: [
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(),
                        ),
                      if (_error != null) ...[
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            _error!,
                            style: const TextStyle(color: AppColors.erro),
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              _load(reset: _itens.isEmpty, force: true),
                          child: const Text('Tentar novamente'),
                        ),
                      ],
                      if (!_loading && _error == null && _itens.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Suas avaliações aparecerão aqui quando os clientes avaliarem as entregas.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      if (!_last && !_loading && _error == null)
                        OutlinedButton(
                          onPressed: _load,
                          child: const Text('Carregar mais'),
                        ),
                    ],
                  );
                }
                final item = _itens[index - 1];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.clienteNome,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Semantics(
                          label: '${item.nota} de 5 estrelas',
                          excludeSemantics: true,
                          child: Row(
                            children: List.generate(
                              5,
                              (i) => Icon(
                                i < item.nota
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                size: 24,
                                color: AppColors.texto,
                              ),
                            ),
                          ),
                        ),
                        Text(
                          'Pedido #${item.pedidoId}',
                          style: AppTextStyles.subtitulo(),
                        ),
                        if (item.comentario?.trim().isNotEmpty == true) ...[
                          const SizedBox(height: 12),
                          Text(item.comentario!),
                        ],
                        const SizedBox(height: 12),
                        Text(
                          _date(item.criadoEm),
                          style: const TextStyle(color: AppColors.desabilitado),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
}
