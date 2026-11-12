import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SectionTitle extends StatelessWidget {
  final String title;
  final String? linkText;
  final VoidCallback? onLinkTap;
  final double fontSize;

  const SectionTitle({
    super.key,
    required this.title,
    this.linkText,
    this.onLinkTap,
    this.fontSize = 17,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: AppTextStyles.heading(size: fontSize)),
          if (linkText != null)
            GestureDetector(
              onTap: onLinkTap,
              child: Text(
                linkText!,
                style: AppTextStyles.body(
                    size: 12, weight: FontWeight.bold, color: AppColors.brassDark),
              ),
            ),
        ],
      ),
    );
  }
}

/// حالة فارغة (Empty state) تُستخدم في القوائم بدون نتائج
class EmptyState extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;

  const EmptyState({super.key, required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 20),
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 38)),
          const SizedBox(height: 10),
          Text(title, style: AppTextStyles.heading(size: 14)),
          const SizedBox(height: 4),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: AppTextStyles.body(size: 12.5, color: AppColors.inkSoft)),
        ],
      ),
    );
  }
}
