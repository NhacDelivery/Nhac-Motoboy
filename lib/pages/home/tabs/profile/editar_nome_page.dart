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

class EditarNomePage extends StatefulWidget {
  const EditarNomePage({super.key});

  @override
  State<EditarNomePage> createState() => _EditarNomePageState();
}

class _EditarNomePageState extends State<EditarNomePage> {
  late final TextEditingController _nameController;
  bool _isLoading = false;
  bool _nomeValido = false;
  String? _erroNome;

  @override
  void initState() {
    super.initState();
    final nomeAtual = context.read<UserProvider>().nome;
    _nameController = TextEditingController(text: nomeAtual);
    _nameController.addListener(_verificarNome);
    _verificarNome();
  }

  @override
  void dispose() {
    _nameController.removeListener(_verificarNome);
    _nameController.dispose();
    super.dispose();
  }

  void _verificarNome() {
    if (!mounted) return;
    final texto = _nameController.text;
    final erroTemp = Validators.validarNome(texto);

    setState(() {
      _erroNome = erroTemp;
      _nomeValido = erroTemp == null && texto.isNotEmpty;
    });
  }

  Future<void> _salvarNome() async {
    try {
      setState(() => _isLoading = true);
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;

      await context.read<UserProvider>().atualizarNome(_nameController.text);

      if (!mounted) return;
      context.showSuccess('Nome atualizado com sucesso!');
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
                        'Editar Nome',
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
                        'Seu nome é utilizado para identificação nas coletas com os restaurantes e nas entregas aos clientes.',
                        style: TextStyle(
                          fontSize: 16.sp,
                          color: Colors.grey.shade800,
                          height: 1.5,
                          fontFamily: 'Roboto',
                        ),
                      ),
                      SizedBox(height: 28.h),
                      NhacInputField(
                        controller: _nameController,
                        onChanged: (value) => _verificarNome(),
                        textCapitalization: TextCapitalization.words,
                        hintText: 'Nome completo',
                        errorText: _erroNome,
                        validator: Validators.validarNome,
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
                onPressed: _nomeValido ? _salvarNome : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
