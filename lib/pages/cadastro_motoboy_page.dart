import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../components/botoes/botao_largo_nhac.dart';
import '../globals/theme_colors.dart';
import '../controllers/entrega_provider.dart';
import '../utils/validators.dart';

class CadastroMotoboyPage extends StatefulWidget {
  const CadastroMotoboyPage({super.key});
  @override
  State<CadastroMotoboyPage> createState() => _CadastroMotoboyPageState();
}
class _CadastroMotoboyPageState extends State<CadastroMotoboyPage> {
  final _form = GlobalKey<FormState>();
  final _cpf = TextEditingController(), _cnh = TextEditingController(), _placa = TextEditingController();
  final _modelo = TextEditingController(), _cor = TextEditingController();
  String _tipo = 'MOTO';
  String? _erro;
  bool _busy = false;
  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() { _busy = true; _erro = null; });
    try {
      await context.read<EntregaProvider>().cadastrarEntregador(
        cpf: _cpf.text.replaceAll(RegExp(r'\D'), ''), cnh: _cnh.text.trim(),
        placaVeiculo: _placa.text.trim().toUpperCase(), tipoVeiculo: _tipo,
        modeloVeiculo: _modelo.text.trim().isEmpty ? null : _modelo.text.trim(),
        corVeiculo: _cor.text.trim().isEmpty ? null : _cor.text.trim());
      if (mounted) context.go('/home-motoca');
    } catch (e) { if (mounted) setState(() => _erro = e.toString()); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  @override
  void dispose() { _cpf.dispose(); _cnh.dispose(); _placa.dispose(); _modelo.dispose(); _cor.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.fundo,
    resizeToAvoidBottomInset: true,
    body: SafeArea(child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 600),
      child: Form(key: _form, child: Column(children: [
        Expanded(child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
          children: [
            Align(alignment: Alignment.centerLeft, child: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.texto),
              onPressed: () => context.canPop() ? context.pop() : context.go('/home-motoca'))),
            SizedBox(height: 20.h),
            Text('Cadastre-se como entregador', style: AppTextStyles.titulo()),
            SizedBox(height: 8.h),
            Text('Informe os dados abaixo para começar a receber pedidos de entrega.', style: AppTextStyles.subtitulo()),
            SizedBox(height: 32.h),
            _label('Tipo de Veículo'),
            SizedBox(height: 8.h),
            DropdownButtonFormField<String>(initialValue: _tipo,
              decoration: _input('Selecione seu veículo'),
              items: const [DropdownMenuItem(value: 'MOTO', child: Text('Motocicleta')),
                DropdownMenuItem(value: 'BICICLETA', child: Text('Bicicleta')),
                DropdownMenuItem(value: 'CARRO', child: Text('Carro'))],
              onChanged: _busy ? null : (value) => setState(() => _tipo = value!)),
            SizedBox(height: 24.h),
            _label('CPF'),
            SizedBox(height: 8.h),
            TextFormField(key: const Key('cadastro-cpf'), controller: _cpf,
              decoration: _input('Digite seu CPF'), keyboardType: TextInputType.number,
              validator: Validators.validarCPF),
            SizedBox(height: 24.h),
            _label('Número da CNH'),
            SizedBox(height: 8.h),
            TextFormField(key: const Key('cadastro-cnh'), controller: _cnh,
              decoration: _input('Digite o número da sua CNH'), keyboardType: TextInputType.number,
              validator: Validators.validarCNH),
            SizedBox(height: 24.h),
            _label('Placa do Veículo'),
            SizedBox(height: 8.h),
            TextFormField(key: const Key('cadastro-placa'), controller: _placa,
              decoration: _input('Ex: ABC-1234 ou BRA2E19'),
              textCapitalization: TextCapitalization.characters, validator: Validators.validarPlaca),
            SizedBox(height: 24.h),
            _label('Modelo do Veículo (opcional)'),
            SizedBox(height: 8.h),
            TextFormField(controller: _modelo, decoration: _input('Ex: Honda CG 160 Fan'),
              textCapitalization: TextCapitalization.words,
              validator: (value) => (value?.trim().length ?? 0) > 60 ? 'Máximo de 60 caracteres' : null),
            SizedBox(height: 24.h),
            _label('Cor do Veículo (opcional)'),
            SizedBox(height: 8.h),
            TextFormField(controller: _cor, decoration: _input('Ex: Preta'),
              textCapitalization: TextCapitalization.words,
              validator: (value) => (value?.trim().length ?? 0) > 30 ? 'Máximo de 30 caracteres' : null),
            SizedBox(height: 32.h),
            Container(padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(color: AppColors.secundaria.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: AppColors.secundaria.withValues(alpha: 0.3))),
              child: Row(children: [
                Icon(Icons.info_outline, color: AppColors.secundaria),
                SizedBox(width: 12.w),
                Expanded(child: Text('Após o cadastro, você ficará offline. Ative sua disponibilidade na tela inicial.',
                  style: AppTextStyles.subtitulo())),
              ])),
            if (_erro != null) Padding(padding: EdgeInsets.symmetric(vertical: 16.h),
              child: Text(_erro!, style: const TextStyle(color: Colors.red))),
          ],
        )),
        Padding(padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 32.h),
          child: BotaoLargoNhac(key: const Key('cadastro-entregador-submit'),
            texto: _busy ? 'Salvando…' : 'Cadastrar como entregador',
            carregando: _busy, onPressed: _busy ? null : _save)),
      ])),
    ))),
  );

  Widget _label(String text) => Text(text, style: TextStyle(
    fontFamily: 'Roboto', fontSize: 14.sp, fontWeight: FontWeight.w600, color: AppColors.texto));

  InputDecoration _input(String hint) => InputDecoration(
    hintText: hint, filled: true, fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r),
      borderSide: const BorderSide(color: AppColors.bordaInativa)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r),
      borderSide: const BorderSide(color: AppColors.bordaInativa)),
  );
}
