import 'package:flutter/material.dart';

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
  Widget build(BuildContext context) => Material(
    color: AppColors.superficie,
    elevation: 6,
    shadowColor: AppColors.texto.withValues(alpha: .15),
    borderRadius: BorderRadius.circular(32),
    child: Padding(
      padding: const EdgeInsets.all(6),
      child: Row(
        children: [
          _item(context, Icons.two_wheeler_rounded, 'Início', 0),
          _item(context, Icons.receipt_long_rounded, 'Corridas', 1),
          _item(context, Icons.account_balance_wallet_rounded, 'Frete', 2),
          _item(context, Icons.person_outline_rounded, 'Perfil', 3),
        ],
      ),
    ),
  );
  Widget _item(BuildContext context, IconData icon, String label, int index) {
    final selected = index == selectedIndex;
    return Expanded(
      child: Semantics(
        key: index == 1 ? const Key('historico-button') : null,
        selected: selected,
        child: TextButton(
          onPressed: () => onItemSelected(index),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.texto,
            backgroundColor: selected ? AppColors.fundo : Colors.transparent,
            minimumSize: const Size(48, 56),
            padding: const EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 24),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
