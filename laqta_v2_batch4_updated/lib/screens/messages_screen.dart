import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/db_service.dart';
import '../state/app_state.dart';
import '../widgets/common_widgets.dart';
import '../widgets/section_title.dart';

class MessagesScreen extends StatelessWidget {
  final AppState appState;
  const MessagesScreen({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      return const Center(child: Text('يجب تسجيل الدخول لعرض الرسائل'));
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: DbService.instance.watchConversations(uid),
      builder: (context, snapshot) {
        final conversations = snapshot.data ?? const [];
        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 90),
          children: [
            SectionTitle(title: 'الرسائل'),
            if (!snapshot.hasData)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (conversations.isEmpty)
              const EmptyState(
                icon: '💬',
                title: 'لا توجد محادثات بعد',
                subtitle: 'ستظهر هنا محادثاتك مع البائعين والمشترين',
              )
            else
              ...conversations.map((c) {
                final names = Map<String, dynamic>.from(c['names'] as Map? ?? {});
                final participants = List<String>.from(c['participants'] as List? ?? []);
                final otherUid = participants.firstWhere((p) => p != uid, orElse: () => '');
                final otherName = names[otherUid] as String? ?? 'مستخدم';
                final productTitle = c['product_title'] as String? ?? '';
                final last = c['last_message'] as String? ?? '';
                final preview = last.length > 28 ? '${last.substring(0, 28)}…' : last;

                return ListRow(
                  leading: NameAvatar(name: otherName),
                  title: otherName,
                  subtitle: productTitle.isEmpty ? preview : '$productTitle — $preview',
                  onTap: () => appState.openConversation(
                    id: c['id'] as String,
                    withName: otherName,
                    productTitle: productTitle,
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}
