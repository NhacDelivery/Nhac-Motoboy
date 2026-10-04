import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../components/botoes/botao_largo_nhac.dart';
import '../../../controllers/entrega_provider.dart';
import '../../../globals/theme_colors.dart';

/// Código fornecido pelo cliente, sem persistência e sem reenvio automático.
class ConfirmarEntregaPage extends StatefulWidget {
  const ConfirmarEntregaPage({super.key});
  @override
  State<ConfirmarEntregaPage> createState() => _ConfirmarEntregaPageState();
}

class _ConfirmarEntregaPageState extends State<ConfirmarEntregaPage> {
  final _codigo = TextEditingController();
  final _form = GlobalKey<FormState>();
  String? _erro;
  DateTime? _bloqueadoAte;
  Timer? _desbloqueio;
  String? _pedidoId;
  bool _enviando = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _pedidoId ??= context.read<EntregaProvider>().entregaAtiva?.pedidoId;
  }

  @override
  void dispose() {
    _desbloqueio?.cancel();
    _codigo.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    if (_enviando || _bloqueadoAte != null || !_form.currentState!.validate()) {
      return;
    }
    final p = context.read<EntregaProvider>();
    if (!p.podeConcluir || p.entregaAtiva?.pedidoId != _pedidoId) return;
    setState(() {
      _enviando = true;
      _erro = null;
    });
    final ok = await p.concluirEntregaAtual(codigo: _codigo.text);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Entrega concluída.')));
      context.go('/home-motoca');
      return;
    }
    final exception = p.erroConclusao;
    final details = exception?.details;
    setState(() {
      _enviando = false;
      _erro =
          p.erro ?? 'Não foi possível confirmar a entrega. Tente novamente.';
      if (exception?.code == 'CODIGO_ENTREGA_INVALIDO' && details is Map) {
        final restantes = details['tentativasRestantes'];
        if (restantes != null) {
          _erro =
              'Código incorreto. Tentativas restantes: $restantes. Confira com o cliente.';
        }
        _codigo.clear();
      }
      if (exception?.code == 'CODIGO_ENTREGA_BLOQUEADO') {
        final value = details is Map ? details['tentativaLiberadaEm'] : null;
        _bloqueadoAte =
            DateTime.tryParse(value?.toString() ?? '') ??
            DateTime.now().add(const Duration(minutes: 10));
        final local = _bloqueadoAte!.toLocal();
        _erro =
            'Tentativas bloqueadas até ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}. Confira o código com o cliente e aguarde.';
        final delay = _bloqueadoAte!.difference(DateTime.now());
        _desbloqueio = Timer(delay.isNegative ? Duration.zero : delay, () {
          if (mounted) setState(() => _bloqueadoAte = null);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<EntregaProvider>();
    final active = p.entregaAtiva;
    final eligible = p.podeConcluir && active?.pedidoId == _pedidoId;
    return Scaffold(
      appBar: AppBar(title: const Text('Confirmar entrega')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Icon(
                  Icons.verified_user_outlined,
                  size: 64,
                  color: AppColors.texto,
                ),
                const SizedBox(height: 24),
                Text(
                  'Pedido nas mãos do cliente',
                  style: AppTextStyles.titulo(),
                ),
                const SizedBox(height: 8),
                Text(
                  'Peça ao cliente o código de quatro números que aparece no rastreio do pedido. Confirme somente após entregar.',
                  style: AppTextStyles.subtitulo(),
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            active?.clienteNome ?? 'Corrida encerrada',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            key: const Key('entrega-codigo'),
                            controller: _codigo,
                            enabled:
                                eligible && !_enviando && _bloqueadoAte == null,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(4),
                            ],
                            maxLength: 4,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 32,
                              letterSpacing: 12,
                              fontWeight: FontWeight.w700,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Código de entrega',
                              hintText: '0000',
                              counterText: '',
                            ),
                            validator: (value) =>
                                RegExp(r'^\d{4}$').hasMatch(value ?? '')
                                ? null
                                : 'Informe os quatro números.',
                            onFieldSubmitted: (_) => _confirmar(),
                          ),
                          if (_erro != null) ...[
                            const SizedBox(height: 16),
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                _erro!,
                                style: const TextStyle(color: AppColors.erro),
                              ),
                            ),
                          ],
                          if (!eligible && !_enviando) ...[
                            const SizedBox(height: 16),
                            const Text(
                              'Esta corrida não está disponível para conclusão. Volte ao início para atualizar o status.',
                            ),
                          ],
                          const SizedBox(height: 24),
                          BotaoLargoNhac(
                            key: const Key('entrega-confirmar'),
                            texto: 'Confirmar entrega',
                            carregando: _enviando,
                            onPressed: eligible && _bloqueadoAte == null
                                ? _confirmar
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _enviando
                      ? null
                      : () => context.go('/home-motoca'),
                  child: const Text('Voltar ao início'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
