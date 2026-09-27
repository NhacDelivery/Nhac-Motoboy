import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../globals/theme_colors.dart';

class StatusToggleButton extends StatefulWidget {
  final bool estaOnline;
  final bool carregando;
  final ValueChanged<bool> onChanged;

  const StatusToggleButton({
    super.key,
    required this.estaOnline,
    this.carregando = false,
    required this.onChanged,
  });

  @override
  State<StatusToggleButton> createState() => _StatusToggleButtonState();
}

class _StatusToggleButtonState extends State<StatusToggleButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.7).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final online = widget.estaOnline;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.carregando ? null : () => widget.onChanged(!online),
        borderRadius: BorderRadius.circular(50.r),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 7.h),
          decoration: BoxDecoration(
            color: online ? const Color(0xFFE8F5E9) : Colors.white,
            borderRadius: BorderRadius.circular(50.r),
            border: Border.all(
              color: online
                  ? const Color(0xFF81C784)
                  : const Color(0xFFFFCDD2).withValues(alpha: 0.8),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: online
                    ? const Color(0xFF4CAF50).withValues(alpha: 0.22)
                    : AppColors.texto.withValues(alpha: 0.07),
                blurRadius: 12.r,
                offset: Offset(0, 4.h),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 18.r,
                height: 18.r,
                child: Center(
                  child: widget.carregando
                      ? CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primaria,
                        )
                      : online
                      ? AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            return Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 10.r * _pulseAnimation.value,
                                  height: 10.r * _pulseAnimation.value,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFF4CAF50)
                                        .withValues(alpha: 0.35 / _pulseAnimation.value),
                                  ),
                                ),
                                Container(
                                  width: 9.r,
                                  height: 9.r,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xFF2E7D32),
                                  ),
                                ),
                              ],
                            );
                          },
                        )
                      : Container(
                          width: 9.r,
                          height: 9.r,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFE53935),
                          ),
                        ),
                ),
              ),
              SizedBox(width: 8.w),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: online
                      ? const Color(0xFF1B5E20)
                      : const Color(0xFF5D201C),
                ),
                child: Text(widget.carregando
                    ? (online ? 'SAINDO...' : 'CONECTANDO...')
                    : (online ? 'DISPONÍVEL' : 'INDISPONÍVEL')),
              ),
              SizedBox(width: 8.w),
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 32.w,
                height: 18.h,
                padding: EdgeInsets.all(2.r),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20.r),
                  color: online
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFFE0E0E0),
                ),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  alignment: online ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    width: 14.r,
                    height: 14.r,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 3,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
