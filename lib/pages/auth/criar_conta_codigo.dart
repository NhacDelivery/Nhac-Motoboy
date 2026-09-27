import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:provider/provider.dart';

import '../../components/botoes/botao_largo_nhac.dart';
import '../../components/seta_voltar.dart';
import '../../controllers/cadastro_controller.dart';
import '../../globals/theme_colors.dart';
import '../../globals/ui_utils.dart';
import '../../services/auth_service.dart';

/// Segunda etapa do cadastro por e-mail (a primeira, EmailMotocaPage, já
/// disparou o código via enviarCodigoCadastro antes de navegar pra cá).
///
/// Espelha VerificacaoNumeroPage (fluxo por SMS) — mesmo componente de PIN,
/// mesmo timer de reenvio — só troca o backend chamado.
class CriarContaCodigoPage extends StatefulWidget {
  const CriarContaCodigoPage({super.key});

  @override
  State<CriarContaCodigoPage> createState() => _CriarContaCodigoPageState();
}

class _CriarContaCodigoPageState extends State<CriarContaCodigoPage> {
  final TextEditingController _pinController = TextEditingController();
  final AuthService _authService = AuthService();

  int _tempoRestante = 60;
  bool _podeReenviar = false;
  bool _codigoValido = false;
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _iniciarTimer();
  }

  void _iniciarTimer() {
    setState(() {
      _tempoRestante = 60;
      _podeReenviar = false;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_tempoRestante > 0) {
        setState(() => _tempoRestante--);
      } else {
        setState(() => _podeReenviar = true);
        timer.cancel();
      }
    });
  }

  Future<void> _reenviarCodigo() async {
    if (!_podeReenviar) return;
    final email = context.read<CadastroController>().email;
    try {
      await _authService.enviarCodigoCadastro(email);
      _iniciarTimer();
      if (mounted) context.showSuccess('Código reenviado para $email!');
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    // NÃO descartar _pinController aqui: o PinCodeTextField ainda
    // referencia o controller durante o unmount e dispara
    // "A TextEditingController was used after being disposed".
    // O controller é coletado pelo GC quando o widget sai.
    super.dispose();
  }

  Future<void> _confirmarCodigo() async {
    if (!_codigoValido) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = context.read<CadastroController>().email;
      final codigo = _pinController.text.trim();

      await _authService.confirmarEmailCadastro(email, codigo);

      if (!mounted) return;
      context.showSuccess('E-mail verificado!');
      context.push('/criar-conta-dados');
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = context.watch<CadastroController>().email;

    return Scaffold(
      backgroundColor: AppColors.fundo,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SetaVoltar(),
                      SizedBox(height: 20.h),
                      Text('Confirme seu e-mail', style: AppTextStyles.titulo()),
                      SizedBox(height: 8.h),
                      Text(
                        'Insira o código de 6 dígitos que enviamos para $email',
                        style: AppTextStyles.subtitulo(),
                      ),
                      SizedBox(height: 32.h),
                      PinCodeTextField(
                        appContext: context,
                        length: 6,
                        controller: _pinController,
                        keyboardType: TextInputType.number,
                        animationType: AnimationType.fade,
                        autoFocus: true,
                        cursorColor: AppColors.primaria,
                        textStyle: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 22.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.texto,
                        ),
                        pinTheme: PinTheme(
                          shape: PinCodeFieldShape.box,
                          borderRadius: BorderRadius.circular(12.r),
                          fieldHeight: 52.h,
                          fieldWidth: 44.w,
                          activeColor: AppColors.primaria,
                          selectedColor: AppColors.primaria,
                          inactiveColor: AppColors.bordaInativa,
                          activeFillColor: Colors.transparent,
                          selectedFillColor: Colors.transparent,
                          inactiveFillColor: Colors.transparent,
                          borderWidth: 1.5,
                        ),
                        enableActiveFill: true,
                        onChanged: (valor) {
                          setState(() => _codigoValido = valor.trim().length == 6);
                        },
                        onCompleted: (valor) => _confirmarCodigo(),
                      ),
                      SizedBox(height: 20.h),
                      Center(
                        child: TextButton(
                          onPressed: _podeReenviar ? _reenviarCodigo : null,
                          child: Text(
                            _podeReenviar
                                ? 'Reenviar código por e-mail'
                                : 'Reenviar código em 00:${_tempoRestante.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              color: _podeReenviar ? AppColors.primaria : AppColors.desabilitado,
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      if (_errorMessage != null)
                        Padding(
                          padding: EdgeInsets.only(top: 16.h),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, color: Colors.red, size: 16.r),
                              SizedBox(width: 8.w),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(color: Colors.red, fontSize: 13.sp, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              BotaoLargoNhac(
                texto: 'Confirmar',
                carregando: _isLoading,
                onPressed: _codigoValido ? _confirmarCodigo : null,
              ),
              SizedBox(height: 12.h),
            ],
          ),
        ),
      ),
    );
  }
}
