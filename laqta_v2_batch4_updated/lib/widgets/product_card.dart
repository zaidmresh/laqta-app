import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

// FIX (تقرير الأداء - تحسين مهم): البطاقة تاخذ isFavorite وshowStatus كقيم
// جاهزة بدل ما تقرأ appState كامل بنفسها — أي تغيير بحالة التطبيق ما
// عاد يفرض إعادة بناء كل بطاقات المنتجات، بس اللي تغيّرت قيمتها فعليًا.
class ProductCard extends StatelessWidget {
  final Product product;
  final bool isFavorite;
  final UserRole role;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

  const ProductCard({
    super.key,
    required this.product,
    required this.isFavorite,
    required this.role,
    required this.onTap,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final bg = kThumbColors[product.cat] ?? AppColors.card;
    final showStatus = role != UserRole.buyer && product.status != ProductStatus.approved;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          border: Border.all(color: AppColors.sandLine),
          borderRadius: BorderRadius.circular(14),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 1.35,
              child: Stack(
                children: [
                  Container(
                    color: bg,
                    alignment: Alignment.center,
                    child: product.imageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: product.imageUrl!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            memCacheWidth: 400,
                            errorWidget: (context, url, error) =>
                                Text(product.emoji.isEmpty ? '📦' : product.emoji,
                                    style: const TextStyle(fontSize: 34)),
                            placeholder: (context, url) =>
                                const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          )
                        : Text(product.emoji, style: const TextStyle(fontSize: 34)),
                  ),
                  Positioned(
                    top: 7,
                    left: 7,
                    child: GestureDetector(
                      onTap: onToggleFavorite,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: AppColors.white.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(isFavorite ? '❤️' : '🤍', style: const TextStyle(fontSize: 13)),
                      ),
                    ),
                  ),
                  if (showStatus)
                    Positioned(
                      top: 7,
                      right: 7,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: product.status == ProductStatus.pending
                              ? AppColors.brass
                              : AppColors.danger,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          product.status == ProductStatus.pending ? 'قيد المراجعة' : 'مرفوض',
                          style: AppTextStyles.body(
                              size: 9, color: AppColors.white, weight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 9, 10, 11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 34,
                    child: Text(
                      product.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body(size: 12.5, weight: FontWeight.bold, color: AppColors.ink),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('${product.price.toStringAsFixed(product.price % 1 == 0 ? 0 : 2)} د.أ',
                      style: AppTextStyles.body(
                          size: 13.5, weight: FontWeight.w900, color: AppColors.tealDark)),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(kCatMap[product.cat]?.name ?? '',
                          style: AppTextStyles.body(size: 10, color: AppColors.inkSoft)),
                      Text(product.date, style: AppTextStyles.body(size: 10, color: AppColors.inkSoft)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
