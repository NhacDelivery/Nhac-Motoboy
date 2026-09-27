import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../globals/theme_colors.dart';

class NhacBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

  const NhacBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(50.r),
        boxShadow: [
          BoxShadow(
            color: AppColors.texto.withValues(alpha: 0.1),
            blurRadius: 16.r,
            offset: Offset(0, 8.h),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItem(
            icon: Icons.two_wheeler_rounded,
            label: 'Início',
            index: 0,
          ),
          _buildNavItem(
            icon: Icons.receipt_long_rounded,
            label: 'Pedidos',
            index: 1,
          ),
          _buildNavItem(
            icon: Icons.account_balance_wallet_rounded,
            label: 'Ganhos',
            index: 2,
          ),
          _buildNavItem(
            icon: Icons.person_outline_rounded,
            label: 'Perfil',
            index: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = selectedIndex == index;

    return Semantics(
      key: index == 1 ? const Key('historico-button') : null,
      button: true,
      label: label,
      selected: isSelected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onItemSelected(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.fastOutSlowIn,
          padding: EdgeInsets.symmetric(
            horizontal: isSelected ? 20.w : 12.w,
            vertical: 10.h,
          ),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFFEBD9) : Colors.transparent,
            borderRadius: BorderRadius.circular(50.r),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 30.sp,
                color: isSelected
                    ? AppColors.primaria
                    : const Color(0xFFA0A0A0),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 350),
                curve: Curves.fastOutSlowIn,
                child: SizedBox(
                  width: isSelected ? null : 0,
                  child: isSelected
                      ? Padding(
                          padding: EdgeInsets.only(left: 8.w),
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              color: AppColors.primaria,
                              fontWeight: FontWeight.w700,
                              fontSize: 14.sp,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
