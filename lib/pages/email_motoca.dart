import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../components/botoes/botao_largo_nhac.dart';
import '../components/nhac_input_field.dart';
import '../components/seta_voltar.dart';
import '../controllers/cadastro_controller.dart';
import '../globals/theme_colors.dart';
import '../globals/ui_utils.dart';
import '../services/auth_service.dart';
import '../utils/validators.dart';

class EmailMotocaPage extends StatefulWidget {
  const EmailMotocaPage({super.key});

  @override
  State<EmailMotocaPage> createState() => _EmailMotocaPageState();
}

class _EmailMotocaPageState extends State<EmailMotocaPage> {
  final TextEditingController _emailController = TextEditingController();

  bool _emailValido = false;
  String? _erroEmail;
  bool _isLoading = false;
  bool _isGoogleLoading = false;

  final List<String> _dominios = [
    '@gmail.com',
    '@hotmail.com',
    '@outlook.com',
    '@yahoo.com.br',
    '@icloud.com',
  ];

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_verificarEmail);
  }

  void _verificarEmail() {
    if (!mounted) return;
    final texto = _emailController.text.trim();
    final erroTemp = Validators.validarEmail(texto);

    setState(() {
      _erroEmail = texto.isEmpty ? null : erroTemp;
      _emailValido = erroTemp == null && texto.isNotEmpty;
    });
  }

  @override
  void dispose() {
    _emailController.removeListener(_verificarEmail);
    _emailController.dispose();
    super.dispose();
  }

  final AuthService _authService = AuthService();

  Future<void> _avancarParaSenha() async {
    final email = _emailController.text.trim();
    if (!_emailValido) return;

    setState(() => _isLoading = true);

    // Antes disso, o botão "Continuar" só dava um delay fake de 300ms e
    // navegava direto pra tela de senha, sem checar nada com o backend — o
    // login por e-mail nunca chamava nenhuma API de verdade.
    final cadastroController = context.read<CadastroController>();
    cadastroController.setEmail(email);

    try {
      final existe = await _authService.checarEmail(email);
      cadastroController.setEmailExiste(existe);

      if (!existe) {
        // E-mail novo: dispara o código de verificação já aqui, antes de
        // navegar, pra tela seguinte já abrir com o código a caminho.
        await _authService.enviarCodigoCadastro(email);
      }

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (existe) {
        context.push('/continuar-senha');
      } else {
        context.push('/criar-conta-codigo');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      context.showError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _fazerLoginGoogle() async {
    setState(() => _isGoogleLoading = true);
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() => _isGoogleLoading = false);
    context.showInfo('Use seu e-mail ou telefone para entrar. O login Google ainda não está disponível.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fundo,
      resizeToAvoidBottomInset: true,
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
                      Text(
                        'Qual o seu email?',
                        style: AppTextStyles.titulo(),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        'Precisamos dele para iniciar o seu cadastro ou aceder ao aplicativo.',
                        style: AppTextStyles.subtitulo(),
                      ),
                      SizedBox(height: 24.h),
                      NhacInputField(
                        controller: _emailController,
                        autofocus: true,
                        keyboardType: TextInputType.emailAddress,
                        hintText: 'Email',
                        errorText: _erroEmail,
                        onFieldSubmitted: (_) => _avancarParaSenha(),
                      ),
                      SizedBox(height: 14.h),
                      SizedBox(
                        height: 38.h,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _dominios.length,
                          separatorBuilder: (_, _) => SizedBox(width: 8.w),
                          itemBuilder: (context, index) => ActionChip(
                            label: Text(_dominios[index]),
                            backgroundColor: AppColors.secundaria.withValues(alpha: 0.4),
                            labelStyle: TextStyle(
                              fontFamily: 'Roboto',
                              color: AppColors.texto,
                              fontWeight: FontWeight.w600,
                              fontSize: 13.sp,
                            ),
                            side: BorderSide(
                              color: AppColors.secundaria,
                              width: 1.w,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20.r),
                            ),
                            onPressed: () {
                              final textoAtual = _emailController.text.trim();
                              final indexArroba = textoAtual.indexOf('@');
                              final prefixo = indexArroba != -1
                                  ? textoAtual.substring(0, indexArroba)
                                  : textoAtual;
                              if (prefixo.isNotEmpty) {
                                _emailController.text =
                                    '$prefixo${_dominios[index]}';
                                _emailController.selection =
                                    TextSelection.fromPosition(
                                  TextPosition(
                                      offset: _emailController.text.length),
                                );
                              }
                            },
                          ),
                          physics: const BouncingScrollPhysics(),
                        ),
                      ),
                      SizedBox(height: 24.h),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Divider(
                              color: AppColors.bordaInativa,
                              thickness: 1.h,
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12.w),
                            child: Text(
                              'ou',
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                color: AppColors.desabilitado,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: AppColors.bordaInativa,
                              thickness: 1.h,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 24.h),
                      BotaoLargoNhac(
                        texto: 'Continuar com o Google',
                        isSecundario: true,
                        carregando: _isGoogleLoading,
                        icone: SvgPicture.asset(
                          'assets/google-logo.svg',
                          height: 22.h,
                          width: 22.w,
                        ),
                        onPressed: _fazerLoginGoogle,
                      ),
                      SizedBox(height: 14.h),
                      BotaoLargoNhac(
                        texto: 'Continuar com o telefone',
                        isSecundario: true,
                        icone: Icon(
                          Icons.phone_rounded,
                          size: 22.r,
                          color: AppColors.texto,
                        ),
                        onPressed: () {
                          context.push('/insira-telefone');
                        },
                      ),
                    ],
                  ),
                ),
              ),
              BotaoLargoNhac(
                texto: 'Continuar',
                carregando: _isLoading,
                onPressed: _emailValido ? _avancarParaSenha : null,
              ),
              SizedBox(height: 12.h),
            ],
          ),
        ),
      ),
    );
  }
}
