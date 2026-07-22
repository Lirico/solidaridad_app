import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  // Header
  static const TextStyle headerTitle = TextStyle(
    color: Colors.white,
    fontSize: 26,
    fontWeight: FontWeight.bold,
    letterSpacing: 1.5,
  );

  static const TextStyle headerSubtitle = TextStyle(
    color: Colors.white,
    fontSize: 18,
    fontWeight: FontWeight.w300,
  );

  // Screen titles
  static const TextStyle screenTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: Colors.black87,
  );

  // Form labels
  static const TextStyle formLabel = TextStyle(
    fontWeight: FontWeight.w500,
    color: Colors.black87,
  );

  // Link buttons
  static const TextStyle linkButton = TextStyle(
    color: AppColors.primaryOrange,
    fontWeight: FontWeight.w500,
  );
}
