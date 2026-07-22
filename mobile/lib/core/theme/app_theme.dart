import 'package:flutter/material.dart';
import 'app_colors.dart';

final ThemeData appTheme = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: AppColors.scaffoldBackground,

  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.primaryOrange,
    primary: AppColors.primaryOrange,
    secondary: AppColors.primaryOrange,
  ),

  inputDecorationTheme: InputDecorationTheme(
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8.0),
      borderSide: const BorderSide(color: AppColors.inputBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8.0),
      borderSide: const BorderSide(color: AppColors.inputBorderEnabled),
    ),
    filled: true,
    fillColor: AppColors.cardBackground,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  ),

  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primaryOrange,
      foregroundColor: AppColors.textWhite,
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    ),
  ),
);
