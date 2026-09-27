import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../components/botoes/botao_largo_nhac.dart';
import '../../../../components/nhac_input_field.dart';
import '../../../../controllers/user_provider.dart';
import '../../../../globals/theme_colors.dart';
import '../../../../globals/ui_utils.dart';
import '../../../../utils/validators.dart';

class EditarEmailPage extends StatefulWidget {
  const EditarEmailPage({super.key});

  @override
  State<EditarEmailPage> createState() => _EditarEmailPageState();
}

class _EditarEmailPageState extends State<EditarEmailPage> {
  late final TextEditingController _emailController;
  bool _emailValido = false;
  String? _erroEmail;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final emailAtual = context.read<UserProvider>().email;
    _emailController = TextEditingController(text: emailAtual);
    _emailController.addListener(_validarNovoEmail);
    _validarNovoEmail();
  }

  @override
  void dispose() {
    _emailController.removeListener(_validarNovoEmail);
    _emailController.dispose();
    super.dispose();
  }

  void _validarNovoEmail() {
    if (!mounted) return;
    final texto = _emailController.text.trim();
    final erroTemp = Validators.validarEmail(texto);

    setState(() {
      _erroEmail = texto.isEmpty ? null : erroTemp;
      _emailValido = erroTemp == null && texto.isNotEmpty;
    });
  }

  Future<void> _salvarEmail() async {
    try {
      setState(() => _isLoading = true);
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;

      await context.read<UserProvider>().atualizarEmail(_emailController.text.trim());

      if (!mounted) return;
      context.showSuccess('E-mail alterado com sucesso!');
      context.pop();
    } catch (e) {
      if (!mounted) return;
      context.showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fundo,
      appBar: AppBar(
        backgroundColor: AppColors.fundo,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF5D201C), size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 16.h),
                      Text(
                        'Digite seu novo e-mail',
                        style: TextStyle(
                          fontSize: 28.sp,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF5D201C),
                          height: 1.2,
                          fontFamily: 'Roboto',
                        ),
                      ),
                      SizedBox(height: 12.h),
                      Text(
                        'Seu e-mail será atualizado imediatamente na sua conta de parceiro.',
                        style: TextStyle(
                          fontSize: 16.sp,
                          color: Colors.grey.shade800,
                          height: 1.5,
                          fontFamily: 'Roboto',
                        ),
                      ),
                      SizedBox(height: 28.h),
                      NhacInputField(
                        controller: _emailController,
                        onChanged: (value) => _validarNovoEmail(),
                        keyboardType: TextInputType.emailAddress,
                        errorText: _erroEmail,
                        hintText: 'Novo e-mail',
                        validator: Validators.validarEmail,
                        style: TextStyle(
                          fontSize: 18.sp,
                          color: const Color(0xFF5D201C),
                          fontFamily: 'Roboto',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(left: 24.w, right: 24.w, bottom: 32.h, top: 16.h),
              child: BotaoLargoNhac(
                texto: 'Salvar alterações',
                carregando: _isLoading,
                onPressed: _emailValido ? _salvarEmail : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
