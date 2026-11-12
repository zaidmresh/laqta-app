import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/product_card.dart';
import '../widgets/section_title.dart';

class SearchScreen extends StatefulWidget {
  final AppState appState;
  const SearchScreen({super.key, required this.appState});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.appState.search);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = widget.appState;
    final term = appState.search.trim();
    var list = appState.products.toList();
    if (appState.cat != null) {
      list = list.where((p) => p.cat == appState.cat).toList();
    }
    if (term.isNotEmpty) {
      list = list
          .where((p) =>
              p.title.contains(term) || (kCatMap[p.cat]?.name.contains(term) ?? false))
          .toList();
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 90),
      children: [
        // شريط البحث
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.card,
            border: Border.all(color: AppColors.sandLine),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.search, size: 18, color: AppColors.teal),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _controller,
                  textAlign: TextAlign.right,
                  decoration: const InputDecoration(
                    hintText: 'ابحث عن قطعة، فئة، أو بائع...',
                    border: InputBorder.none,
                  ),
                  style: AppTextStyles.body(size: 13.5),
                  onChanged: (v) => appState.setSearch(v),
                ),
              ),
              GestureDetector(
                onTap: () {},
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    border: Border.all(color: AppColors.sandLine),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.tune, size: 16, color: AppColors.tealDark),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 84,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: kCategories.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 9),
            itemBuilder: (context, i) {
              if (i == 0) {
                final active = appState.cat == null;
                return _catChip('✨', 'الكل', active, () => appState.setCategory(null));
              }
              final c = kCategories[i - 1];
              final active = appState.cat == c.id;
              return _catChip(c.icon, c.name, active, () => appState.setCategory(c.id));
            },
          ),
        ),
        SectionTitle(title: '${list.length} نتيجة', fontSize: 15),
        if (list.isEmpty)
          const EmptyState(
            icon: '🕵️‍♀️',
            title: 'لا توجد نتائج',
            subtitle: 'جرّب كلمة بحث أو فئة مختلفة',
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

  Widget _catChip(String icon, String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: active ? AppColors.teal : AppColors.card,
              border: Border.all(color: active ? AppColors.teal : AppColors.sandLine),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Text(icon, style: const TextStyle(fontSize: 22)),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 62,
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: AppTextStyles.body(
                size: 10.5,
                weight: FontWeight.bold,
                color: active ? AppColors.tealDark : AppColors.inkSoft,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
