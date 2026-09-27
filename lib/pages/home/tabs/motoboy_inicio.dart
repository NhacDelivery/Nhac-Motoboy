import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../components/entrega/oferta_card.dart';
import '../../../controllers/entrega_provider.dart';
import '../../../controllers/user_provider.dart';
import '../../../globals/theme_colors.dart';

class NhacCard extends StatelessWidget {
  final Widget child;
  const NhacCard({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: EdgeInsets.all(20.r),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [
            BoxShadow(color: AppColors.texto.withValues(alpha: 0.06), blurRadius: 15, offset: const Offset(0, 5)),
          ],
        ),
        child: child,
      );
}

class MotoboyInicio extends StatelessWidget {
  final ValueChanged<bool> onToggleOnline;
  const MotoboyInicio({super.key, required this.onToggleOnline});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<EntregaProvider>();
    final user = context.watch<UserProvider>();
    return RefreshIndicator(
      onRefresh: p.sincronizar,
      color: AppColors.primaria,
      child: ListView(
        padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 120.h),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Text(user.nome.trim().isEmpty ? 'Olá, Parceiro Motoca! 🛵'
              : 'Olá, ${user.nome.trim()}! 🛵',
            style: AppTextStyles.titulo()),
          SizedBox(height: 4.h),
          Text(user.email.isEmpty ? 'Pronto para as entregas de hoje?' : user.email, style: AppTextStyles.subtitulo()),
          SizedBox(height: 24.h),
          if (!p.inicializado)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator(color: AppColors.primaria)),
            ),
          if (p.erro != null) _Notice(p.erro!, action: p.sincronizar),
          if (p.aviso != null) _Notice(p.aviso!),
          if (p.inicializado && p.erro == null && !p.isCadastrado)
            NhacCard(
              child: InkWell(
                borderRadius: BorderRadius.circular(20.r),
                onTap: () => context.push('/cadastro-motoboy'),
                child: Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Comece seu cadastro',
                            style: TextStyle(fontFamily: 'Roboto', fontSize: 16.sp, fontWeight: FontWeight.w700, color: AppColors.texto)),
                        SizedBox(height: 4.h),
                        Text('Informe seus documentos e veículo para receber entregas.', style: AppTextStyles.subtitulo()),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: AppColors.texto, size: 22.r),
                ]),
              ),
            ),
          if (p.isCadastrado) ...[
            NhacCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 14.r, height: 14.r,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: p.estaOnline ? const Color(0xFF4CAF50) : AppColors.desabilitado,
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(child: Text(
                      p.isChangingStatus ? (p.estaOnline ? 'SAINDO...' : 'CONECTANDO...') :
                      p.emEntrega ? 'EM ENTREGA' : p.estaOnline ? 'ONLINE PARA PEDIDOS' : 'VOCÊ ESTÁ OFFLINE',
                      key: const Key('motoboy-status-text'),
                      style: TextStyle(fontFamily: 'Roboto', fontSize: 14.sp,
                        fontWeight: FontWeight.w700, letterSpacing: 0.5,
                        color: p.estaOnline ? const Color(0xFF2E7D32) : AppColors.desabilitado),
                    )),
                    if (!p.emEntrega && p.cadastroAtivo)
                      Switch(
                        key: const Key('motoboy-status-toggle'),
                        value: p.estaOnline,
                        activeThumbColor: AppColors.primaria,
                        activeTrackColor: AppColors.secundaria,
                        onChanged: p.isLoading ? null : onToggleOnline,
                      ),
                  ]),
                  SizedBox(height: 12.h),
                  Text(
                    p.isChangingStatus ? 'Atualizando sua disponibilidade...' :
                    !p.cadastroAtivo ? 'Seu cadastro está inativo.' :
                    p.emEntrega ? 'Sua disponibilidade é controlada pela corrida ativa.' :
                    p.estaOnline ? 'Procurando chamadas de restaurantes próximos a você...' :
                    'Ative o interruptor acima para começar a receber pedidos de entrega.',
                    style: AppTextStyles.subtitulo(),
                  ),
                ],
              ),
            ),
            if (p.erroLocalizacao != null)
              _Notice(p.erroLocalizacao!, action: () => p.atualizarLocalizacao(solicitar: true)),
            if (p.latitudeAtual != null) ...[
              SizedBox(height: 12.h),
              Row(children: [
                Icon(Icons.gps_fixed_rounded, size: 18.r, color: AppColors.desabilitado),
                SizedBox(width: 8.w),
                Text('Localização atualizada', style: AppTextStyles.subtitulo()),
              ]),
            ],
            if (p.estaOnline) ...[
              SizedBox(height: 12.h),
              Text(
                'Mantenha o aplicativo aberto para receber ofertas. Ao ir para segundo plano, solicitamos o status offline.',
                style: AppTextStyles.subtitulo(),
              ),
            ],
            if (p.entregaAtiva != null) ...[
              SizedBox(height: 16.h),
              NhacCard(
                key: const Key('corrida-ativa-card'),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20.r),
                  onTap: () => context.push('/rota-entrega'),
                  child: Row(children: [
                    Container(
                      width: 44.w,
                      height: 44.w,
                      decoration: BoxDecoration(color: AppColors.fundo, borderRadius: BorderRadius.circular(14.r)),
                      child: Icon(Icons.delivery_dining_rounded, color: AppColors.primaria, size: 26.r),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.entregaAtiva!.lojaNome,
                              style: TextStyle(fontFamily: 'Roboto', fontSize: 15.sp, fontWeight: FontWeight.w700, color: AppColors.texto)),
                          Text(p.entregaAtiva!.statusPedido.label, style: AppTextStyles.subtitulo()),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: AppColors.texto, size: 22.r),
                  ]),
                ),
              ),
            ],
            if (p.estaOnline && !p.emEntrega) ...[
              SizedBox(height: 24.h),
              Text('Ofertas disponíveis',
                  style: TextStyle(fontFamily: 'Roboto', fontSize: 17.sp, fontWeight: FontWeight.w700, color: AppColors.texto)),
              SizedBox(height: 12.h),
              if (p.ofertas.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.h),
                  child: Text(
                    'Nenhuma entrega disponível no momento.\nVocê será avisado quando uma nova oferta aparecer.',
                    key: const Key('ofertas-empty'),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.subtitulo(),
                  ),
                ),
              for (final offer in p.ofertas)
                Padding(
                  padding: EdgeInsets.only(bottom: 12.h),
                  child: OfertaCard(
                    oferta: offer,
                    busy: p.isLoading,
                    aceitar: () async {
                      final ok = await p.aceitarOferta(offer.id);
                      if (ok && context.mounted) context.push('/rota-entrega');
                    },
                    recusar: () => p.recusarOferta(offer.id),
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  final String text;
  final VoidCallback? action;
  const _Notice(this.text, {this.action});
  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(top: 12.h),
        child: NhacCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.info_outline_rounded, size: 18.r, color: AppColors.primaria),
                SizedBox(width: 8.w),
                Expanded(child: Text(text, style: AppTextStyles.subtitulo(cor: AppColors.texto))),
              ]),
              if (action != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: action,
                    style: TextButton.styleFrom(foregroundColor: AppColors.primaria),
                    child: const Text('Tentar novamente'),
                  ),
                ),
            ],
          ),
        ),
      );
}
