import '../../../../services/auth_service.dart';
import '../../../../utils/formatters.dart';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:provider/provider.dart';

import '../../../../components/botoes/botao_largo_nhac.dart';
import '../../../../components/nhac_input_field.dart';
import '../../../../controllers/user_provider.dart';
import '../../../../globals/theme_colors.dart';
import '../../../../globals/ui_utils.dart';
import '../../../../utils/validators.dart';

class EditarTelefonePage extends StatefulWidget {
  const EditarTelefonePage({super.key});

  @override
  State<EditarTelefonePage> createState() => _EditarTelefonePageState();
}

class _EditarTelefonePageState extends State<EditarTelefonePage> {
  late final TextEditingController _phoneController;
  late final MaskTextInputFormatter _phoneFormatter;
  bool _phoneValido = false;
  String? _erroPhone;
  bool _isLoading = false, _codigoEnviado = false;
  final _codigo = TextEditingController();
  final _auth = AuthService();

  @override
  void initState() {
    super.initState();
    final phoneAtual = context.read<UserProvider>().telefone;
    _phoneFormatter = MaskTextInputFormatter(
      mask: '(##) #####-####',
      filter: {'#': RegExp(r'[0-9]')},
      initialText: telefoneNacional(phoneAtual),
    );
    _phoneController = TextEditingController(
      text: _phoneFormatter.getMaskedText(),
    );
    _phoneController.addListener(_validarTelefone);
    _validarTelefone();
  }

  @override
  void dispose() {
    _phoneController.removeListener(_validarTelefone);
    _phoneController.dispose();
    _codigo.dispose();
    super.dispose();
  }

  void _validarTelefone() {
    if (!mounted) return;
    final texto = _phoneController.text.trim();
    final erroTemp = Validators.validarTelefone(texto);

    setState(() {
      _erroPhone = texto.isEmpty ? null : erroTemp;
      _phoneValido = erroTemp == null && texto.isNotEmpty;
    });
  }

  Future<void> _salvarTelefone() async {
    if (_isLoading) return;
    try {
      setState(() => _isLoading = true);
      if (!mounted) return;

      final telefone = telefoneE164(_phoneController.text);
      if (!_codigoEnviado) {
        await _auth.enviarCodigoTelefone(telefone);
        if (mounted) setState(() => _codigoEnviado = true);
        return;
      }
      final user = context.read<UserProvider>();
      await user.service.confirmarTelefone(telefone, _codigo.text.trim());
      await user.carregarDadosReais(force: true);

      if (!mounted) return;
      context.showSuccess('Telefone atualizado com sucesso!');
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
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Color(0xFF5D201C),
            size: 20,
          ),
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
                        'Editar Telefone',
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
                        'O telefone é fundamental para que o suporte e os estabelecimentos entrem em contato durante as rotas.',
                        style: TextStyle(
                          fontSize: 16.sp,
                          color: Colors.grey.shade800,
                          height: 1.5,
                          fontFamily: 'Roboto',
                        ),
                      ),
                      SizedBox(height: 28.h),
                      const Text('Código do país: +55'),
                      NhacInputField(
                        controller: _phoneController,
                        enabled: !_codigoEnviado && !_isLoading,
                        inputFormatters: [_phoneFormatter],
                        keyboardType: TextInputType.phone,
                        errorText: _erroPhone,
                        hintText: '(00) 00000-0000',
                        validator: Validators.validarTelefone,
                        style: TextStyle(
                          fontSize: 18.sp,
                          color: const Color(0xFF5D201C),
                          fontFamily: 'Roboto',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_codigoEnviado) ...[
                        const SizedBox(height: 16),
                        TextField(
                          controller: _codigo,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          decoration: const InputDecoration(
                            labelText: 'Código recebido por SMS',
                          ),
                        ),
                        TextButton(
                          onPressed: _isLoading
                              ? null
                              : () => setState(() {
                                  _codigoEnviado = false;
                                  _codigo.clear();
                                }),
                          child: const Text('Alterar número'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(
                left: 24.w,
                right: 24.w,
                bottom: 32.h,
                top: 16.h,
              ),
              child: BotaoLargoNhac(
                texto: _codigoEnviado
                    ? 'Confirmar novo telefone'
                    : 'Enviar código por SMS',
                carregando: _isLoading,
                onPressed: _phoneValido ? _salvarTelefone : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
