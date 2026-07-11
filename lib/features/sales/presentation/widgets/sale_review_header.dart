import 'package:flutter/material.dart';

class SaleReviewHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onBackPressed;

  const SaleReviewHeader({super.key, required this.title, this.onBackPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 180,
      color: const Color(0xFF1A4F9C),
      padding: const EdgeInsets.only(top: 60, left: 24, right: 24),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: onBackPressed,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
