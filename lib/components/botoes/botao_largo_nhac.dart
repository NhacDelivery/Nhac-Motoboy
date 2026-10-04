import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../globals/theme_colors.dart';

class BotaoLargoNhac extends StatelessWidget {
  final String texto;
  final VoidCallback? onPressed;
  final bool carregando;
  final Widget? icone;
  final bool isSecundario;

  const BotaoLargoNhac({
    super.key,
    required this.texto,
    this.onPressed,
    this.carregando = false,
    this.icone,
    this.isSecundario = false,
  });

  @override
  Widget build(BuildContext context) {
    const Color corPrimaria = AppColors.primaria;
    const Color corEscura = AppColors.texto;
    const Color corTextoClaro = AppColors.texto;
    const Color corDesabilitada = AppColors.desabilitado;

    return LayoutBuilder(
      builder: (context, constraints) {
        final label =
            TextPainter(
              text: TextSpan(
                text: texto,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.1,
                ),
              ),
              textDirection: Directionality.of(context),
              textScaler: MediaQuery.textScalerOf(context),
            )..layout(
              maxWidth: math.max(
                1,
                constraints.maxWidth - 48 - (icone == null ? 0 : 32),
              ),
            );
        final height = math.max(49.h.clamp(48.0, 64.0), label.height + 24);
        label.dispose();
        return SizedBox(
          width: double.infinity,
          height: height,
          child: ElevatedButton(
            onPressed: carregando ? null : onPressed,
            style:
                ElevatedButton.styleFrom(
                  backgroundColor: isSecundario
                      ? Colors.transparent
                      : (onPressed == null
                            ? const Color(0xFFC9BCBC)
                            : corPrimaria),
                  foregroundColor: isSecundario ? corEscura : corTextoClaro,
                  elevation: 0,
                  side: isSecundario
                      ? BorderSide(
                          color: onPressed == null
                              ? const Color(0xFFC9BCBC)
                              : corEscura,
                          width: 1.w,
                        )
                      : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50.r),
                  ),
                  disabledBackgroundColor: isSecundario
                      ? Colors.transparent
                      : const Color(0xFFC9BCBC),
                  disabledForegroundColor: isSecundario
                      ? corDesabilitada
                      : corTextoClaro,
                ).copyWith(
                  backgroundColor: WidgetStateProperty.resolveWith<Color>((
                    states,
                  ) {
                    if (states.contains(WidgetState.disabled)) {
                      return isSecundario
                          ? Colors.transparent
                          : const Color(0xFFC9BCBC);
                    }
                    return isSecundario ? Colors.transparent : corPrimaria;
                  }),
                ),
            child: carregando
                ? SizedBox(
                    height: 24.h,
                    width: 24.h,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isSecundario ? corEscura : corTextoClaro,
                      ),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icone != null) ...[icone!, SizedBox(width: 8.w)],
                      Flexible(
                        child: Text(
                          texto,
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            color: isSecundario ? corEscura : corTextoClaro,
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}
