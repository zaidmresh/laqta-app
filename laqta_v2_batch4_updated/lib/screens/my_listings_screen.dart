import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../state/app_state.dart';
import '../widgets/common_widgets.dart';
import '../widgets/section_title.dart';

class MyListingsScreen extends StatelessWidget {
  final AppState appState;
  const MyListingsScreen({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    final mine = appState.myProducts;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 30),
      children: [
        SubHeader(title: 'منتجاتي', onBack: appState.back),
        if (mine.isEmpty)
          const EmptyState(
            icon: '📦',
            title: 'لا توجد منتجات بعد',
            subtitle: 'اضغط على زر + لإضافة أول منتج',
          )
        else
          ...mine.map((p) => ListRow(
                leading: ThumbBox(emoji: p.emoji, background: kThumbColors[p.cat]!),
                title: p.title,
                subtitle: '${p.price} د.أ · ${kCatMap[p.cat]?.name ?? ''}',
                trailing: StatusBadge(status: p.status),
                onTap: () => appState.openProduct(p.id),
              )),
      ],
    );
  }
}
