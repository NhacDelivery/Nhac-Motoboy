import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../controllers/entrega_provider.dart';
import '../../../controllers/user_provider.dart';
import '../../../globals/theme_colors.dart';

class PerfilTab extends StatelessWidget {
  const PerfilTab({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    final delivery = context.watch<EntregaProvider>();
    final profile = delivery.perfilEntregador;
    return SafeArea(child: ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 120.h),
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _CircleIcon(icon: Icons.notifications_none, onTap: () => ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Você não tem novas notificações.')))),
          Text('Perfil', style: TextStyle(fontFamily: 'Roboto', fontSize: 18.sp,
              fontWeight: FontWeight.bold, color: AppColors.texto)),
          _CircleIcon(icon: Icons.more_horiz, onTap: () => _accountOptions(context, delivery)),
        ]),
        SizedBox(height: 32.h),
        Row(children: [
          Stack(children: [
            InkWell(
              onTap: () => context.push('/editar-foto'),
              customBorder: const CircleBorder(),
              child: Container(
                width: 80.r, height: 80.r,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white,
                  boxShadow: [BoxShadow(color: AppColors.texto.withValues(alpha: 0.1), blurRadius: 10.r, offset: Offset(0, 4.h))]),
                child: ClipOval(child: user.fotoPerfil == null
                    ? Icon(Icons.two_wheeler_rounded, size: 44.r, color: AppColors.primaria)
                    : user.fotoPerfil!.startsWith('http')
                        ? Image.network(user.fotoPerfil!, fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Icon(Icons.two_wheeler_rounded, size: 44.r, color: AppColors.primaria))
                        : Image.file(File(user.fotoPerfil!), fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Icon(Icons.two_wheeler_rounded, size: 44.r, color: AppColors.primaria))),
              ),
            ),
            Positioned(bottom: 0, right: 0, child: Semantics(
              button: true, label: 'Alterar foto de perfil',
              child: InkWell(onTap: () => context.push('/editar-foto'),
                customBorder: const CircleBorder(),
                child: Container(padding: EdgeInsets.all(6.r),
                  decoration: const BoxDecoration(color: AppColors.texto, shape: BoxShape.circle),
                  child: Icon(Icons.edit_rounded, size: 14.r, color: Colors.white))),
            )),
          ]),
          SizedBox(width: 16.w),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(user.nome.isEmpty ? 'Parceiro Motoca' : user.nome,
                style: TextStyle(fontFamily: 'Roboto', fontSize: 22.sp, fontWeight: FontWeight.bold, color: AppColors.texto)),
            SizedBox(height: 4.h),
            Text(profile == null ? 'Complete seu cadastro de entregador'
                : '${profile.modeloVeiculo?.isNotEmpty == true ? profile.modeloVeiculo : profile.tipoVeiculo ?? 'Veículo'} • Placa ${profile.placaVeiculo ?? '—'}',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: 'Roboto', fontSize: 12.sp,
                    color: Colors.grey.shade700)),
          ])),
        ]),
        SizedBox(height: 32.h),
        if (user.isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator(color: AppColors.primaria)),
          ),
        if (user.erro != null) TextButton(onPressed: user.carregarDadosReais,
            child: Text('${user.erro} Tentar novamente')),
        SizedBox(height: 20.h),
        _sectionTitle('Sua Conta'),
        SizedBox(height: 16.h),
        _Section(children: [
          _AccountRow(icon: Icons.person_outline, title: 'Dados Pessoais',
            subtitle: user.nome, onTap: () => context.push('/editar-nome')),
          _AccountRow(icon: Icons.photo_camera_outlined, title: 'Foto de Perfil',
            subtitle: 'Alterar foto', onTap: () => context.push('/editar-foto')),
          _AccountRow(icon: Icons.mail_outline, title: 'E-mail',
            subtitle: user.email, onTap: () => context.push('/editar-email')),
          _AccountRow(icon: Icons.phone_outlined, title: 'Telefone',
            subtitle: user.telefone, onTap: () => context.push('/editar-telefone')),
          _AccountRow(icon: Icons.two_wheeler_outlined, title: 'Veículo & Moto',
            subtitle: profile == null ? 'Toque para cadastrar seu veículo'
                : '${profile.modeloVeiculo?.isNotEmpty == true ? profile.modeloVeiculo : profile.tipoVeiculo ?? 'Veículo'} • Placa ${profile.placaVeiculo ?? '—'}',
            onTap: () => context.push(profile == null ? '/cadastro-motoboy' : '/editar-veiculo')),
          if (profile != null) ...[
            _AccountRow(icon: Icons.badge_outlined, title: 'Documentos (CPF & CNH)',
              subtitle: 'Consultar e atualizar', onTap: () => context.push('/editar-documentos')),
            _AccountRow(icon: Icons.credit_card_outlined, title: 'Dados Bancários',
              subtitle: profile.chavePix?.isNotEmpty == true ? 'Chave PIX cadastrada' : 'Cadastrar chave PIX',
              onTap: () => context.push('/editar-dados-bancarios')),
          ],
        ]),
        SizedBox(height: 32.h),
        _sectionTitle('Configurações'),
        SizedBox(height: 16.h),
        _Section(children: [
          _AccountRow(icon: Icons.notifications_none, title: 'Notificações',
            subtitle: 'Preferências de avisos', onTap: () => context.push('/notificacoes')),
          _AccountRow(icon: Icons.help_outline, title: 'Suporte & Ajuda',
            subtitle: 'Dúvidas sobre o aplicativo', onTap: () => _showHelp(context)),
          _AccountRow(icon: Icons.lock_outline, title: 'Alterar senha',
            subtitle: 'Atualizar senha da conta', onTap: () => context.push('/editar-senha')),
          _AccountRow(icon: Icons.logout, title: 'Sair da conta',
            subtitle: 'Desconectar deste celular', key: const Key('logout-button'),
            onTap: delivery.sair),
        ]),
      ],
    ));
  }

  Widget _sectionTitle(String title) => Text(title, style: TextStyle(
    fontFamily: 'Roboto', fontSize: 18.sp, fontWeight: FontWeight.bold, color: AppColors.texto));

  void _showHelp(BuildContext context) => showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24.r))),
    builder: (ctx) => SafeArea(child: Padding(
      padding: EdgeInsets.all(24.r),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionTitle('Ajuda'),
        SizedBox(height: 16.h),
        Text('Para receber ofertas, mantenha o GPS ligado, permita o acesso à localização e ative a disponibilidade na home.',
          style: AppTextStyles.subtitulo()),
        SizedBox(height: 12.h),
        Text('Os ganhos e o histórico de corridas ficam nas abas inferiores. Durante uma entrega, abra a rota pela home ou por Pedidos.',
          style: AppTextStyles.subtitulo()),
        SizedBox(height: 20.h),
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar')),
      ]),
    )),
  );

  void _accountOptions(BuildContext context, EntregaProvider delivery) {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 32.h),
        decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(40.r))),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionTitle('Opções da Conta'),
          SizedBox(height: 28.h),
          ListTile(leading: const Icon(Icons.logout), title: const Text('Sair da conta'),
            onTap: () { Navigator.pop(ctx); delivery.sair(); }),
          SizedBox(height: 24.h),
          SizedBox(width: double.infinity, child: FilledButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Voltar'))),
        ]),
      ));
  }
}

class _CircleIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleIcon({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(40.r),
    child: Container(width: 40.r, height: 40.r,
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.6), shape: BoxShape.circle),
      child: Icon(icon, color: AppColors.texto)));
}

class _Section extends StatelessWidget {
  final List<Widget> children;
  const _Section({required this.children});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(24.r),
      boxShadow: [BoxShadow(color: AppColors.texto.withValues(alpha: 0.03), blurRadius: 15.r, offset: Offset(0, 5.h))]),
    child: Column(children: [for (var i = 0; i < children.length; i++) ...[
      children[i],
      if (i < children.length - 1) Divider(height: 1, indent: 64.w, color: Colors.grey.shade100),
    ]]));
}

class _AccountRow extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback? onTap;
  const _AccountRow({super.key, required this.icon, required this.title, required this.subtitle, this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(24.r),
    child: Padding(padding: EdgeInsets.all(16.w), child: Row(children: [
      Container(padding: EdgeInsets.all(10.w),
        decoration: BoxDecoration(color: const Color(0xFFFF6961).withValues(alpha: 0.1), shape: BoxShape.circle),
        child: Icon(icon, color: const Color(0xFFFF6961), size: 24.r)),
      SizedBox(width: 16.w),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontFamily: 'Roboto', fontSize: 15.sp, fontWeight: FontWeight.w600, color: AppColors.texto)),
        SizedBox(height: 2.h),
        Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(fontFamily: 'Roboto', fontSize: 12.sp,
            color: Colors.grey.shade600)),
      ])),
      if (onTap != null) Icon(Icons.chevron_right, color: Colors.grey.shade400),
    ])));
}
