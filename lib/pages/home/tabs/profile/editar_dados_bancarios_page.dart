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

class EditarDadosBancariosPage extends StatefulWidget {
  const EditarDadosBancariosPage({super.key});
  @override
  State<EditarDadosBancariosPage> createState() => _EditarDadosBancariosPageState();
}

class _EditarDadosBancariosPageState extends State<EditarDadosBancariosPage> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _chave;
  late String _tipo;
  bool _saving = false;
  static const _tipos = {'CPF': 'CPF', 'CELULAR': 'Celular',
    'EMAIL': 'E-mail', 'ALEATORIA': 'Aleatória'};

  @override
  void initState() {
    super.initState();
    final profile = context.read<EntregaProvider>().perfilEntregador;
    _tipo = _tipos.containsKey(profile?.tipoChavePix) ? profile!.tipoChavePix! : 'CPF';
    _chave = TextEditingController(text: profile?.chavePix ?? '');
  }

  @override
  void dispose() { _chave.dispose(); super.dispose(); }

  String? _validarChave(String? value) {
    final chave = value?.trim() ?? '';
    if (chave.isEmpty) return 'Informe a chave PIX';
    if (chave.length > 255) return 'Máximo de 255 caracteres';
    return switch (_tipo) {
      'CPF' => Validators.validarCPF(chave),
      'CELULAR' => Validators.validarTelefone(chave),
      'EMAIL' => Validators.validarEmail(chave),
      'ALEATORIA' => RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(chave)
          ? null : 'Informe uma chave aleatória válida',
      _ => null,
    };
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await context.read<EntregaProvider>().atualizarDadosBancarios(
        tipoChavePix: _tipo, chavePix: _chave.text.trim());
      if (!mounted) return;
      context.showSuccess('Chave PIX salva no cadastro.');
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
          Text('Dados Bancários', style: AppTextStyles.titulo()),
          SizedBox(height: 12.h),
          Text('Cadastre uma chave PIX no seu perfil. Isso ainda não ativa repasses automáticos.',
            style: AppTextStyles.subtitulo()),
          SizedBox(height: 28.h),
          _label('Tipo de Chave PIX'), SizedBox(height: 12.h),
          Wrap(spacing: 8.w, children: [
            for (final entry in _tipos.entries) ChoiceChip(
              label: Text(entry.value), selected: _tipo == entry.key,
              selectedColor: AppColors.primaria,
              labelStyle: TextStyle(color: _tipo == entry.key ? Colors.white : AppColors.texto),
              onSelected: _saving ? null : (selected) {
                if (selected) setState(() { _tipo = entry.key; _form.currentState?.validate(); });
              }),
          ]),
          SizedBox(height: 24.h),
          _label('Chave PIX'), SizedBox(height: 8.h),
          NhacInputField(controller: _chave, hintText: 'Digite sua chave PIX', validator: _validarChave),
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
