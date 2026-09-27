import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../globals/theme_colors.dart';
import '../../../models/ganhos_entregador_model.dart';
import '../../../services/entregador_service.dart';

/// Antes, esta tela era inteiramente estática: "Saldo Disponível: R$ 0,00"
/// era um texto fixo no código-fonte, sem nenhuma chamada ao backend -
/// mesmo com GET /api/v1/entregador/ganhos (V039) já existindo pra alimentar
/// exatamente isto.
class GanhosTab extends StatefulWidget {
  const GanhosTab({super.key});

  @override
  State<GanhosTab> createState() => _GanhosTabState();
}

enum _Periodo { hoje, seteDias, trintaDias }

extension on _Periodo {
  String get chaveApi => switch (this) {
        _Periodo.hoje => 'HOJE',
        _Periodo.seteDias => 'SETE_DIAS',
        _Periodo.trintaDias => 'TRINTA_DIAS',
      };

  String get rotulo => switch (this) {
        _Periodo.hoje => 'Hoje',
        _Periodo.seteDias => '7 dias',
        _Periodo.trintaDias => '30 dias',
      };
}

class _GanhosTabState extends State<GanhosTab> {
  final EntregadorService _service = EntregadorService();
  _Periodo _periodoSelecionado = _Periodo.hoje;
  GanhosEntregadorModel? _ganhos;
  bool _carregando = true;
  bool _naoEhEntregador = false;
  String? _erro;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _carregarGanhos();
  }

  Future<void> _carregarGanhos() async {
    final requestId = ++_requestId;
    setState(() {
      _carregando = true;
      _erro = null;
      _naoEhEntregador = false;
    });

    try {
      final resultado = await _service.buscarGanhos(periodo: _periodoSelecionado.chaveApi);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _carregando = false;
        if (resultado != null) {
          _ganhos = resultado;
        } else {
          _erro = 'Não foi possível carregar seus ganhos agora.';
        }
      });
    } on EntregadorNaoCadastradoException {
      // Antes, isto caía no mesmo "erro genérico, tente novamente" que um
      // problema de rede de verdade — mas a pessoa só ainda não completou
      // o cadastro de entregador, o que não é bem um "erro" do ponto de
      // vista dela.
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _carregando = false;
        _naoEhEntregador = true;
      });
    } catch (e) {
      if (!mounted || requestId != _requestId) return;
      setState(() { _carregando = false; _erro = e.toString(); });
    }
  }

  void _selecionarPeriodo(_Periodo periodo) {
    if (periodo == _periodoSelecionado) return;
    setState(() => _periodoSelecionado = periodo);
    _carregarGanhos();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _carregarGanhos,
      color: AppColors.primaria,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 110.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Extrato & Carteira', style: AppTextStyles.titulo()),
            SizedBox(height: 8.h),
            Text(
              'Resumo dos seus repasses e corridas finalizadas',
              style: AppTextStyles.subtitulo(),
            ),
            SizedBox(height: 20.h),
            Row(
              children: _Periodo.values
                  .map((p) => Padding(
                        padding: EdgeInsets.only(right: 8.w),
                        child: ChoiceChip(
                          label: Text(p.rotulo),
                          selected: _periodoSelecionado == p,
                          onSelected: (_) => _selecionarPeriodo(p),
                          selectedColor: AppColors.primaria,
                          labelStyle: TextStyle(
                            color: _periodoSelecionado == p ? Colors.white : AppColors.texto,
                            fontWeight: FontWeight.w600,
                          ),
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20.r),
                            side: BorderSide(color: AppColors.bordaInativa),
                          ),
                        ),
                      ))
                  .toList(),
            ),
            SizedBox(height: 20.h),
            if (_carregando)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator(color: AppColors.primaria)),
              )
            else if (_naoEhEntregador)
              _buildNaoEhEntregador()
            else if (_erro != null)
              _buildErro()
            else
              _buildResumo(_ganhos!),
          ],
        ),
      ),
    );
  }

  /// Estado neutro para quem ainda não completou o cadastro de entregador —
  /// nada de errado aconteceu, só ainda não há nada pra mostrar aqui.
  Widget _buildNaoEhEntregador() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20.r)),
      child: Column(
        children: [
          Icon(Icons.two_wheeler_rounded, size: 40.r, color: AppColors.bordaInativa),
          SizedBox(height: 12.h),
          Text(
            'Você ainda não tem ganhos por aqui',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Roboto', fontSize: 15.sp, fontWeight: FontWeight.w700, color: AppColors.texto),
          ),
          SizedBox(height: 6.h),
          Text(
            'Complete seu cadastro de entregador para começar a receber corridas.',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Roboto', fontSize: 13.sp, color: AppColors.desabilitado),
          ),
        ],
      ),
    );
  }

  Widget _buildErro() {
    return Container(
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20.r)),
      child: Column(
        children: [
          Text(_erro!, style: TextStyle(color: AppColors.desabilitado, fontSize: 14.sp)),
          SizedBox(height: 12.h),
          TextButton(onPressed: _carregarGanhos, child: const Text('Tentar novamente')),
        ],
      ),
    );
  }

  Widget _buildResumo(GanhosEntregadorModel ganhos) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(24.r),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20.r),
            boxShadow: [
              BoxShadow(
                color: AppColors.texto.withValues(alpha: 0.06),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ganhos (${_periodoSelecionado.rotulo.toLowerCase()})',
                style: TextStyle(fontFamily: 'Roboto', fontSize: 14.sp, color: AppColors.desabilitado),
              ),
              SizedBox(height: 8.h),
              Text(
                'R\$ ${ganhos.totalGanhos.toStringAsFixed(2)}',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 32.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.texto,
                ),
              ),
              SizedBox(height: 16.h),
              Row(
                children: [
                  _buildEstatistica('Entregas', '${ganhos.totalEntregas}'),
                  SizedBox(width: 24.w),
                  _buildEstatistica('Ticket médio', 'R\$ ${ganhos.ticketMedio.toStringAsFixed(2)}'),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 20.h),
        Text(
          'Por dia',
          style: TextStyle(fontFamily: 'Roboto', fontSize: 15.sp, fontWeight: FontWeight.w700, color: AppColors.texto),
        ),
        SizedBox(height: 12.h),
        ...ganhos.porDia.reversed.map((dia) => _buildLinhaDia(dia)),
      ],
    );
  }

  Widget _buildEstatistica(String rotulo, String valor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(rotulo, style: TextStyle(fontFamily: 'Roboto', fontSize: 12.sp, color: AppColors.desabilitado)),
        Text(
          valor,
          style: TextStyle(fontFamily: 'Roboto', fontSize: 15.sp, fontWeight: FontWeight.w700, color: AppColors.texto),
        ),
      ],
    );
  }

  Widget _buildLinhaDia(GanhoDiaModel dia) {
    final data = dia.data;
    final rotuloData = '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}';
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14.r)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(rotuloData, style: TextStyle(fontFamily: 'Roboto', fontSize: 14.sp, color: AppColors.texto)),
          Text(
            '${dia.entregas} entrega${dia.entregas == 1 ? '' : 's'}',
            style: TextStyle(fontFamily: 'Roboto', fontSize: 13.sp, color: AppColors.desabilitado),
          ),
          Text(
            'R\$ ${dia.valor.toStringAsFixed(2)}',
            style: TextStyle(fontFamily: 'Roboto', fontSize: 14.sp, fontWeight: FontWeight.w700, color: AppColors.texto),
          ),
        ],
      ),
    );
  }
}
