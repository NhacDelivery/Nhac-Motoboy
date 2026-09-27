import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../components/botoes/botao_largo_nhac.dart';
import '../../../components/entrega/mapa_rota_widget.dart';
import '../../../controllers/entrega_provider.dart';
import '../../../globals/theme_colors.dart';
import '../../chat_page.dart';

class RotaEntregaPage extends StatelessWidget {
  const RotaEntregaPage({super.key});

  Future<void> _confirm(BuildContext context, EntregaProvider p, bool collect) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        backgroundColor: Colors.white,
        title: Text(
          collect ? 'Confirmar retirada?' : 'Confirmar entrega?',
          style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w700, color: AppColors.texto),
        ),
        content: Text(
          collect ? 'Confirme após receber o pedido na loja.' : 'Confirme após entregar o pedido ao cliente.',
          style: AppTextStyles.subtitulo(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(foregroundColor: AppColors.desabilitado),
            child: const Text('Voltar'),
          ),
          FilledButton(
            key: const Key('corrida-confirmar-dialog'),
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaria,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50.r)),
            ),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (accepted != true || !context.mounted) return;
    final ok = collect ? await p.confirmarColeta() : await p.concluirEntregaAtual();
    if (!context.mounted) return;
    if (ok && !collect) context.go('/home-motoca');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<EntregaProvider>();
    final active = p.entregaAtiva;
    return Scaffold(
      backgroundColor: AppColors.fundo,
      appBar: AppBar(
        backgroundColor: AppColors.fundo,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.texto, size: 20.r),
          onPressed: () => context.canPop() ? context.pop() : context.go('/home-motoca'),
        ),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(active == null ? 'Rota de Entrega' : 'Entrega #${active.pedidoId.length > 8 ? active.pedidoId.substring(0, 8) : active.pedidoId}',
            style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w700, fontSize: 16.sp, color: AppColors.texto)),
          if (active != null) Text(p.entregaColetada ? 'Em transporte' : 'A caminho da loja',
            style: TextStyle(fontFamily: 'Roboto', fontSize: 12.sp, color: p.entregaColetada ? const Color(0xFF2E7D32) : AppColors.primaria)),
        ]),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: active == null
                ? Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.r),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(p.aviso ?? 'Nenhuma corrida ativa.', textAlign: TextAlign.center, style: AppTextStyles.subtitulo()),
                        SizedBox(height: 12.h),
                        TextButton(
                          onPressed: () => context.go('/home-motoca'),
                          style: TextButton.styleFrom(foregroundColor: AppColors.primaria),
                          child: const Text('Voltar ao início'),
                        ),
                      ]),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: p.sincronizar,
                    color: AppColors.primaria,
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(24.w, 8.h, 24.w, 32.h),
                      children: [
                        Text(active.statusPedido.label, key: const Key('corrida-status-text'), style: AppTextStyles.titulo()),
                        SizedBox(height: 12.h),
                        if (p.isLoading)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: Center(child: CircularProgressIndicator(color: AppColors.primaria)),
                          ),
                        if (p.erro != null)
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.h),
                            child: Text(p.erro!, style: const TextStyle(color: Colors.red)),
                          ),
                        if (p.rotaAtual != null) ...[
                          SizedBox(height: 16.h),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20.r),
                            child: MapaRotaWidget(rota: p.rotaAtual!, latitude: p.latitudeAtual, longitude: p.longitudeAtual),
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            'Loja → cliente: ${p.rotaAtual!.distanciaKm.toStringAsFixed(1)} km • '
                            'estimativa ${p.rotaAtual!.duracaoEstimadaMinutos} min',
                            style: AppTextStyles.subtitulo(),
                          ),
                        ] else
                          Padding(
                            padding: EdgeInsets.only(top: 8.h),
                            child: TextButton(
                              onPressed: () => p.carregarRota(active.pedidoId),
                              style: TextButton.styleFrom(foregroundColor: AppColors.primaria),
                              child: Text(p.erroRota == null ? 'Carregar mapa da corrida' : '${p.erroRota} Tentar novamente'),
                            ),
                          ),
                        SizedBox(height: 20.h),
                        _InfoCard(icone: Icons.storefront_rounded, rotulo: 'Ponto de Retirada (Restaurante)', titulo: active.lojaNome, subtitulo: active.lojaEndereco, destaque: !p.entregaColetada),
                        SizedBox(height: 10.h),
                        _InfoCard(
                          icone: Icons.home_rounded,
                          rotulo: 'Ponto de Entrega (Cliente)',
                          destaque: p.entregaColetada,
                          titulo: active.clienteNome,
                          subtitulo: active.enderecoEntrega?.formatado ?? 'Endereço indisponível',
                        ),
                        if (active.observacao?.isNotEmpty == true) ...[
                          SizedBox(height: 10.h),
                          Text('Observação: ${active.observacao}', style: AppTextStyles.subtitulo()),
                        ],
                        SizedBox(height: 16.h),
                        Container(padding: EdgeInsets.all(16.r),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16.r),
                            border: Border.all(color: AppColors.bordaInativa)),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Seu ganho no frete:', style: AppTextStyles.subtitulo()),
                            Text('R\$ ${active.taxaFrete.toStringAsFixed(2)}',
                              style: TextStyle(fontFamily: 'Roboto', fontSize: 20.sp, fontWeight: FontWeight.w800, color: const Color(0xFF2E7D32))),
                          ])),
                        SizedBox(height: 20.h),
                        BotaoLargoNhac(
                          texto: 'Abrir navegação',
                          isSecundario: true,
                          icone: Icon(Icons.directions_rounded, color: AppColors.texto, size: 20.r),
                          onPressed: () async {
                            final lat = p.entregaColetada ? active.entregaLatitude : active.lojaLatitude;
                            final lng = p.entregaColetada ? active.entregaLongitude : active.lojaLongitude;
                            final address = p.entregaColetada ? active.enderecoEntrega?.formatado : active.lojaEndereco;
                            if ((lat == null || lng == null) && (address == null || address.isEmpty)) return;
                            final uri = Uri.https('www.google.com', '/maps/dir/',
                                {'api': '1', 'destination': lat != null && lng != null ? '$lat,$lng' : address!});
                            try {
                              if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                                throw StateError('Navegação indisponível.');
                              }
                            } catch (_) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(const SnackBar(content: Text('Não foi possível abrir a navegação.')));
                              }
                            }
                          },
                        ),
                        if (active.lojaId != null) ...[
                          SizedBox(height: 10.h),
                          BotaoLargoNhac(
                            key: const Key('chat-button'),
                            texto: 'Conversar com a loja',
                            isSecundario: true,
                            icone: Icon(Icons.chat_bubble_outline_rounded, color: AppColors.texto, size: 20.r),
                            onPressed: () => Navigator.push(
                                context, MaterialPageRoute(builder: (_) => ChatPage(lojaId: active.lojaId!, lojaNome: active.lojaNome))),
                          ),
                        ],
                        SizedBox(height: 20.h),
                        if (!p.entregaColetada)
                          BotaoLargoNhac(
                            key: const Key('corrida-coletar-button'),
                            texto: 'Confirmar retirada',
                            onPressed: p.podeColetar ? () => _confirm(context, p, true) : null,
                          )
                        else
                          BotaoLargoNhac(
                            key: const Key('corrida-entregar-button'),
                            texto: 'Confirmar entrega',
                            onPressed: p.podeConcluir ? () => _confirm(context, p, false) : null,
                          ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icone;
  final String titulo, subtitulo, rotulo;
  final bool destaque;
  const _InfoCard({required this.icone, required this.rotulo, required this.titulo, required this.subtitulo, this.destaque = false});
  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: destaque ? Border.all(color: icone == Icons.storefront_rounded ? AppColors.primaria : const Color(0xFF2E7D32), width: 1.5) : null,
          boxShadow: [BoxShadow(color: AppColors.texto.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3))],
        ),
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
                Text(rotulo, style: TextStyle(fontFamily: 'Roboto', fontSize: 12.sp, color: AppColors.desabilitado)),
                SizedBox(height: 8.h),
                Text(titulo, style: TextStyle(fontFamily: 'Roboto', fontSize: 15.sp, fontWeight: FontWeight.w700, color: AppColors.texto)),
                SizedBox(height: 2.h),
                Text(subtitulo, style: AppTextStyles.subtitulo()),
              ],
            ),
          ),
        ]),
      );
}
