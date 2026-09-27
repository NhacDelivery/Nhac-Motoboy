import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../components/botoes/botao_largo_nhac.dart';
import '../../../../components/nhac_input_field.dart';
import '../../../../controllers/user_provider.dart';
import '../../../../globals/theme_colors.dart';
import '../../../../globals/ui_utils.dart';

class EditarSenhaPage extends StatefulWidget {
  const EditarSenhaPage({super.key});

  @override
  State<EditarSenhaPage> createState() => _EditarSenhaPageState();
}

class _EditarSenhaPageState extends State<EditarSenhaPage> {
  final TextEditingController _senhaAtualController = TextEditingController();
  final TextEditingController _novaSenhaController = TextEditingController();
  final TextEditingController _confirmarSenhaController = TextEditingController();

  bool _isLoading = false;
  bool _formValido = false;
  bool _mostrarSenhaAtual = false;
  bool _mostrarNovaSenha = false;
  bool _mostrarConfirmar = false;

  String? _erroSenhaAtual;
  String? _erroNovaSenha;
  String? _erroConfirmarSenha;

  @override
  void initState() {
    super.initState();
    _senhaAtualController.addListener(_validarForm);
    _novaSenhaController.addListener(_validarForm);
    _confirmarSenhaController.addListener(_validarForm);
  }

  @override
  void dispose() {
    _senhaAtualController.dispose();
    _novaSenhaController.dispose();
    _confirmarSenhaController.dispose();
    super.dispose();
  }

  void _validarForm() {
    if (!mounted) return;

    final senhaAtual = _senhaAtualController.text;
    final novaSenha = _novaSenhaController.text;
    final confirmarSenha = _confirmarSenhaController.text;

    setState(() {
      _erroSenhaAtual = senhaAtual.isEmpty ? 'Informe a senha atual' : null;

      if (novaSenha.isEmpty) {
        _erroNovaSenha = 'Informe a nova senha';
      } else if (novaSenha.length < 6) {
        _erroNovaSenha = 'A nova senha deve ter no mínimo 6 caracteres';
      } else {
        _erroNovaSenha = null;
      }

      if (confirmarSenha.isEmpty) {
        _erroConfirmarSenha = 'Confirme a nova senha';
      } else if (confirmarSenha != novaSenha) {
        _erroConfirmarSenha = 'As senhas não coincidem';
      } else {
        _erroConfirmarSenha = null;
      }

      _formValido = _erroSenhaAtual == null &&
          _erroNovaSenha == null &&
          _erroConfirmarSenha == null &&
          senhaAtual.isNotEmpty &&
          novaSenha.isNotEmpty &&
          confirmarSenha.isNotEmpty;
    });
  }

  Future<void> _processarAtualizacaoSenha() async {
    try {
      setState(() => _isLoading = true);
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;

      await context.read<UserProvider>().atualizarSenha(_senhaAtualController.text, _novaSenhaController.text);

      if (!mounted) return;
      context.showSuccess('Senha alterada com sucesso!');
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
                        'Alterar Senha',
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
                        'Escolha uma senha forte com no mínimo 6 caracteres para manter seu acesso seguro.',
                        style: TextStyle(
                          fontSize: 16.sp,
                          color: Colors.grey.shade800,
                          height: 1.5,
                          fontFamily: 'Roboto',
                        ),
                      ),
                      SizedBox(height: 28.h),
                      Text(
                        'Senha Atual',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF5D201C),
                          fontFamily: 'Roboto',
                        ),
                      ),
                      SizedBox(height: 8.h),
                      NhacInputField(
                        controller: _senhaAtualController,
                        obscureText: !_mostrarSenhaAtual,
                        errorText: _erroSenhaAtual,
                        hintText: 'Digite sua senha atual',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _mostrarSenhaAtual ? Icons.visibility : Icons.visibility_off,
                            color: const Color(0xFF5D201C),
                          ),
                          onPressed: () => setState(() => _mostrarSenhaAtual = !_mostrarSenhaAtual),
                        ),
                      ),
                      SizedBox(height: 20.h),
                      Text(
                        'Nova Senha',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF5D201C),
                          fontFamily: 'Roboto',
                        ),
                      ),
                      SizedBox(height: 8.h),
                      NhacInputField(
                        controller: _novaSenhaController,
                        obscureText: !_mostrarNovaSenha,
                        errorText: _erroNovaSenha,
                        hintText: 'Digite a nova senha',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _mostrarNovaSenha ? Icons.visibility : Icons.visibility_off,
                            color: const Color(0xFF5D201C),
                          ),
                          onPressed: () => setState(() => _mostrarNovaSenha = !_mostrarNovaSenha),
                        ),
                      ),
                      SizedBox(height: 20.h),
                      Text(
                        'Confirmar Nova Senha',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF5D201C),
                          fontFamily: 'Roboto',
                        ),
                      ),
                      SizedBox(height: 8.h),
                      NhacInputField(
                        controller: _confirmarSenhaController,
                        obscureText: !_mostrarConfirmar,
                        errorText: _erroConfirmarSenha,
                        hintText: 'Repita a nova senha',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _mostrarConfirmar ? Icons.visibility : Icons.visibility_off,
                            color: const Color(0xFF5D201C),
                          ),
                          onPressed: () => setState(() => _mostrarConfirmar = !_mostrarConfirmar),
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
                onPressed: _formValido ? _processarAtualizacaoSenha : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
