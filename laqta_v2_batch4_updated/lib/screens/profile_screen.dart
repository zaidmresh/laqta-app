import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/section_title.dart';

class ProfileScreen extends StatelessWidget {
  final AppState appState;
  const ProfileScreen({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    final mine = appState.myProducts;
    final user = Supabase.instance.client.auth.currentUser;
    final meta = user?.userMetadata;
    final metadataName = meta == null ? null : meta['name'] as String?;
    final displayName = metadataName?.isNotEmpty == true
        ? metadataName!
        : (user?.email ?? 'مستخدم');

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 90),
      children: [
        // رأس الملف الشخصي
        Row(
          children: [
            NameAvatar(name: displayName.substring(0, 1)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(displayName,
                          style: AppTextStyles.body(size: 13.5, weight: FontWeight.bold)),
                      if (appState.isAdmin) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.rustTint,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('🛡️ مسؤول',
                              style: AppTextStyles.body(size: 10, weight: FontWeight.bold, color: AppColors.tealDark)),
                        ),
                      ],
                    ],
                  ),
                  Text(user?.email ?? '',
                      style: AppTextStyles.body(size: 11.5, color: AppColors.inkSoft)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        FutureBuilder<Map<String, dynamic>?>(
          future: user == null ? null : AuthService.instance.fetchUserProfile(user.id),
          builder: (context, snapshot) {
            final profile = snapshot.data;
            if (profile == null) return const SizedBox.shrink();
            final phone = profile['phone'] as String?;
            final location = profile['location'] as String?;
            final createdAtRaw = profile['created_at'] as String?;
            final createdAt = createdAtRaw == null ? null : DateTime.tryParse(createdAtRaw);
            final joinDate = createdAt == null
                ? null
                : '${createdAt.year}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.day.toString().padLeft(2, '0')}';

            final rows = <Widget>[];
            if (phone != null && phone.isNotEmpty) rows.add(_infoRow('📱', phone));
            if (location != null && location.isNotEmpty) rows.add(_infoRow('📍', location));
            if (joinDate != null) rows.add(_infoRow('🗓️', 'عضو منذ $joinDate'));
            if (rows.isEmpty) return const SizedBox.shrink();

            return Container(
              margin: const EdgeInsets.only(bottom: 18),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.card,
                border: Border.all(color: AppColors.sandLine),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows),
            );
          },
        ),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: appState.openEditProfile,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.tealDark,
              side: const BorderSide(color: AppColors.teal, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
            ),
            child: Text('✏️ تعديل الملف الشخصي',
                style: AppTextStyles.body(size: 12.5, weight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 18),
        SectionTitle(title: 'نشاطي', fontSize: 13),
        const SizedBox(height: 8),

        // أي حساب يقدر يبيع الآن — لا يوجد تمييز مشتري/بائع بعد الآن.
        Row(
          children: [
            _statBox('${mine.length}', 'منتجاتي'),
            const SizedBox(width: 10),
            _statBox('${mine.where((p) => p.status == ProductStatus.approved).length}', 'منشورة'),
            const SizedBox(width: 10),
            _statBox('4.8', 'تقييمي'),
          ],
        ),
        const SizedBox(height: 12),
        ListRow(
          leading: const ThumbBox(emoji: '📦', background: AppColors.tealTint),
          title: 'منتجاتي',
          subtitle: 'إدارة الإعلانات والحالة',
          onTap: () => appState.go(AppView.myListings),
        ),

        if (appState.isAdmin)
          ListRow(
            leading: const ThumbBox(emoji: '🛡️', background: AppColors.rustTint),
            title: 'لوحة الإدارة',
            subtitle: 'مراجعة المنتجات وطلبات السحب',
            onTap: () => appState.go(AppView.admin),
          ),

        ListRow(
          leading: const ThumbBox(emoji: '🤍', background: AppColors.paper2),
          title: 'المفضلة',
          subtitle: '${appState.favoriteProductIds.length} عنصر محفوظ',
          onTap: () => appState.go(AppView.favorites),
        ),
        ListRow(
          leading: const ThumbBox(emoji: '🔔', background: AppColors.paper2),
          title: 'الإشعارات',
          onTap: () => appState.go(AppView.notifications),
        ),
        ListRow(
          leading: const ThumbBox(emoji: '🚪', background: AppColors.paper2),
          title: 'تسجيل الخروج',
          subtitle: 'الخروج من الحساب الحالي',
          onTap: () => AuthService.instance.signOut(),
        ),
      ],
    );
  }

  Widget _infoRow(String icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: AppTextStyles.body(size: 12, color: AppColors.inkSoft))),
        ],
      ),
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
            Text(label, style: AppTextStyles.body(size: 10.5, color: AppColors.inkSoft)),
          ],
        ),
      ),
    );
  }
}
