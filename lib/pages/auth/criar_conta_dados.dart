import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../components/botoes/botao_largo_nhac.dart';
import '../../components/nhac_input_field.dart';
import '../../components/seta_voltar.dart';
import '../../controllers/cadastro_controller.dart';
import '../../controllers/user_provider.dart';
import '../../globals/theme_colors.dart';
import '../../globals/ui_utils.dart';
import '../../services/api_config.dart';
import '../../services/auth_service.dart';
import '../../utils/validators.dart';

/// Etapa final do cadastro por e-mail: nome, telefone e senha, depois
/// POST /api/v1/auth/registrar. Esta tela simplesmente não existia antes —
/// o cadastro por e-mail (fora do fluxo SMS) não tinha como ser concluído
/// no app do motoboy, mesmo com o backend já suportando o fluxo inteiro.
class CriarContaDadosPage extends StatefulWidget {
  const CriarContaDadosPage({super.key});

  @override
  State<CriarContaDadosPage> createState() => _CriarContaDadosPageState();
}

class _CriarContaDadosPageState extends State<CriarContaDadosPage> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmarSenhaController = TextEditingController();
  final _telefoneMask = MaskTextInputFormatter(mask: '(##) #####-####');
  final AuthService _authService = AuthService();

  bool _senhaVisivel = false;
  bool _confirmarSenhaVisivel = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nomeController.dispose();
    _telefoneController.dispose();
    _senhaController.dispose();
    _confirmarSenhaController.dispose();
    super.dispose();
  }

  Future<void> _finalizarCadastro() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = context.read<CadastroController>().email;
      final telefoneDigitos = _telefoneController.text.replaceAll(RegExp(r'\D'), '');
      final telefoneFormatado = '+55$telefoneDigitos';

      // RegistroRequestDTO exige um id gerado pelo cliente (@NotBlank String
      // id) — não é o backend quem atribui.
      final id = const Uuid().v4();

      final token = await _authService.registrar(
        id: id,
        nome: _nomeController.text.trim(),
        email: email,
        telefone: telefoneFormatado,
        senha: _senhaController.text,
      );

      await ApiConfig.setAuthToken(token);

      if (!mounted) return;

      // Popula o UserProvider já aqui com o que a pessoa acabou de digitar —
      // sem isto, a tela de perfil ficava sem nome/telefone até a próxima
      // vez que a home chamasse carregarDadosReais() (GET /entregador/perfil).
      context.read<UserProvider>().setUsuario(
            id: id,
            nome: _nomeController.text.trim(),
            email: email,
            telefone: telefoneFormatado,
          );

      setState(() => _isLoading = false);

      context.showSuccess('Conta criada com sucesso!');
      // Mesmo destino do fluxo por SMS: completar o cadastro de entregador
      // (CNH, veículo) antes de liberar a home.
      context.go('/cadastro-motoboy');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fundo,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
          child: Form(
            key: _formKey,
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
                        Text('Quase lá!', style: AppTextStyles.titulo()),
                        SizedBox(height: 8.h),
                        Text(
                          'Complete seus dados para criar sua conta.',
                          style: AppTextStyles.subtitulo(),
                        ),
                        SizedBox(height: 24.h),
                        NhacInputField(
                          controller: _nomeController,
                          autofocus: true,
                          hintText: 'Nome completo',
                          validator: Validators.validarNome,
                        ),
                        SizedBox(height: 14.h),
                        NhacInputField(
                          controller: _telefoneController,
                          hintText: 'Telefone',
                          keyboardType: TextInputType.phone,
                          inputFormatters: [_telefoneMask],
                          validator: Validators.validarTelefone,
                        ),
                        SizedBox(height: 14.h),
                        NhacInputField(
                          controller: _senhaController,
                          hintText: 'Senha',
                          obscureText: !_senhaVisivel,
                          validator: Validators.validarSenha,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _senhaVisivel ? Icons.visibility : Icons.visibility_off,
                              color: AppColors.desabilitado,
                            ),
                            onPressed: () => setState(() => _senhaVisivel = !_senhaVisivel),
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          'Mínimo 8 caracteres, com letras e números.',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 12.sp,
                            color: AppColors.desabilitado,
                          ),
                        ),
                        SizedBox(height: 14.h),
                        NhacInputField(
                          controller: _confirmarSenhaController,
                          hintText: 'Confirmar senha',
                          obscureText: !_confirmarSenhaVisivel,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Confirme sua senha';
                            }
                            if (value != _senhaController.text) {
                              return 'As senhas não são iguais';
                            }
                            return null;
                          },
                          suffixIcon: IconButton(
                            icon: Icon(
                              _confirmarSenhaVisivel ? Icons.visibility : Icons.visibility_off,
                              color: AppColors.desabilitado,
                            ),
                            onPressed: () => setState(() => _confirmarSenhaVisivel = !_confirmarSenhaVisivel),
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
                  texto: 'Criar conta',
                  carregando: _isLoading,
                  onPressed: _finalizarCadastro,
                ),
                SizedBox(height: 12.h),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
