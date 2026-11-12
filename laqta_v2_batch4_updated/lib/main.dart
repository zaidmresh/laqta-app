import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';
import 'services/auth_deep_link_controller.dart';
import 'screens/admin_screen.dart';
import 'screens/add_product_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/detail_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/favorites_screen.dart';
import 'screens/home_screen.dart';
import 'screens/messages_screen.dart';
import 'screens/my_listings_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/search_screen.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Supabase هو مصدر الحقيقة الوحيد للتوثيق (Auth) وقاعدة البيانات والتخزين.
  // حط بيانات مشروعك بـ lib/supabase_config.dart.
  await Supabase.initialize(url: kSupabaseUrl, publishableKey: kSupabasePublishableKey);

  // يرصد لحظة فتح المستخدم لرابط "استعادة كلمة المرور" (Deep Link) —
  // Supabase بيتعرّف على الرابط تلقائيًا (لازم يكون مسجّل بـ
  // AndroidManifest.xml) وبيطلق هذا الحدث فور فتح التطبيق منه.
  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    if (data.event == AuthChangeEvent.passwordRecovery) {
      AuthDeepLinkController.isPasswordRecovery.value = true;
    }
  });

  runApp(const LaqtaApp());
}

class LaqtaApp extends StatelessWidget {
  const LaqtaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        title: 'لَقطة — LAQTA',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        ),
        home: const AuthGate(),
      ),
    );
  }
}

/// بوابة الدخول: تعرض شاشة تسجيل الدخول إذا ما في مستخدم، أو التطبيق
/// نفسه (RootShell) إذا كان مسجّل دخول فعلاً — وتتحدث تلقائيًا بأي تغيير.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AuthDeepLinkController.isPasswordRecovery,
      builder: (context, isRecovery, _) {
        // بغض النظر عن حالة تسجيل الدخول العادية، لو المستخدم جاي من رابط
        // استعادة كلمة المرور، نعرض شاشة "كلمة مرور جديدة" فورًا.
        if (isRecovery) return const ResetPasswordScreen();

        return StreamBuilder<User?>(
          stream: Supabase.instance.client.auth.onAuthStateChange
              .map((state) => state.session?.user),
          initialData: Supabase.instance.client.auth.currentUser,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                backgroundColor: Color(0xFFF1EAD9),
                body: Center(child: CircularProgressIndicator()),
              );
            }
            final user = snapshot.data;
            if (user == null) {
              return const AuthScreen();
            }
            return const RootShell();
          },
        );
      },
    );
  }
}

/// الإطار الرئيسي للتطبيق: يحتوي الشريط العلوي، المحتوى المتغيّر، الشريط
/// السفلي وزر الإضافة العائم — مطابق لبنية device/topbar/content/navbar
/// في النسخة الأصلية بلغة HTML.
class RootShell extends StatelessWidget {
  const RootShell({super.key});

  static const _viewsWithoutTopbar = {
    AppView.detail,
    AppView.chat,
    AppView.addProduct,
    AppView.myListings,
    AppView.notifications,
    AppView.admin,
    AppView.editProfile,
  };

  static const _viewsWithoutNav = {
    AppView.detail,
    AppView.addProduct,
    AppView.editProfile,
  };

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final showTopbar = !_viewsWithoutTopbar.contains(appState.view);
        final showNav = !_viewsWithoutNav.contains(appState.view);
        // أي حساب مسجّل دخول يقدر يبيع (لا يوجد تمييز مشتري/بائع بعد الآن).
        final showFab = appState.view == AppView.home || appState.view == AppView.myListings;

        return PopScope(
          canPop: appState.history.length <= 1,
          onPopInvoked: (didPop) {
            if (!didPop && appState.history.length > 1) {
              appState.back();
            }
          },
          child: Scaffold(
            backgroundColor: const Color(0xFFF1EAD9),
            appBar: showTopbar ? _TopBar(appState: appState) : null,
            body: SafeArea(child: _buildBody(appState)),
            bottomNavigationBar: showNav ? _BottomNav(appState: appState) : null,
            floatingActionButton: showFab
                ? FloatingActionButton(
                    onPressed: () => appState.openAddProduct(),
                    backgroundColor: AppColors.brass,
                    foregroundColor: AppColors.tealDark,
                    child: const Icon(Icons.add, size: 26),
                  )
                : null,
          ),
        );
      },
    );
  }

  /// التبويبات الخمسة الرئيسية بالشريط السفلي — تُبنى مرة واحدة فقط وتبقى
  /// محفوظة بالذاكرة (بما فيها اتصالاتها اللحظية بقاعدة البيانات)، والتنقل
  /// بينها مجرد تبديل عرض فوري بدل إعادة بناء وإعادة اتصال من الصفر في كل مرة.
  static const _tabViews = [
    AppView.home,
    AppView.search,
    AppView.favorites,
    AppView.messages,
    AppView.profile,
  ];

  Widget _buildBody(AppState appState) {
    final tabIndex = _tabViews.indexOf(appState.view);
    if (tabIndex != -1) {
      // FIX (تقرير الأداء - مشكلة حرجة): بدل بناء الخمس شاشات دفعة واحدة
      // عند أول تشغيل، هاد الـwidget يبنيها بشكل كسول (lazy) — كل شاشة
      // تُبنى فقط أول مرة يزورها المستخدم، وتبقى محفوظة بالذاكرة بعدها.
      return _LazyTabsView(appState: appState, index: tabIndex);
    }

    switch (appState.view) {
      case AppView.chat:
        return ChatScreen(appState: appState);
      case AppView.detail:
        return DetailScreen(appState: appState);
      case AppView.addProduct:
        return AddProductScreen(appState: appState);
      case AppView.myListings:
        return MyListingsScreen(appState: appState);
      case AppView.notifications:
        return NotificationsScreen(appState: appState);
      case AppView.admin:
        return AdminScreen(appState: appState);
      case AppView.editProfile:
        return EditProfileScreen(appState: appState);
      default:
        return HomeScreen(appState: appState);
    }
  }
}

/// FIX (تقرير الأداء - مشكلة حرجة): بناء كسول للتبويبات الخمسة. يحتفظ
/// بمجموعة التبويبات اللي زارها المستخدم فعليًا؛ أي تبويب لسا ما انزار
/// يُستبدل بـwidget فارغ رخيص بدل بناء شاشته الكاملة (وبالتالي الاتصال
/// بقاعدة البيانات جواها) من أول تشغيل للتطبيق.
class _LazyTabsView extends StatefulWidget {
  final AppState appState;
  final int index;
  const _LazyTabsView({required this.appState, required this.index});

  @override
  State<_LazyTabsView> createState() => _LazyTabsViewState();
}

class _LazyTabsViewState extends State<_LazyTabsView> {
  final Set<int> _visited = {};

  @override
  Widget build(BuildContext context) {
    _visited.add(widget.index);
    final appState = widget.appState;
    final tabs = <Widget>[
      HomeScreen(appState: appState),
      SearchScreen(appState: appState),
      FavoritesScreen(appState: appState),
      MessagesScreen(appState: appState),
      ProfileScreen(appState: appState),
    ];
    return IndexedStack(
      index: widget.index,
      children: List.generate(
        tabs.length,
        (i) => _visited.contains(i) ? tabs[i] : const SizedBox.shrink(),
      ),
    );
  }
}

/// الشريط العلوي (شعار لَقطة + أيقونات الإشعارات والملف الشخصي)
class _TopBar extends StatelessWidget implements PreferredSizeWidget {
  final AppState appState;
  const _TopBar({required this.appState});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.paper,
      elevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 18,
      title: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => appState.go(AppView.home),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                gradient: const LinearGradient(
                  colors: [AppColors.teal, AppColors.tealDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              alignment: Alignment.center,
              child: Text('ل', style: AppTextStyles.heading(size: 19, color: AppColors.brass)),
            ),
            const SizedBox(width: 9),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('لَقطة', style: AppTextStyles.heading(size: 21)),
                Text('سوق الجمعة الرقمي',
                    style: AppTextStyles.body(size: 10.5, color: AppColors.inkSoft)),
              ],
            ),
          ],
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: _iconButton(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_none, size: 19, color: AppColors.tealDark),
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(color: AppColors.rust, shape: BoxShape.circle),
                  ),
                ),
              ],
            ),
            onTap: () => appState.go(AppView.notifications),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 18),
          child: _iconButton(
            child: const Icon(Icons.person_outline, size: 19, color: AppColors.tealDark),
            onTap: () => appState.go(AppView.profile),
          ),
        ),
      ],
    );
  }

  Widget _iconButton({required Widget child, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.card,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.sandLine),
        ),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}

/// الشريط السفلي للتنقل بين الأقسام الرئيسية
class _BottomNav extends StatelessWidget {
  final AppState appState;
  const _BottomNav({required this.appState});

  static const _items = [
    (AppView.home, Icons.home_outlined, 'الرئيسية'),
    (AppView.search, Icons.search, 'البحث'),
    (AppView.favorites, Icons.favorite_border, 'المفضلة'),
    (AppView.messages, Icons.chat_bubble_outline, 'الرسائل'),
    (AppView.profile, Icons.person_outline, 'حسابي'),
  ];

  AppView _currentTab() {
    switch (appState.view) {
      case AppView.chat:
        return AppView.messages;
      case AppView.myListings:
      case AppView.notifications:
      case AppView.admin:
        return AppView.profile;
      default:
        return appState.view;
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = _currentTab();
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.sandLine)),
      ),
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
      child: SafeArea(
        top: false,
        child: Row(
          children: _items.map((item) {
            final active = current == item.$1;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  appState.go(item.$1);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(item.$2, size: 20, color: active ? AppColors.tealDark : AppColors.inkSoft),
                    const SizedBox(height: 3),
                    Text(
                      item.$3,
                      style: AppTextStyles.body(
                        size: 10.5,
                        color: active ? AppColors.tealDark : AppColors.inkSoft,
                        weight: active ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
