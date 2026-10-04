import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AppColors {
  static const Color erro = Color(0xFFB3261E);
  static const Color sucesso = Color(0xFF2E7D32);
  static const Color superficie = Colors.white;
  // Cores do Guia de Estilo Nhac
  static const Color primaria = Color(0xFFFF6961); // Vermelho Nhac
  static const Color secundaria = Color(0xFFFCDABB); // Bege Nhac
  static const Color fundo = Color(0xFFFFE7E5); // Creme
  static const Color texto = Color(0xFF5D201C); // Marrom
  static const Color desabilitado = Color(0xFF757575); // Cinza / Subtítulo
  static const Color bordaInativa = Color(0xFFC9BCBC);
}

class AppTextStyles {
  // Tipografia do Guia de Estilo Nhac
  static TextStyle titulo({Color cor = AppColors.texto}) => TextStyle(
    fontFamily: 'Roboto',
    fontWeight: FontWeight.w700, // Bold
    fontSize: 28.sp,
    color: cor,
    height: 1.2,
  );

  static TextStyle subtitulo({Color cor = AppColors.desabilitado}) => TextStyle(
    fontFamily: 'Roboto',
    fontWeight: FontWeight.w400, // Regular
    fontSize: 16.sp,
    color: cor,
    height: 1.3,
  );

  static TextStyle botao({Color cor = AppColors.fundo}) => TextStyle(
    fontFamily: 'Roboto',
    fontWeight: FontWeight.w600, // SemiBold
    fontSize: 18.sp,
    color: cor,
    letterSpacing: 0.1,
  );
}
