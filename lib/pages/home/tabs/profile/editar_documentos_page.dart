import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../components/botoes/botao_largo_nhac.dart';
import '../../../../components/nhac_input_field.dart';
import '../../../../controllers/entrega_provider.dart';
import '../../../../globals/theme_colors.dart';
import '../../../../globals/ui_utils.dart';
import '../../../../utils/validators.dart';

class EditarDocumentosPage extends StatefulWidget {
  const EditarDocumentosPage({super.key});
  @override
  State<EditarDocumentosPage> createState() => _EditarDocumentosPageState();
}

class _EditarDocumentosPageState extends State<EditarDocumentosPage> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _cpf, _cnh;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final profile = context.read<EntregaProvider>().perfilEntregador;
    _cpf = TextEditingController(text: profile?.cpf ?? '');
    _cnh = TextEditingController(text: profile?.cnh ?? '');
  }

  @override
  void dispose() { _cpf.dispose(); _cnh.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await context.read<EntregaProvider>().atualizarDocumentos(
        cpf: _cpf.text.replaceAll(RegExp(r'\D'), ''),
        cnh: _cnh.text.replaceAll(RegExp(r'\D'), ''),
      );
      if (!mounted) return;
      context.showSuccess('Documentos atualizados com sucesso!');
      context.pop();
    } catch (e) {
      if (mounted) context.showError(e.toString().replaceFirst('Bad state: ', ''));
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
    body: SafeArea(child: Form(key: _form, child: Column(children: [
      Expanded(child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        children: [
          SizedBox(height: 16.h),
          Text('Documentos do Motoboy', style: AppTextStyles.titulo()),
          SizedBox(height: 12.h),
          Text('Mantenha CPF e CNH atualizados no seu cadastro de entregador.',
            style: AppTextStyles.subtitulo()),
          SizedBox(height: 28.h),
          _label('CPF'), SizedBox(height: 8.h),
          NhacInputField(controller: _cpf, keyboardType: TextInputType.number,
            hintText: '000.000.000-00', validator: Validators.validarCPF),
          SizedBox(height: 20.h),
          _label('Número da CNH'), SizedBox(height: 8.h),
          NhacInputField(controller: _cnh, keyboardType: TextInputType.number,
            hintText: '11 dígitos da CNH', validator: Validators.validarCNH),
        ],
      )),
      Padding(padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 32.h),
        child: BotaoLargoNhac(texto: 'Salvar alterações', carregando: _saving,
          onPressed: _saving ? null : _save)),
    ]))),
  );

  Widget _label(String label) => Text(label, style: TextStyle(fontFamily: 'Roboto',
    fontSize: 14.sp, fontWeight: FontWeight.w600, color: AppColors.texto));
}
