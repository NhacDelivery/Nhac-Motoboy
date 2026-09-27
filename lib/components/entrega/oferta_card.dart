import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../globals/theme_colors.dart';
import '../../models/oferta_entrega_model.dart';

class OfertaCard extends StatelessWidget {
  final OfertaEntregaModel oferta;
  final bool busy;
  final VoidCallback aceitar, recusar;
  const OfertaCard({super.key, required this.oferta, required this.busy,
    required this.aceitar, required this.recusar});

  @override
  Widget build(BuildContext context) {
    final seconds = oferta.segundosEm(DateTime.now());
    final expired = seconds <= 0;
    return Container(
      key: Key('oferta-card-${oferta.id}'),
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [BoxShadow(color: AppColors.primaria.withValues(alpha: 0.18),
          blurRadius: 24.r, offset: Offset(0, 8.h))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            decoration: BoxDecoration(color: AppColors.primaria.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12.r)),
            child: Text('🛵  NOVA CORRIDA', style: TextStyle(fontFamily: 'Roboto',
              fontSize: 12.sp, fontWeight: FontWeight.w700, color: AppColors.primaria))),
          Stack(alignment: Alignment.center, children: [
            SizedBox(width: 36.r, height: 36.r, child: CircularProgressIndicator(
              value: (seconds / 45).clamp(0.0, 1.0), strokeWidth: 3.5,
              backgroundColor: AppColors.bordaInativa.withValues(alpha: 0.3),
              color: seconds > 10 ? AppColors.primaria : const Color(0xFFD32F2F))),
            Text(expired ? '0' : '$seconds', style: TextStyle(fontFamily: 'Roboto',
              fontSize: 13.sp, fontWeight: FontWeight.w700, color: AppColors.texto)),
          ]),
        ]),
        SizedBox(height: 18.h),
        Text('Você recebe por esta entrega:', textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Roboto', fontSize: 13.sp, color: AppColors.desabilitado)),
        Text('R\$ ${oferta.taxaFrete.toStringAsFixed(2)}', textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Roboto', fontSize: 32.sp, fontWeight: FontWeight.w900,
            color: const Color(0xFF2E7D32))),
        SizedBox(height: 20.h),
        const Divider(color: AppColors.bordaInativa),
        SizedBox(height: 12.h),
        _Address(icon: Icons.store_rounded, label: 'Retirada no Restaurante',
          title: oferta.lojaNome, detail: oferta.lojaEndereco, color: AppColors.primaria),
        SizedBox(height: 14.h),
        _Address(icon: Icons.location_on_rounded, label: 'Entrega no Cliente',
          title: [oferta.clienteBairro, oferta.clienteCidade].whereType<String>().join(' - '),
          color: const Color(0xFF2E7D32)),
        SizedBox(height: 24.h),
        Row(children: [
          Expanded(child: OutlinedButton(key: Key('oferta-recusar-${oferta.id}'),
            onPressed: busy || expired ? null : recusar,
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.texto,
              side: const BorderSide(color: AppColors.bordaInativa),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50.r))),
            child: const Text('Recusar'))),
          SizedBox(width: 12.w),
          Expanded(child: FilledButton(key: Key('oferta-aceitar-${oferta.id}'),
            onPressed: busy || expired ? null : aceitar,
            style: FilledButton.styleFrom(backgroundColor: AppColors.primaria,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50.r))),
            child: const Text('Aceitar corrida'))),
        ]),
      ]),
    );
  }
}

class _Address extends StatelessWidget {
  final IconData icon;
  final String label, title;
  final String? detail;
  final Color color;
  const _Address({required this.icon, required this.label, required this.title,
    required this.color, this.detail});
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Container(padding: EdgeInsets.all(8.r),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
      child: Icon(icon, color: color, size: 20.r)),
    SizedBox(width: 12.w),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontFamily: 'Roboto', fontSize: 11.sp, color: AppColors.desabilitado)),
      Text(title.isEmpty ? 'Endereço do Cliente' : title,
        style: TextStyle(fontFamily: 'Roboto', fontSize: 14.sp, fontWeight: FontWeight.w700, color: AppColors.texto)),
      if (detail?.isNotEmpty == true) Text(detail!, maxLines: 1, overflow: TextOverflow.ellipsis,
        style: TextStyle(fontFamily: 'Roboto', fontSize: 12.sp, color: AppColors.desabilitado)),
    ])),
  ]);
}
