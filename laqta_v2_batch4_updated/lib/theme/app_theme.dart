import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ألوان التطبيق (مطابقة لمتغيرات CSS في النسخة الأصلية)
class AppColors {
  static const ink = Color(0xFF241F1B);
  static const inkSoft = Color(0xFF4A4038);
  static const paper = Color(0xFFF1EAD9);
  static const paper2 = Color(0xFFE7DCC0);
  static const card = Color(0xFFFBF7EC);
  static const brass = Color(0xFFB9862B);
  static const brassDark = Color(0xFF8F6720);
  static const teal = Color(0xFF1E4E4A);
  static const tealDark = Color(0xFF11302D);
  static const tealTint = Color(0xFFDCE9E6);
  static const rust = Color(0xFFA8452E);
  static const rustTint = Color(0xFFF0DAD2);
  static const sandLine = Color(0xFFD8C9A3);
  static const white = Color(0xFFFFFCF5);
  static const success = Color(0xFF3E7A52);
  static const successTint = Color(0xFFDCEADE);
  static const danger = Color(0xFFB23A2E);
  static const dangerTint = Color(0xFFF3DAD4);
}

class AppTextStyles {
  // عنوان بخط "Reem Kufi" (يُستخدم للعناوين الكبيرة والشعار)
  static TextStyle heading({double size = 18, Color? color, FontWeight? weight}) {
    return GoogleFonts.reemKufi(
      fontSize: size,
      color: color ?? AppColors.tealDark,
      fontWeight: weight ?? FontWeight.w400,
    );
  }

  static TextStyle body({double size = 13.5, Color? color, FontWeight? weight}) {
    return GoogleFonts.tajawal(
      fontSize: size,
      color: color ?? AppColors.ink,
      fontWeight: weight ?? FontWeight.normal,
    );
  }
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.paper2,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.teal,
      primary: AppColors.teal,
      secondary: AppColors.brass,
      surface: AppColors.card,
    ),
    fontFamily: GoogleFonts.tajawal().fontFamily,
  );
  return base.copyWith(
    textTheme: GoogleFonts.tajawalTextTheme(base.textTheme),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.paper,
      elevation: 0,
      foregroundColor: AppColors.tealDark,
      titleTextStyle: AppTextStyles.heading(size: 16),
    ),
  );
}
