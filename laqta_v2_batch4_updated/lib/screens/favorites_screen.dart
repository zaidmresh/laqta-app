import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../widgets/product_card.dart';
import '../widgets/section_title.dart';

class FavoritesScreen extends StatelessWidget {
  final AppState appState;
  const FavoritesScreen({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    final list = appState.products.where((p) => appState.isFavorite(p)).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 90),
      children: [
        SectionTitle(title: 'المفضلة'),
        if (list.isEmpty)
          const EmptyState(
            icon: '🤍',
            title: 'لا توجد عناصر مفضلة بعد',
            subtitle: 'اضغط على أيقونة القلب لحفظ ما يعجبك',
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: list.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.72,
            ),
            itemBuilder: (context, i) {
              final p = list[i];
              return ProductCard(
                product: p,
                isFavorite: true,
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
