import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../components/botoes/botao_largo_nhac.dart';
import '../../../../controllers/user_provider.dart';
import '../../../../globals/theme_colors.dart';
import '../../../../globals/ui_utils.dart';

class NotificacoesPage extends StatefulWidget {
  const NotificacoesPage({super.key});
  @override
  State<NotificacoesPage> createState() => _NotificacoesPageState();
}

class _NotificacoesPageState extends State<NotificacoesPage> {
  static const labels = {
    'notificarNovoPedido': 'Novos pedidos',
    'notificarMensagens': 'Mensagens',
    'notificarAvaliacoes': 'Avaliações',
    'notificarNovidades': 'Novidades da plataforma',
  };
  Map<String, bool>? _values;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await context.read<UserProvider>().service.obterPreferenciasNotificacao();
      if (!mounted) return;
      setState(() => _values = {for (final key in labels.keys) key: data[key] ?? false});
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_saving || _values == null) return;
    setState(() => _saving = true);
    try {
      await context.read<UserProvider>().service.atualizarPreferenciasNotificacao(_values!);
      if (!mounted) return;
      context.showSuccess('Preferências salvas.');
      context.pop();
    } catch (e) {
      if (mounted) context.showError(e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.fundo,
    appBar: AppBar(leading: IconButton(
      icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.texto),
      onPressed: () => context.pop())),
    body: SafeArea(child: Column(children: [
      Expanded(child: ListView(padding: EdgeInsets.symmetric(horizontal: 24.w), children: [
        SizedBox(height: 16.h),
        Text('Notificações', style: AppTextStyles.titulo()),
        SizedBox(height: 12.h),
        Text('Escolha quais avisos deseja receber.', style: AppTextStyles.subtitulo()),
        SizedBox(height: 28.h),
        if (_loading)
          const Center(child: CircularProgressIndicator(color: AppColors.primaria)),
        if (_error != null) TextButton(onPressed: _load, child: Text('$_error Tentar novamente')),
        if (_values != null && !_loading) ...[
          for (final entry in labels.entries) SwitchListTile(
            title: Text(entry.value),
            value: _values![entry.key]!,
            activeThumbColor: AppColors.primaria,
            onChanged: _saving ? null : (value) => setState(() => _values![entry.key] = value),
          ),
        ],
      ])),
      if (_values != null) Padding(
        padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 32.h),
        child: BotaoLargoNhac(texto: 'Salvar preferências', carregando: _saving,
          onPressed: _saving || _loading ? null : _save)),
    ])),
  );
}
