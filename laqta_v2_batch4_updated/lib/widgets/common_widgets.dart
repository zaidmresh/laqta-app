import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

/// ترويسة شاشة فرعية مع زر رجوع (يعادل .subhead في النسخة الأصلية)
class SubHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBack;

  const SubHeader({super.key, required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.card,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.sandLine),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.chevron_right, size: 18, color: AppColors.tealDark),
            ),
          ),
          const SizedBox(width: 10),
          Text(title, style: AppTextStyles.heading(size: 16)),
        ],
      ),
    );
  }
}

/// صف قائمة عام (list-row) بأيقونة مصغّرة، عنوان ووصف، وسهم
class ListRow extends StatelessWidget {
  final Widget leading;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  const ListRow({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.card,
          border: Border.all(color: AppColors.sandLine),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body(size: 12.5, weight: FontWeight.bold)),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.body(size: 11, color: AppColors.inkSoft)),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
            if (trailing == null)
              const Icon(Icons.chevron_left, size: 18, color: AppColors.inkSoft),
          ],
        ),
      ),
    );
  }
}

/// أيقونة مصغّرة مربعة الحواف (list-thumb)
class ThumbBox extends StatelessWidget {
  final String emoji;
  final Color background;
  final double size;
  const ThumbBox({super.key, required this.emoji, required this.background, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(10)),
      alignment: Alignment.center,
      child: Text(emoji, style: TextStyle(fontSize: size * 0.43)),
    );
  }
}

/// شارة حالة المنتج (badge-status)
class StatusBadge extends StatelessWidget {
  final ProductStatus status;
  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    late Color bg;
    late Color fg;
    late String label;
    switch (status) {
      case ProductStatus.approved:
        bg = AppColors.successTint;
        fg = AppColors.success;
        label = 'منشور';
        break;
      case ProductStatus.pending:
        bg = const Color(0xFFF5E6C8);
        fg = AppColors.brassDark;
        label = 'قيد المراجعة';
        break;
      case ProductStatus.rejected:
        bg = AppColors.dangerTint;
        fg = AppColors.danger;
        label = 'مرفوض';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: AppTextStyles.body(size: 11, weight: FontWeight.bold, color: fg)),
    );
  }
}

/// عرض تقييم بالنجوم
class StarsRow extends StatelessWidget {
  final double rating;
  final double fontSize;
  const StarsRow({super.key, required this.rating, this.fontSize = 12});

  @override
  Widget build(BuildContext context) {
    final rounded = rating.round().clamp(0, 5);
    final text = '${'★' * rounded}${'☆' * (5 - rounded)}';
    return Text(text, style: TextStyle(fontSize: fontSize, color: AppColors.brass, letterSpacing: 1));
  }
}

/// أفاتار دائري بحرف أول من الاسم
class NameAvatar extends StatelessWidget {
  final String name;
  final double size;
  const NameAvatar({super.key, required this.name, this.size = 42});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [AppColors.brass, AppColors.brassDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0] : '؟',
        style: AppTextStyles.body(size: size * 0.36, weight: FontWeight.bold, color: AppColors.white),
      ),
    );
  }
}
