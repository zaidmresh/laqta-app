import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../widgets/common_widgets.dart';
import '../widgets/section_title.dart';

class NotificationsScreen extends StatelessWidget {
  final AppState appState;
  const NotificationsScreen({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 30),
      children: [
        SubHeader(title: 'الإشعارات', onBack: appState.back),
        const EmptyState(
          icon: '🔔',
          title: 'لا توجد إشعارات حاليًا',
          subtitle: 'ستظهر هنا آخر التحديثات المتعلقة بحسابك',
        ),
      ],
    );
  }
}
