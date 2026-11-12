import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/mock_data.dart';
import '../models/models.dart';
import '../services/db_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/product_image_gallery.dart';
import '../widgets/section_title.dart';

Future<void> _callSeller(BuildContext context, String phone) async {
  final digitsOnly = phone.replaceAll(RegExp(r'[^0-9+]'), '');
  final uri = Uri(scheme: 'tel', path: digitsOnly);
  final ok = await launchUrl(uri);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تعذّر فتح تطبيق الهاتف على هذا الجهاز')),
    );
  }
}

class DetailScreen extends StatelessWidget {
  final AppState appState;
  const DetailScreen({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    final p = appState.selectedProduct;
    if (p == null) {
      return const Center(child: Text('المنتج غير متوفر'));
    }
    final bg = kThumbColors[p.cat] ?? AppColors.card;
    final isFav = appState.isFavorite(p);
    final avg = p.reviews.isNotEmpty
        ? p.reviews.map((r) => r.stars).reduce((a, b) => a + b) / p.reviews.length
        : p.rating;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 30),
      children: [
        SubHeader(title: 'تفاصيل المنتج', onBack: appState.back),
        ProductImageGallery(
          imageUrls: p.imageUrls,
          emoji: p.emoji,
          background: bg,
          height: 190,
          overlay: Positioned(
            top: 10,
            left: 10,
            child: GestureDetector(
              onTap: () => appState.toggleFavorite(p),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.9), shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text(isFav ? '❤️' : '🤍', style: const TextStyle(fontSize: 14)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _tag(kCatMap[p.cat]?.name ?? ''),
            _tag(p.cond),
            if (appState.role != UserRole.buyer) StatusBadge(status: p.status),
          ],
        ),
        const SizedBox(height: 8),
        Text(p.title, style: AppTextStyles.heading(size: 19)),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${p.price.toStringAsFixed(p.price % 1 == 0 ? 0 : 2)} د.أ',
                style: AppTextStyles.heading(size: 25)),
            Row(
              children: [
                StarsRow(rating: avg, fontSize: 12),
                const SizedBox(width: 4),
                Text('(${avg.toStringAsFixed(1)})',
                    style: AppTextStyles.body(size: 11, color: AppColors.inkSoft)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(p.desc, style: AppTextStyles.body(size: 13, color: AppColors.inkSoft)),

        // بطاقة البائع
        Container(
          margin: const EdgeInsets.symmetric(vertical: 14),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: AppColors.card,
            border: Border.all(color: AppColors.sandLine),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Row(
            children: [
              NameAvatar(name: p.seller),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.seller, style: AppTextStyles.body(size: 13, weight: FontWeight.bold)),
                    Row(
                      children: [
                        StarsRow(rating: p.rating, fontSize: 12),
                        const SizedBox(width: 4),
                        Text('${p.rating}',
                            style: AppTextStyles.body(size: 11, color: AppColors.inkSoft)),
                      ],
                    ),
                  ],
                ),
              ),
              if (appState.role == UserRole.buyer)
                OutlinedButton(
                  onPressed: () => appState.contactSeller(p),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.tealDark,
                    side: const BorderSide(color: AppColors.teal, width: 1.5),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                  ),
                  child: Text('راسل البائع', style: AppTextStyles.body(size: 12, weight: FontWeight.bold)),
                ),
            ],
          ),
        ),

        if (appState.role == UserRole.buyer &&
            p.sellerUid != Supabase.instance.client.auth.currentUser?.id &&
            p.contactAddress != null &&
            p.contactAddress!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                const Text('📍', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(p.contactAddress!,
                      style: AppTextStyles.body(size: 12.5, color: AppColors.inkSoft)),
                ),
              ],
            ),
          ),

        if (appState.role == UserRole.buyer &&
            p.sellerUid != Supabase.instance.client.auth.currentUser?.id &&
            p.contactPhone != null &&
            p.contactPhone!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _callSeller(context, p.contactPhone!),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brass,
                  foregroundColor: AppColors.tealDark,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                  elevation: 0,
                ),
                child: Text('📞 اتصل بالبائع',
                    style: AppTextStyles.body(size: 13.5, weight: FontWeight.bold, color: AppColors.tealDark)),
              ),
            ),
          ),

        if (appState.role == UserRole.buyer)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => appState.contactSeller(p),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.teal,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                elevation: 0,
              ),
              child: Text('💬 تواصل مع البائع',
                  style: AppTextStyles.body(size: 12, weight: FontWeight.bold, color: AppColors.white)),
            ),
          ),

        if (appState.isAdmin && p.status == ProductStatus.pending)
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 10),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _reviewProduct(context, appState, p, 'rejected'),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: AppColors.dangerTint,
                      foregroundColor: AppColors.danger,
                      side: BorderSide.none,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                    ),
                    child: Text('رفض المنتج', style: AppTextStyles.body(size: 13, weight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _reviewProduct(context, appState, p, 'approved'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.teal,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                      elevation: 0,
                    ),
                    child: Text('اعتماد المنتج',
                        style: AppTextStyles.body(size: 13, weight: FontWeight.bold, color: AppColors.white)),
                  ),
                ),
              ],
            ),
          ),

        if (p.sellerUid != null && p.sellerUid == Supabase.instance.client.auth.currentUser?.id)
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 10),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _deleteListing(context, appState, p),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: AppColors.dangerTint,
                      foregroundColor: AppColors.danger,
                      side: BorderSide.none,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                    ),
                    child: Text('حذف الإعلان', style: AppTextStyles.body(size: 13, weight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => appState.startEditProduct(p),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.tealDark,
                      side: const BorderSide(color: AppColors.teal, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                    ),
                    child: Text('تعديل', style: AppTextStyles.body(size: 13, weight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),

        SectionTitle(title: 'التقييمات (${p.reviews.length})', fontSize: 15),
        if (p.reviews.isEmpty)
          Text('لا توجد تقييمات بعد على هذا المنتج.',
              style: AppTextStyles.body(size: 12.5, color: AppColors.inkSoft))
        else
          ...p.reviews.map((r) => Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.sandLine)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(r.name, style: AppTextStyles.body(size: 12.5, weight: FontWeight.bold)),
                        StarsRow(rating: r.stars.toDouble(), fontSize: 11),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(r.text, style: AppTextStyles.body(size: 12, color: AppColors.inkSoft)),
                  ],
                ),
              )),
      ],
    );
  }

  Widget _tag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: AppColors.tealTint, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: AppTextStyles.body(size: 10.5, weight: FontWeight.bold, color: AppColors.tealDark)),
    );
  }
}

Future<void> _reviewProduct(BuildContext context, AppState appState, Product p, String status) async {
  if (p.firestoreId == null) return;
  try {
    await DbService.instance.updateProductStatus(p.firestoreId!, status);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(status == 'approved' ? 'تم اعتماد المنتج' : 'تم رفض المنتج')),
    );
    appState.back();
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذّر تنفيذ العملية، حاول مرة أخرى')));
  }
}

Future<void> _deleteListing(BuildContext context, AppState appState, Product p) async {
  if (p.firestoreId == null) return;
  try {
    await DbService.instance.deleteProduct(p.firestoreId!);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف الإعلان')));
    appState.back();
  } catch (e) {
    if (!context.mounted) return;
    final message = e.toString().replaceFirst('Exception: ', '');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
