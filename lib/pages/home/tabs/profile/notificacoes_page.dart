import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../components/botoes/botao_largo_nhac.dart';
import '../../../../controllers/user_provider.dart';
import '../../../../globals/theme_colors.dart';
import '../../../../globals/ui_utils.dart';
import '../../../../services/push_service.dart';

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
  bool _registeringPush = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await context
          .read<UserProvider>()
          .service
          .obterPreferenciasNotificacao();
      if (!mounted) return;
      setState(
        () =>
            _values = {for (final key in labels.keys) key: data[key] ?? false},
      );
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _registerPush() async {
    if (_registeringPush) return;
    setState(() => _registeringPush = true);
    try {
      await PushService.shared.registrar();
      if (!mounted) return;
      final erro = PushService.shared.erro;
      if (erro != null) {
        context.showError(erro);
      } else if (PushService.shared.registrado) {
        context.showSuccess('Notificações ativadas neste aparelho.');
      }
    } catch (_) {
      if (mounted) {
        context.showError(
          'Não foi possível ativar os avisos. Tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _registeringPush = false);
    }
  }

  Future<void> _save() async {
    if (_saving || _values == null) return;
    setState(() => _saving = true);
    try {
      await context
          .read<UserProvider>()
          .service
          .atualizarPreferenciasNotificacao(_values!);
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
    appBar: AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.texto),
        onPressed: () => context.pop(),
      ),
    ),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              children: [
                SizedBox(height: 16.h),
                Text('Notificações', style: AppTextStyles.titulo()),
                SizedBox(height: 12.h),
                Text(
                  'Avisos de novas ofertas e mensagens respeitam estas preferências. A disponibilidade é encerrada ao sair do aplicativo; ofertas deixam de chegar quando você fica offline. Mensagens podem chegar em segundo plano quando os avisos do aparelho estão configurados. Atualizações essenciais da corrida permanecem visíveis.',
                  style: AppTextStyles.subtitulo(),
                ),
                SizedBox(height: 16.h),
                if (PushService.shared.ativo) ...[
                  Text(
                    PushService.shared.registrado
                        ? 'Notificações ativadas neste aparelho.'
                        : 'Ative as notificações para receber mensagens em segundo plano.',
                    style: AppTextStyles.subtitulo(),
                  ),
                  if (PushService.shared.erro != null)
                    Text(
                      PushService.shared.erro!,
                      style: AppTextStyles.subtitulo(),
                    ),
                  TextButton(
                    onPressed: _registeringPush ? null : _registerPush,
                    child: _registeringPush
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primaria,
                            ),
                          )
                        : Text(
                            PushService.shared.registrado
                                ? 'Verificar notificações do aparelho'
                                : 'Ativar notificações no aparelho',
                          ),
                  ),
                ] else if (PushService.shared.erro != null)
                  Text(
                    PushService.shared.erro!,
                    style: AppTextStyles.subtitulo(),
                  ),
                SizedBox(height: 28.h),
                if (_loading)
                  const Center(
                    child: CircularProgressIndicator(color: AppColors.primaria),
                  ),
                if (_error != null)
                  TextButton(
                    onPressed: _load,
                    child: Text('$_error Tentar novamente'),
                  ),
                if (_values != null && !_loading) ...[
                  for (final entry in labels.entries)
                    SwitchListTile(
                      title: Text(entry.value),
                      value: _values![entry.key]!,
                      activeThumbColor: AppColors.primaria,
                      onChanged: _saving
                          ? null
                          : (value) =>
                                setState(() => _values![entry.key] = value),
                    ),
                ],
              ],
            ),
          ),
          if (_values != null)
            Padding(
              padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 32.h),
              child: BotaoLargoNhac(
                texto: 'Salvar preferências',
                carregando: _saving,
                onPressed: _saving || _loading ? null : _save,
              ),
            ),
        ],
      ),
    ),
  );
}
