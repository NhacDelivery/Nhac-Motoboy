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

class EditarVeiculoPage extends StatefulWidget {
  const EditarVeiculoPage({super.key});
  @override
  State<EditarVeiculoPage> createState() => _EditarVeiculoPageState();
}

class _EditarVeiculoPageState extends State<EditarVeiculoPage> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _placa, _modelo, _cor;
  late String _tipo;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final profile = context.read<EntregaProvider>().perfilEntregador;
    _placa = TextEditingController(text: profile?.placaVeiculo ?? '');
    _modelo = TextEditingController(text: profile?.modeloVeiculo ?? '');
    _cor = TextEditingController(text: profile?.corVeiculo ?? '');
    _tipo = const ['MOTO', 'BICICLETA', 'CARRO'].contains(profile?.tipoVeiculo)
        ? profile!.tipoVeiculo! : 'MOTO';
  }

  @override
  void dispose() {
    _placa.dispose(); _modelo.dispose(); _cor.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await context.read<EntregaProvider>().atualizarVeiculo(
        tipoVeiculo: _tipo,
        placaVeiculo: _placa.text.trim().toUpperCase(),
        modeloVeiculo: _modelo.text.trim(),
        corVeiculo: _cor.text.trim(),
      );
      if (!mounted) return;
      context.showSuccess('Veículo atualizado com sucesso!');
      context.pop();
    } catch (e) {
      if (mounted) context.showError(e.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final emEntrega = context.watch<EntregaProvider>().emEntrega;
    return Scaffold(
      backgroundColor: AppColors.fundo,
      appBar: AppBar(leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.texto),
        onPressed: () => context.pop(),
      )),
      body: SafeArea(child: Form(key: _form, child: Column(children: [
        Expanded(child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          children: [
            SizedBox(height: 16.h),
            Text('Veículo & Moto', style: AppTextStyles.titulo()),
            SizedBox(height: 12.h),
            Text('Atualize os dados do veículo cadastrado para as entregas.', style: AppTextStyles.subtitulo()),
            SizedBox(height: 28.h),
            _label('Tipo de Veículo'), SizedBox(height: 8.h),
            DropdownButtonFormField<String>(initialValue: _tipo,
              decoration: const InputDecoration(filled: true, fillColor: Colors.white,
                border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'MOTO', child: Text('Motocicleta')),
                DropdownMenuItem(value: 'BICICLETA', child: Text('Bicicleta')),
                DropdownMenuItem(value: 'CARRO', child: Text('Carro')),
              ],
              onChanged: _saving || emEntrega ? null : (value) => setState(() => _tipo = value!)),
            SizedBox(height: 20.h),
            _label('Modelo do Veículo'), SizedBox(height: 8.h),
            NhacInputField(controller: _modelo, hintText: 'Ex: Honda CG 160 Fan',
              textCapitalization: TextCapitalization.words,
              validator: (v) => (v?.trim().length ?? 0) > 60 ? 'Máximo de 60 caracteres' : null),
            SizedBox(height: 20.h),
            _label('Placa do Veículo'), SizedBox(height: 8.h),
            NhacInputField(controller: _placa, hintText: 'Ex: ABC-1234 ou BRA2E19',
              textCapitalization: TextCapitalization.characters, validator: Validators.validarPlaca),
            SizedBox(height: 20.h),
            _label('Cor do Veículo'), SizedBox(height: 8.h),
            NhacInputField(controller: _cor, hintText: 'Ex: Preta',
              textCapitalization: TextCapitalization.words,
              validator: (v) => (v?.trim().length ?? 0) > 30 ? 'Máximo de 30 caracteres' : null),
            if (emEntrega) ...[
              SizedBox(height: 20.h),
              Text('Conclua a entrega atual antes de trocar de veículo.', style: AppTextStyles.subtitulo()),
            ],
          ],
        )),
        Padding(padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 32.h),
          child: BotaoLargoNhac(texto: 'Salvar alterações', carregando: _saving,
            onPressed: _saving || emEntrega ? null : _save)),
      ]))),
    );
  }

  Widget _label(String text) => Text(text, style: TextStyle(fontFamily: 'Roboto',
    fontSize: 14.sp, fontWeight: FontWeight.w600, color: AppColors.texto));
}
