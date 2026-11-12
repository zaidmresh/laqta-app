import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/db_service.dart';

/// أسماء الشاشات (Views)
enum AppView {
  home,
  search,
  favorites,
  messages,
  chat,
  profile,
  detail,
  addProduct,
  myListings,
  notifications,
  admin,
  editProfile,
}

// FIX (تقرير الأداء - تحسين مهم): حد أقصى لحجم الـ history لتفادي نموّه
// بلا حدود مع تنقّل المستخدم الكثير بين الشاشات.
const int _maxHistory = 20;

class AppState extends ChangeNotifier {
  AppState() {
    _listenLiveProducts();
    _listenUserContext();
  }

  // ---------------- بيانات حيّة من قاعدة البيانات ----------------
  List<Product> products = [];
  List<Product> myProducts = [];
  List<Product> adminProducts = [];
  bool adminProductsLoaded = false;
  bool isAdmin = false;
  Set<String> favoriteProductIds = {};

  StreamSubscription<List<Product>>? _liveProductsSub;
  StreamSubscription<User?>? _authSub;
  StreamSubscription<List<Product>>? _myProductsSub;
  StreamSubscription<List<Product>>? _adminProductsSub;
  StreamSubscription<List<String>>? _favoritesSub;

  // FIX (تقرير الأداء - مشكلة حرجة): دمج أي notifyListeners() ناتجة عن
  // وصول عدة streams بنفس اللحظة (مثلاً products وfavorites سويًا) في
  // إعادة بناء واحدة بدل عدة rebuilds متتالية.
  bool _pendingNotify = false;
  void _scheduleNotify() {
    if (_pendingNotify) return;
    _pendingNotify = true;
    Future.microtask(() {
      _pendingNotify = false;
      notifyListeners();
    });
  }

  void _listenLiveProducts() {
    _liveProductsSub = DbService.instance.watchApprovedProducts().listen(
      (live) {
        products = live;
        _scheduleNotify();
      },
      onError: (_) {},
    );
  }

  /// يربط منتجات المستخدم وصلاحية الإدارة بحساب المستخدم المسجّل دخول
  /// حاليًا، ويحدّثهم تلقائيًا عند تغيّر حالة الدخول.
  void _listenUserContext() {
    _authSub = Supabase.instance.client.auth.onAuthStateChange
        .map((state) => state.session?.user)
        .listen((user) async {
      _myProductsSub?.cancel();
      _adminProductsSub?.cancel();
      _favoritesSub?.cancel();

      if (user == null) {
        myProducts = [];
        adminProducts = [];
        adminProductsLoaded = false;
        isAdmin = false;
        favoriteProductIds = {};
        notifyListeners();
        return;
      }

      _myProductsSub = DbService.instance.watchProductsBySeller(user.id).listen(
        (mine) {
          myProducts = mine;
          _scheduleNotify();
        },
        onError: (_) {},
      );

      _favoritesSub = DbService.instance.watchFavoriteIds(user.id).listen(
        (ids) {
          favoriteProductIds = ids.toSet();
          _scheduleNotify();
        },
        onError: (_) {},
      );

      final profile = await AuthService.instance.fetchUserProfile(user.id);
      isAdmin = profile != null && profile['is_admin'] == true;
      // يحتاج الأدمن رؤية كل المنتجات (بما فيها قيد المراجعة من بائعين
      // آخرين) عشان يقدر يفتح تفاصيل أي منتج ويتصفّح صوره ووصفه كاملًا
      // قبل اعتماده أو رفضه.
      if (isAdmin) {
        adminProductsLoaded = false;
        _adminProductsSub = DbService.instance.watchAllProducts().listen(
          (all) {
            adminProducts = all;
            adminProductsLoaded = true;
            _scheduleNotify();
          },
          onError: (_) {
            adminProductsLoaded = true; // نوقف مؤشر التحميل حتى لو صار خطأ، بدل ما يعلّق للأبد
            _scheduleNotify();
          },
        );
      } else {
        adminProducts = [];
        adminProductsLoaded = false;
      }
      _scheduleNotify();
    });
  }

  @override
  void dispose() {
    _liveProductsSub?.cancel();
    _authSub?.cancel();
    _myProductsSub?.cancel();
    _adminProductsSub?.cancel();
    _favoritesSub?.cancel();
    super.dispose();
  }

  void openEditProfile() => go(AppView.editProfile);

  // ---------------- حالة الواجهة ----------------
  AppView view = AppView.home;
  UserRole role = UserRole.buyer;
  String? cat;
  String search = '';
  // FIX: id الآن String بدل int (يطابق تعديل Product.id)
  String? selectedProductId;
  String? activeConversationId;
  String activeConversationTitle = '';
  String activeConversationProductTitle = '';
  String addFormCat = 'clothing';
  String addFormCond = 'مستعمل - حالة جيدة';
  Product? editingProduct;
  final List<AppView> history = [AppView.home];

  // ---------------- تنقل بين الشاشات ----------------
  void go(AppView v, {bool push = true}) {
    if (push) {
      history.add(v);
      // FIX (تقرير الأداء - تحسين مهم): حد أقصى لحجم الـ history
      if (history.length > _maxHistory) {
        history.removeAt(0);
      }
    }
    view = v;
    notifyListeners();
  }

  void back() {
    if (history.isNotEmpty) history.removeLast();
    view = history.isNotEmpty ? history.last : AppView.home;
    notifyListeners();
  }

  // ---------------- مساعدات ----------------
  Product? get selectedProduct =>
      selectedProductId == null ? null : productById(selectedProductId!);

  /// أول 6 منتجات معتمدة تُعرض بالصفحة الرئيسية. products أصلًا معتمدة
  /// فقط (الفلترة تصير من السيرفر بـ watchApprovedProducts)، فهون بس
  /// نقتطع أول 6 — بدون أي فلترة إضافية مكرّرة.
  List<Product> get featuredProducts => products.take(6).toList();

  /// يبحث بين المنتجات المعتمدة (المعروضة للعموم) ومنتجات المستخدم
  /// الحالي الخاصة (بأي حالة اعتماد)، وكل المنتجات اللي يشوفها الأدمن
  /// (عشان يقدر يفتح تفاصيل منتج أي بائع وهو قيد المراجعة).
  Product? productById(String id) {
    for (final p in products) {
      if (p.id == id) return p;
    }
    for (final p in myProducts) {
      if (p.id == id) return p;
    }
    for (final p in adminProducts) {
      if (p.id == id) return p;
    }
    return null;
  }

  // ---------------- إجراءات ----------------
  bool isFavorite(Product p) => favoriteProductIds.contains(p.id);

  Future<void> toggleFavorite(Product p) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    if (isFavorite(p)) {
      await DbService.instance.removeFavorite(uid, p.id);
    } else {
      await DbService.instance.addFavorite(uid, p.id);
    }
  }

  void setCategory(String? id) {
    cat = id;
    notifyListeners();
  }

  void setSearch(String text) {
    search = text;
    notifyListeners();
  }

  /// يبدّل بين عرض التطبيق كمشترٍ أو بائع (تفضيل عرض فقط، لا علاقة له
  /// بصلاحيات الإدارة — تلك تُشتق حصرًا من [isAdmin]).
  void setRole(UserRole r) {
    if (r == UserRole.admin) return;
    role = r;
    view = AppView.profile;
    history
      ..clear()
      ..addAll([AppView.home, AppView.profile]);
    notifyListeners();
  }

  void openProduct(String id) {
    selectedProductId = id;
    go(AppView.detail);
  }

  void openConversation({
    required String id,
    required String withName,
    required String productTitle,
  }) {
    activeConversationId = id;
    activeConversationTitle = withName;
    activeConversationProductTitle = productTitle;
    go(AppView.chat);
  }

  bool _contactingSeller = false;

  /// يفتح محادثة موجودة مع البائع بخصوص منتج معيّن أو ينشئ واحدة جديدة.
  /// محمي من الضغط المتكرر السريع (double-tap) بعلم داخلي.
  Future<void> contactSeller(Product p) async {
    if (_contactingSeller) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || p.sellerUid == null) return;
    _contactingSeller = true;
    try {
      final buyerName = AuthService.instance.displayName ?? user.email ?? 'مستخدم';
      final id = await DbService.instance.getOrCreateConversation(
        productId: p.id,
        productTitle: p.title,
        buyerUid: user.id,
        buyerName: buyerName,
        sellerUid: p.sellerUid!,
        sellerName: p.seller,
      );
      openConversation(id: id, withName: p.seller, productTitle: p.title);
    } finally {
      _contactingSeller = false;
    }
  }

  void setAddFormCategory(String id) {
    addFormCat = id;
    notifyListeners();
  }

  void setAddFormCondition(String cond) {
    addFormCond = cond;
    notifyListeners();
  }

  /// يفتح نموذج إضافة منتج بوضع "إضافة جديد" (يمسح أي تعديل سابق كان جاريًا).
  void openAddProduct() {
    editingProduct = null;
    go(AppView.addProduct);
  }

  /// يفتح نفس النموذج بوضع "تعديل" على منتج قائم.
  void startEditProduct(Product p) {
    editingProduct = p;
    go(AppView.addProduct);
  }
}
