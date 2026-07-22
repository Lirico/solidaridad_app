import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/app_routes.dart';
import '../theme/app_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.loading);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryOrange,
      body: const Center(
        child: Image(image: AssetImage('assets/solidaridad_logo.png')),
      ),
    );
  }
}
