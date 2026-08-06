import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Tema POS embebido (Verifone).
///
/// Reglas operativas fijas:
/// - Inputs: altura 56px, padding interno 16/12, texto 22px, label 16px,
///   helper/error 14px, radio 8px, elevación 0.
/// - Botones primario/secundario: altura 60px, radio 10px, texto 20px,
///   padding horizontal 24px, ancho completo. Diferenciación solo por color.
/// - Iconografía: mínima 24px (nunca menor a 20px).
/// - Separación entre controles 16px; entre grupos 24px.
/// - Elevación 0 o muy sutil. Nunca sombras fuertes.
final ThemeData appTheme = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: AppColors.scaffoldBackground,

  // ---- Paleta (MD3 adaptado a POS) ----
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.primaryOrange,
    primary: AppColors.primaryOrange,
    secondary: AppColors.primaryOrange,
  ),

  // =====================================================
  // Tipografía POS (jerarquía operativa)
  // =====================================================
  textTheme: const TextTheme(
    // Título de pantalla: 24px
    headlineMedium: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.bold,
      color: AppColors.textPrimary,
    ),
    // Subtítulo: 18px
    titleLarge: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    ),
    // Label: 16px
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: AppColors.textPrimary,
    ),
    // Texto secundario / helper: 14px
    bodyMedium: TextStyle(
      fontSize: 14,
      color: AppColors.textSecondary,
    ),
    bodySmall: TextStyle(
      fontSize: 14,
      color: AppColors.textSecondary,
    ),
  ),

  // =====================================================
  // Inputs POS: 56px de alto, radio 8, texto 22px
  // =====================================================
  inputDecorationTheme: InputDecorationTheme(
    // Fuerza altura operativa de 56px (Fitts: target táctil cómodo en POS)
    constraints: const BoxConstraints(minHeight: 56),
    isDense: true,
    filled: true,
    fillColor: AppColors.cardBackground,
    // Padding interno: horizontal 16px, vertical 12px (medida fija)
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    // Nota: el texto digitado (22px) se configura en cada TextFormField
    // mediante `style: TextStyle(fontSize: 22)` ya que InputDecorationTheme
    // no expone textStyle en Flutter.
    // Label: 16px
    labelStyle: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
    floatingLabelStyle: const TextStyle(
      fontSize: 16,
      color: AppColors.primaryOrange,
      fontWeight: FontWeight.w500,
    ),
    // Placeholder: 22px
    hintStyle: const TextStyle(fontSize: 22, color: AppColors.inputPlaceholder),
    // Helper / Error: 14px
    helperStyle: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
    errorStyle: const TextStyle(fontSize: 14, color: AppColors.errorRed),
    // Icono del input: 24px (nunca menos de 20)
    iconColor: AppColors.iconGrey,
    prefixIconColor: AppColors.iconGrey,
    suffixIconColor: AppColors.iconGrey,
    // Radio de bordes: 8px (medida fija)
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8.0),
      borderSide: const BorderSide(color: AppColors.inputBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8.0),
      borderSide: const BorderSide(color: AppColors.inputBorderEnabled),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8.0),
      borderSide: const BorderSide(color: AppColors.primaryOrange, width: 2),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8.0),
      borderSide: const BorderSide(color: AppColors.primaryOrange, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8.0),
      borderSide: const BorderSide(color: AppColors.errorRed),
    ),
  ),

  // =====================================================
  // Botón primario POS: 60px, radio 10, texto 20px
  // =====================================================
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primaryOrange,
      foregroundColor: AppColors.textWhite,
      // Altura operativa 60px + ancho completo
      minimumSize: const Size.fromHeight(60),
      // Radio 10px (medida fija)
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      // Padding horizontal 24px
      padding: const EdgeInsets.symmetric(horizontal: 24),
      textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      elevation: 0, // Elevación 0: sin sombras
      shadowColor: Colors.transparent,
    ),
  ),

  // =====================================================
  // Botón secundario POS: mismas dimensiones, solo color
  // =====================================================
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.primaryOrange,
      // Mismas dimensiones que el primario: 60px + full width
      minimumSize: const Size.fromHeight(60),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      side: const BorderSide(color: AppColors.primaryOrange, width: 1.5),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      elevation: 0,
      shadowColor: Colors.transparent,
    ),
  ),

  // =====================================================
  // AppBar POS: 64px, título 20px, volver 48x48
  // =====================================================
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.primaryOrange,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: false,
    titleTextStyle: TextStyle(
      color: AppColors.textWhite,
      fontSize: 20,
      fontWeight: FontWeight.bold,
    ),
    iconTheme: IconThemeData(color: AppColors.textWhite, size: 24),
    toolbarHeight: 64,
  ),
);
