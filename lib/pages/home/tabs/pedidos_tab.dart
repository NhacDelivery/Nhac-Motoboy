import '../../../utils/formatters.dart';

import 'package:flutter/material.dart';
import 'suporte_entrega_page.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../../controllers/entrega_provider.dart';
import '../../../globals/theme_colors.dart';
import '../../../models/historico_entrega_model.dart';
import '../../../services/entregador_service.dart';

class PedidosTab extends StatefulWidget {
  final EntregadorService? service;
  const PedidosTab({super.key, this.service});
  @override
  State<PedidosTab> createState() => _PedidosTabState();
}

class _PedidosTabState extends State<PedidosTab> {
  late final _service = widget.service ?? EntregadorService();
  final List<HistoricoEntregaModel> _items = [];
  bool _loading = false, _last = false;
  bool _pendingReload = false;
  int _page = 0;
  String? _error, _statusFiltro;
  int _generation = 0;
  EntregaProvider? _entrega;
  int _lastRevision = 0;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<EntregaProvider>();
    if (provider == _entrega) return;
    _entrega?.removeListener(_onEntregaChanged);
    _entrega = provider;
    _lastRevision = provider.entregasConcluidasRevision;
    provider.addListener(_onEntregaChanged);
  }

  void _onEntregaChanged() {
    final revision = _entrega?.entregasConcluidasRevision ?? 0;
    if (revision == _lastRevision) return;
    _lastRevision = revision;
    _load(reset: true);
  }

  @override
  void dispose() {
    _entrega?.removeListener(_onEntregaChanged);
    super.dispose();
  }

  Future<void> _load({bool reset = false, bool force = false}) async {
    if (_loading) {
      if (reset) _pendingReload = true;
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final generation = _generation;
    try {
      final page = await _service.buscarHistorico(
        page: reset ? 0 : _page,
        status: _statusFiltro,
        force: force,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        if (reset) _items.clear();
        _items.addAll(page.itens);
        _page = page.paginaAtual + 1;
        _last = page.ultima;
      });
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        if (_pendingReload) {
          _pendingReload = false;
          _load(reset: true);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    context.select<EntregaProvider, (bool, Object?)>(
      (p) => (p.isCadastrado, p.entregaAtiva),
    );
    final p = context.read<EntregaProvider>();
    if (!p.isCadastrado) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 40.r,
                color: AppColors.bordaInativa,
              ),
              SizedBox(height: 12.h),
              Text(
                'Complete seu cadastro para acompanhar suas corridas.',
                textAlign: TextAlign.center,
                style: AppTextStyles.subtitulo(),
              ),
              SizedBox(height: 12.h),
              TextButton(
                onPressed: () => context.push('/cadastro-motoboy'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaria,
                ),
                child: const Text('Completar cadastro'),
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(reset: true, force: true),
      color: AppColors.primaria,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 120.h),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _items.length + 2,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Suas corridas', style: AppTextStyles.titulo()),
                SizedBox(height: 8.h),
                Text(
                  'Sua entrega atual e o histórico de corridas',
                  style: AppTextStyles.subtitulo(),
                ),
                SizedBox(height: 24.h),
                if (p.entregaAtiva != null)
                  Padding(
                    padding: EdgeInsets.only(bottom: 12.h),
                    child: _CorridaCard(
                      icone: Icons.two_wheeler_rounded,
                      titulo: p.entregaAtiva!.lojaNome,
                      subtitulo:
                          'Entregar para: ${p.entregaAtiva!.clienteNome} • ${p.entregaAtiva!.statusPedido.label}',
                      onTap: () => context.push('/rota-entrega'),
                    ),
                  ),
                SizedBox(height: 18.h),
                Text(
                  'Histórico recente',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.texto,
                  ),
                ),
                SizedBox(height: 12.h),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final filtro in const [
                      (null, 'Todas'),
                      ('ENTREGUE', 'Concluídas'),
                      ('CANCELADO', 'Canceladas'),
                    ])
                      ChoiceChip(
                        label: Text(filtro.$2),
                        selectedColor: AppColors.primaria,
                        backgroundColor: Colors.white,
                        labelStyle: const TextStyle(
                          color: AppColors.texto,
                          fontWeight: FontWeight.w600,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20.r),
                          side: const BorderSide(color: AppColors.bordaInativa),
                        ),
                        selected: _statusFiltro == filtro.$1,
                        onSelected: (_) {
                          if (_statusFiltro == filtro.$1) return;
                          setState(() {
                            _statusFiltro = filtro.$1;
                            _generation++;
                            _items.clear();
                            _page = 0;
                            _last = false;
                          });
                          _load(reset: true);
                        },
                      ),
                  ],
                ),
                SizedBox(height: 12.h),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaria,
                      ),
                    ),
                  ),
                if (_error != null)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    child: TextButton(
                      onPressed: () =>
                          _load(reset: _items.isEmpty, force: true),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primaria,
                      ),
                      child: Text('$_error Tentar novamente'),
                    ),
                  ),
                if (!_loading && _error == null && _items.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 32.h),
                    child: Text(
                      _statusFiltro == null
                          ? 'Nenhuma corrida no histórico ainda.'
                          : 'Nenhuma corrida com este status.',
                      key: const Key('historico-empty'),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.subtitulo(),
                    ),
                  ),
              ],
            );
          }
          if (index == _items.length + 1) {
            return Column(
              children: [
                if (!_last && !_loading && _error == null)
                  Center(
                    child: TextButton(
                      onPressed: _load,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primaria,
                      ),
                      child: const Text('Carregar mais'),
                    ),
                  ),
              ],
            );
          }
          final item = _items[index - 1];
          return Padding(
            padding: EdgeInsets.only(bottom: 10.h),
            child: _CorridaCard(
              icone: Icons.storefront_rounded,
              titulo: item.lojaNome ?? 'Loja',
              subtitulo:
                  '${item.status.label} • '
                  '${_regiao(item)}\n${_formatarData(item.entregueEm ?? item.criadoEm)}',
              onTap: () => _detalhes(item),
              trailing: Text(
                item.taxaFrete == null ? '—' : formatarReal(item.taxaFrete!),
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.texto,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _regiao(HistoricoEntregaModel item) {
    final partes = [
      item.bairroEntrega,
      item.cidadeEntrega,
    ].whereType<String>().where((p) => p.trim().isNotEmpty);
    return partes.isEmpty ? 'Região não informada' : partes.join(', ');
  }

  String _formatarData(DateTime? value) {
    if (value == null) return 'Data não informada';
    final date = value.toLocal();
    String dois(int n) => n.toString().padLeft(2, '0');
    return '${dois(date.day)}/${dois(date.month)}/${date.year} às ${dois(date.hour)}:${dois(date.minute)}';
  }

  void _detalhes(HistoricoEntregaModel item) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: EdgeInsets.all(24.r),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Detalhes da entrega', style: AppTextStyles.titulo()),
            SizedBox(height: 16.h),
            Text('Pedido #${item.pedidoId}', style: AppTextStyles.subtitulo()),
            SizedBox(height: 12.h),
            Text('Loja: ${item.lojaNome ?? 'Não informada'}'),
            Text('Status: ${item.status.label}'),
            Text(
              'Endereço da entrega: ${item.enderecoEntrega?.formatado ?? _regiao(item)}',
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.of(this.context).push(
                  MaterialPageRoute(
                    builder: (_) => SuporteEntregaPage(pedidoId: item.pedidoId),
                  ),
                );
              },
              child: const Text('Acompanhar suporte da corrida'),
            ),
            Text('Criado em: ${_formatarData(item.criadoEm)}'),
            if (item.coletadoEm != null)
              Text('Coletado em: ${_formatarData(item.coletadoEm)}'),
            if (item.entregueEm != null)
              Text('Concluído em: ${_formatarData(item.entregueEm)}'),
            SizedBox(height: 12.h),
            Text(
              item.taxaFrete == null
                  ? 'Frete não informado'
                  : 'Frete calculado: ${formatarReal(item.taxaFrete!)}',
            ),
            SizedBox(height: 8.h),
          ],
        ),
      ),
    ),
  );
}

class _CorridaCard extends StatelessWidget {
  final IconData icone;
  final String titulo, subtitulo;
  final Widget? trailing;
  final VoidCallback? onTap;
  const _CorridaCard({
    required this.icone,
    required this.titulo,
    required this.subtitulo,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(16.r),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20.r),
      border: onTap == null
          ? null
          : Border.all(
              color: AppColors.primaria.withValues(alpha: 0.3),
              width: 1.5,
            ),
      boxShadow: [
        BoxShadow(
          color: AppColors.primaria.withValues(alpha: 0.08),
          blurRadius: 14,
          offset: const Offset(0, 5),
        ),
      ],
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(16.r),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: AppColors.fundo,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(icone, color: AppColors.primaria, size: 22.r),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.texto,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  subtitulo,
                  style: AppTextStyles.subtitulo(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (trailing != null)
            trailing!
          else
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.desabilitado,
              size: 20.r,
            ),
        ],
      ),
    ),
  );
}
