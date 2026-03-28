import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF6366F1);
  static const Color secondary = Color(0xFF8B5CF6);
  static const Color background = Color(0xFF0F172A);
  static const Color surface = Color(0xFF1E293B);
  static const Color textBody = Color(0xFF94A3B8);
  static const Color textHeading = Color(0xFFF8FAFC);
  static const Color accent = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppTextStyles {
  static const TextStyle heading = TextStyle(
    color: AppColors.textHeading,
    fontSize: 24,
    fontWeight: FontWeight.bold,
    fontFamily: 'Outfit',
  );

  static const TextStyle body = TextStyle(
    color: AppColors.textBody,
    fontSize: 16,
    fontFamily: 'Outfit',
  );

  static const TextStyle caption = TextStyle(
    color: AppColors.textBody,
    fontSize: 14,
    fontFamily: 'Outfit',
  );
}
