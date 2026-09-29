import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../controllers/entrega_provider.dart';
import '../../../globals/theme_colors.dart';
import '../../../models/historico_entrega_model.dart';
import '../../../services/entregador_service.dart';

class PedidosTab extends StatefulWidget {
  const PedidosTab({super.key});
  @override
  State<PedidosTab> createState() => _PedidosTabState();
}

class _PedidosTabState extends State<PedidosTab> {
  final _service = EntregadorService();
  final List<HistoricoEntregaModel> _items = [];
  bool _loading = false, _last = false;
  bool _pendingReload = false;
  int _page = 0;
  String? _error;
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
  void dispose() { _entrega?.removeListener(_onEntregaChanged); super.dispose(); }

  Future<void> _load({bool reset = false}) async {
    if (_loading) { if (reset) _pendingReload = true; return; }
    setState(() { _loading = true; _error = null; });
    try {
      final page = await _service.buscarHistorico(page: reset ? 0 : _page);
      if (!mounted) return;
      setState(() {
        if (reset) _items.clear();
        _items.addAll(page.itens);
        _page = page.paginaAtual + 1;
        _last = page.ultima;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        if (_pendingReload) { _pendingReload = false; _load(reset: true); }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<EntregaProvider>();
    if (!p.isCadastrado) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24.r),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.receipt_long_outlined, size: 40.r, color: AppColors.bordaInativa),
            SizedBox(height: 12.h),
            Text(
              'Complete seu cadastro para acompanhar suas corridas.',
              textAlign: TextAlign.center,
              style: AppTextStyles.subtitulo(),
            ),
            SizedBox(height: 12.h),
            TextButton(
              onPressed: () => context.push('/cadastro-motoboy'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primaria),
              child: const Text('Completar cadastro'),
            ),
          ]),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      color: AppColors.primaria,
      child: ListView(
        padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 120.h),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Text('Seus Pedidos', style: AppTextStyles.titulo()),
          SizedBox(height: 8.h),
          Text('Acompanhe e gerencie as corridas ativas', style: AppTextStyles.subtitulo()),
          SizedBox(height: 24.h),
          if (p.entregaAtiva != null)
            Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: _CorridaCard(
                icone: Icons.two_wheeler_rounded,
                titulo: p.entregaAtiva!.lojaNome,
                subtitulo: 'Entregar para: ${p.entregaAtiva!.clienteNome} • ${p.entregaAtiva!.statusPedido.label}',
                onTap: () => context.push('/rota-entrega'),
              ),
            ),
          SizedBox(height: 18.h),
          Text('Histórico recente', style: TextStyle(fontFamily: 'Roboto', fontSize: 15.sp, fontWeight: FontWeight.w700, color: AppColors.texto)),
          SizedBox(height: 12.h),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator(color: AppColors.primaria)),
            ),
          if (_error != null)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.h),
              child: TextButton(
                onPressed: () => _load(reset: _items.isEmpty),
                style: TextButton.styleFrom(foregroundColor: AppColors.primaria),
                child: Text('$_error Tentar novamente'),
              ),
            ),
          if (!_loading && _error == null && _items.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 32.h),
              child: Text(
                'Nenhuma entrega concluída ainda.',
                key: const Key('historico-empty'),
                textAlign: TextAlign.center,
                style: AppTextStyles.subtitulo(),
              ),
            ),
          for (final item in _items)
            Padding(
              padding: EdgeInsets.only(bottom: 10.h),
              child: _CorridaCard(
                icone: Icons.storefront_rounded,
                titulo: item.lojaNome ?? 'Loja',
                subtitulo: '${item.status.label} • '
                    '${_regiao(item)}\n${_formatarData(item.entregueEm ?? item.criadoEm)}',
                onTap: () => _detalhes(item),
                trailing: Text(
                  item.taxaFrete == null ? '—' : 'R\$ ${item.taxaFrete!.toStringAsFixed(2)}',
                  style: TextStyle(fontFamily: 'Roboto', fontSize: 14.sp, fontWeight: FontWeight.w700, color: AppColors.texto),
                ),
              ),
            ),
          if (!_last && !_loading && _error == null)
            Center(
              child: TextButton(
                onPressed: _load,
                style: TextButton.styleFrom(foregroundColor: AppColors.primaria),
                child: const Text('Carregar mais'),
              ),
            ),
        ],
      ),
    );
  }
  String _regiao(HistoricoEntregaModel item) {
    final partes = [item.bairroEntrega, item.cidadeEntrega]
        .whereType<String>().where((p) => p.trim().isNotEmpty);
    return partes.isEmpty ? 'Região não informada' : partes.join(', ');
  }
  String _formatarData(DateTime? value) {
    if (value == null) return 'Data não informada';
    final date = value.toLocal();
    String dois(int n) => n.toString().padLeft(2, '0');
    return '${dois(date.day)}/${dois(date.month)}/${date.year} às ${dois(date.hour)}:${dois(date.minute)}';
  }
  void _detalhes(HistoricoEntregaModel item) => showModalBottomSheet<void>(
    context: context, showDragHandle: true, isScrollControlled: true,
    builder: (context) => SafeArea(child: Padding(
      padding: EdgeInsets.all(24.r),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Detalhes da entrega', style: AppTextStyles.titulo()),
        SizedBox(height: 16.h),
        Text('Pedido #${item.pedidoId}', style: AppTextStyles.subtitulo()),
        SizedBox(height: 12.h),
        Text('Loja: ${item.lojaNome ?? 'Não informada'}'),
        Text('Status: ${item.status.label}'),
        Text('Endereço de entrega: ${item.enderecoEntrega?.formatado ?? _regiao(item)}'),
        Text('Criado em: ${_formatarData(item.criadoEm)}'),
        if (item.coletadoEm != null) Text('Coletado em: ${_formatarData(item.coletadoEm)}'),
        if (item.entregueEm != null) Text('Concluído em: ${_formatarData(item.entregueEm)}'),
        SizedBox(height: 12.h),
        Text(item.taxaFrete == null ? 'Frete não informado' :
          'Frete calculado: R\$ ${item.taxaFrete!.toStringAsFixed(2)}'),
        SizedBox(height: 8.h),
      ]),
    )),
  );
}

class _CorridaCard extends StatelessWidget {
  final IconData icone;
  final String titulo, subtitulo;
  final Widget? trailing;
  final VoidCallback? onTap;
  const _CorridaCard({required this.icone, required this.titulo, required this.subtitulo, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          border: onTap == null ? null : Border.all(color: AppColors.primaria.withValues(alpha: 0.3), width: 1.5),
          boxShadow: [BoxShadow(color: AppColors.primaria.withValues(alpha: 0.08), blurRadius: 14, offset: const Offset(0, 5))],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16.r),
          onTap: onTap,
          child: Row(children: [
            Container(
              width: 40.w,
              height: 40.w,
              decoration: BoxDecoration(color: AppColors.fundo, borderRadius: BorderRadius.circular(12.r)),
              child: Icon(icone, color: AppColors.primaria, size: 22.r),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: TextStyle(fontFamily: 'Roboto', fontSize: 14.sp, fontWeight: FontWeight.w700, color: AppColors.texto)),
                  SizedBox(height: 2.h),
                  Text(subtitulo, style: AppTextStyles.subtitulo(), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (trailing != null) trailing! else Icon(Icons.chevron_right_rounded, color: AppColors.desabilitado, size: 20.r),
          ]),
        ),
      );
}
