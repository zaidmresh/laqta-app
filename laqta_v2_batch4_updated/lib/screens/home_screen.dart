import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/product_card.dart';
import '../widgets/section_title.dart';

class HomeScreen extends StatelessWidget {
  final AppState appState;
  const HomeScreen({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    final featured = appState.featuredProducts;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 90),
      children: [
        // Hero
        Container(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              colors: [AppColors.teal, AppColors.tealDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('سوق الجمعة — بين يديك',
                  style: AppTextStyles.body(
                      size: 11.5, weight: FontWeight.bold, color: const Color(0xFFE7C77E))),
              const SizedBox(height: 6),
              Text('اكتشف لَقطتك القادمة',
                  style: AppTextStyles.heading(size: 23, color: AppColors.white)),
              const SizedBox(height: 8),
              Text(
                'قطع نادرة، أثاث عتيق، ومقتنيات لا تجدها إلا في سوق الجمعة — الآن على تطبيق واحد.',
                style: AppTextStyles.body(size: 12.5, color: const Color(0xFFD9E6E4)),
              ),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: () => appState.go(AppView.search),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brass,
                  foregroundColor: AppColors.tealDark,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                  textStyle: AppTextStyles.body(size: 13, weight: FontWeight.bold),
                ),
                child: const Text('تصفّح المنتجات ⟵'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        SectionTitle(title: 'الأقسام'),
        SizedBox(
          height: 84,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: kCategories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 9),
            itemBuilder: (context, i) {
              final c = kCategories[i];
              return GestureDetector(
                onTap: () {
                  appState.setCategory(c.id);
                  appState.go(AppView.search);
                },
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        border: Border.all(color: AppColors.sandLine),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,
                      child: Text(c.icon, style: const TextStyle(fontSize: 22)),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: 62,
                      child: Text(
                        c.name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: AppTextStyles.body(
                            size: 10.5, weight: FontWeight.bold, color: AppColors.inkSoft),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        SectionTitle(
          title: 'الأحدث في السوق',
          linkText: 'عرض الكل',
          onLinkTap: () => appState.go(AppView.search),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: featured.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.72,
          ),
          itemBuilder: (context, i) {
            final p = featured[i];
            return ProductCard(
              product: p,
              isFavorite: appState.isFavorite(p),
              role: appState.role,
              onTap: () => appState.openProduct(p.id),
              onToggleFavorite: () => appState.toggleFavorite(p),
            );
          },
        ),
      ],
    );
  }
}
