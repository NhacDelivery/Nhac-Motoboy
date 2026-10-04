import 'package:flutter/material.dart';

import 'theme_colors.dart';

final nhacTheme = ThemeData(
  useMaterial3: true,
  fontFamily: 'Roboto',
  scaffoldBackgroundColor: AppColors.fundo,
  colorScheme: ColorScheme.light(
    primary: AppColors.primaria,
    onPrimary: AppColors.texto,
    surface: AppColors.fundo,
    onSurface: AppColors.texto,
    error: AppColors.erro,
  ),
  cardTheme: CardThemeData(
    color: AppColors.superficie,
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.fundo,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
    contentPadding: const EdgeInsets.all(16),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      foregroundColor: AppColors.texto,
      minimumSize: const Size(48, 48),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.texto,
      minimumSize: const Size(48, 48),
      side: const BorderSide(color: AppColors.texto),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: AppColors.texto,
      minimumSize: const Size(48, 48),
    ),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.fundo,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
  ),
);
