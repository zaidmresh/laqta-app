import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/db_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/section_title.dart';

class AdminScreen extends StatefulWidget {
  final AppState appState;
  const AdminScreen({super.key, required this.appState});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final Set<String> _processing = {};

  Future<void> _reviewProduct(String productId, String status) async {
    setState(() => _processing.add(productId));
    try {
      await DbService.instance.updateProductStatus(productId, status);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(status == 'approved' ? 'تم اعتماد المنتج بنجاح' : 'تم رفض المنتج')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر تنفيذ الإجراء، يرجى المحاولة مرة أخرى')),
      );
    } finally {
      if (mounted) setState(() => _processing.remove(productId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = widget.appState;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 30),
      children: [
        SubHeader(title: 'لوحة الإدارة', onBack: appState.back),
        Builder(builder: (context) {
          final all = appState.adminProducts;
          final pendingReal = all.where((p) => p.status == ProductStatus.pending).toList();
          final loaded = appState.adminProductsLoaded;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _statBox('${all.length}', 'إجمالي المنتجات'),
                  const SizedBox(width: 10),
                  _statBox('${pendingReal.length}', 'بانتظار المراجعة'),
                ],
              ),
              SectionTitle(title: 'قيد المراجعة', fontSize: 14.5),
              if (!loaded)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (pendingReal.isEmpty)
                Text('لا توجد منتجات بانتظار المراجعة 🎉',
                    style: AppTextStyles.body(size: 12.5, color: AppColors.inkSoft))
              else ...[
                Text('اضغط على أي منتج لتصفّح كل صوره ووصفه كاملًا قبل اتخاذ القرار.',
                    style: AppTextStyles.body(size: 11, color: AppColors.inkSoft)),
                const SizedBox(height: 8),
                ...pendingReal.map((p) {
                  final id = p.firestoreId!;
                  final busy = _processing.contains(id);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      border: Border.all(color: AppColors.sandLine),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        GestureDetector(
                          onTap: () => appState.openProduct(id),
                          child: Row(
                            children: [
                              _MiniThumb(product: p),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(p.title,
                                        style: AppTextStyles.body(size: 13, weight: FontWeight.bold)),
                                    Text('بواسطة ${p.seller} · ${p.price} د.أ',
                                        style: AppTextStyles.body(size: 11, color: AppColors.inkSoft)),
                                    if (p.imageUrls.length > 1)
                                      Text('${p.imageUrls.length} صور',
                                          style: AppTextStyles.body(size: 10.5, color: AppColors.tealDark)),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_left, size: 18, color: AppColors.inkSoft),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: busy ? null : () => _reviewProduct(id, 'approved'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.teal,
                                  padding: const EdgeInsets.symmetric(vertical: 9),
                                ),
                                child: Text(busy ? '...' : 'قبول',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: busy ? null : () => _reviewProduct(id, 'rejected'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.danger,
                                  side: const BorderSide(color: AppColors.danger),
                                  padding: const EdgeInsets.symmetric(vertical: 9),
                                ),
                                child: Text(busy ? '...' : 'رفض',
                                    style: const TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          );
        }),
      ],
    );
  }

  Widget _statBox(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          border: Border.all(color: AppColors.sandLine),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(value, style: AppTextStyles.heading(size: 17)),
            const SizedBox(height: 2),
            Text(label, style: AppTextStyles.body(size: 10.5, color: AppColors.inkSoft), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

/// مصغّرة تعرض أول صورة من صور المنتج إن وُجدت، وإلا الإيموجي كبديل.
class _MiniThumb extends StatelessWidget {
  final Product product;
  const _MiniThumb({required this.product});

  @override
  Widget build(BuildContext context) {
    final url = product.imageUrl;
    return Container(
      width: 44,
      height: 44,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: AppColors.tealTint, borderRadius: BorderRadius.circular(10)),
      alignment: Alignment.center,
      child: url != null
          ? CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              width: 44,
              height: 44,
              errorWidget: (context, url, error) => Text(product.emoji.isEmpty ? '📦' : product.emoji,
                  style: const TextStyle(fontSize: 19)),
              placeholder: (context, url) =>
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          : Text(product.emoji.isEmpty ? '📦' : product.emoji, style: const TextStyle(fontSize: 19)),
    );
  }
}
