import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/mock_data.dart';
import '../models/models.dart';
import 'storage_service.dart';

class DbService {
  DbService._();
  static final DbService instance = DbService._();

  SupabaseClient get _db => Supabase.instance.client;

  /// حد أقصى لعدد الصفوف المجلوبة بكل بث، لتفادي تحميل قاعدة البيانات
  /// كاملة دفعة واحدة مع نمو عدد المنتجات/المحادثات.
  static const int _productsLimit = 50;
  static const int _conversationsLimit = 30;
  static const int _messagesLimit = 100;

  // ---------------- المفضلة ----------------

  Stream<List<String>> watchFavoriteIds(String uid) {
    return _db
        .from('favorites')
        .stream(primaryKey: ['uid', 'product_id'])
        .eq('uid', uid)
        .map((rows) => rows.map((r) => r['product_id'] as String).toList());
  }

  Future<void> addFavorite(String uid, String productId) {
    return _db.from('favorites').upsert({'uid': uid, 'product_id': productId});
  }

  Future<void> removeFavorite(String uid, String productId) {
    return _db.from('favorites').delete().eq('uid', uid).eq('product_id', productId);
  }

  // ---------------- المنتجات ----------------

  Stream<List<Product>> watchApprovedProducts() {
    return _db
        .from('products')
        .stream(primaryKey: ['id'])
        .eq('status', 'approved')
        .order('created_at', ascending: false)
        .limit(_productsLimit)
        .map((rows) => rows.map(_productFromRow).toList());
  }

  Stream<List<Product>> watchProductsBySeller(String sellerUid) {
    return _db
        .from('products')
        .stream(primaryKey: ['id'])
        .eq('seller_uid', sellerUid)
        .order('created_at', ascending: false)
        .limit(_productsLimit)
        .map((rows) => rows.map(_productFromRow).toList());
  }

  Stream<List<Product>> watchAllProducts() {
    return _db
        .from('products')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .limit(_productsLimit)
        .map((rows) => rows.map(_productFromRow).toList());
  }

  Future<String> addProduct({
    required String title,
    required double price,
    required String cat,
    required String cond,
    required String desc,
    required String sellerUid,
    required String sellerName,
    required String contactPhone,
    required String contactAddress,
    List<String> imageUrls = const [],
  }) async {
    final row = await _db
        .from('products')
        .insert({
          'title': title,
          'price': price,
          'cat': cat,
          'cond': cond,
          'desc': desc,
          'seller_uid': sellerUid,
          'seller_name': sellerName,
          'contact_phone': contactPhone,
          'contact_address': contactAddress,
          'rating': 0.0,
          'status': 'pending',
          'image_url': imageUrls.isNotEmpty ? imageUrls.first : null,
          'image_urls': imageUrls,
          'product_date': DateTime.now().toIso8601String(),
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  /// يحدّث بيانات منتج قائم بالكامل. يعيد المنتج لحالة "قيد المراجعة"
  /// تلقائيًا لأن أي تعديل على محتوى معتمد يحتاج مراجعة جديدة من الأدمن.
  /// يحذف من Storage أي صورة قديمة أزالها المستخدم أثناء التعديل (طالما
  /// ما في منتج آخر لسا يستخدم نفس الصورة).
  Future<void> updateProduct({
    required String productId,
    required String title,
    required double price,
    required String cat,
    required String cond,
    required String desc,
    required String contactPhone,
    required String contactAddress,
    List<String>? imageUrls,
  }) async {
    List<String> removedImages = const [];
    if (imageUrls != null) {
      final existing = await _db.from('products').select('image_urls').eq('id', productId).maybeSingle();
      final oldUrls = _imageUrlsFromRow(existing ?? const {});
      removedImages = oldUrls.where((u) => !imageUrls.contains(u)).toList();
    }

    final data = <String, dynamic>{
      'title': title,
      'price': price,
      'cat': cat,
      'cond': cond,
      'desc': desc,
      'contact_phone': contactPhone,
      'contact_address': contactAddress,
      'status': 'pending',
    };
    if (imageUrls != null) {
      data['image_url'] = imageUrls.isNotEmpty ? imageUrls.first : null;
      data['image_urls'] = imageUrls;
    }

    final result = await _db.from('products').update(data).eq('id', productId).select('id');
    if ((result as List).isEmpty) {
      throw Exception('تعذّر تنفيذ العملية، يرجى التحقق من صلاحيات الحساب');
    }

    if (removedImages.isNotEmpty) {
      await _deleteImagesIfUnused(removedImages, excludingProductId: productId);
    }
  }

  Future<void> updateProductStatus(String productId, String status) async {
    final result =
        await _db.from('products').update({'status': status}).eq('id', productId).select('id');
    if ((result as List).isEmpty) {
      throw Exception('تعذّر تنفيذ العملية، يرجى التحقق من صلاحيات الحساب');
    }
  }

  /// يحذف المنتج، ثم صوره من Storage (طالما ما في منتج آخر يستخدم نفس
  /// الصورة). حذف قاعدة البيانات هو الأهم وينفّذ أولًا؛ فشل حذف صورة من
  /// Storage بعده ما يرجع خطأ للمستخدم — المنتج يبقى محذوفًا فعليًا
  /// بأي الحالتين، وأسوأ نتيجة ممكنة هي ملف يتيم بالتخزين بدل فشل العملية.
  Future<void> deleteProduct(String productId) async {
    final existing = await _db.from('products').select('image_urls, image_url').eq('id', productId).maybeSingle();
    final images = _imageUrlsFromRow(existing ?? const {});

    final result = await _db.from('products').delete().eq('id', productId).select('id');
    if ((result as List).isEmpty) {
      throw Exception('تعذّر تنفيذ العملية، يرجى التحقق من صلاحيات الحساب');
    }

    if (images.isNotEmpty) {
      await _deleteImagesIfUnused(images, excludingProductId: productId);
    }
  }

  /// يحذف من Storage فقط الصور اللي ما عاد يستخدمها أي منتج آخر — حماية
  /// (مطلوبة صراحة) من حذف صورة لسا مرتبطة بمنتج تاني بالغلط.
  Future<void> _deleteImagesIfUnused(List<String> urls, {required String excludingProductId}) async {
    final toDelete = <String>[];
    for (final url in urls) {
      final stillUsed = await _db
          .from('products')
          .select('id')
          .neq('id', excludingProductId)
          .contains('image_urls', [url]).maybeSingle();
      if (stillUsed == null) toDelete.add(url);
    }
    if (toDelete.isNotEmpty) {
      await StorageService.instance.deleteProductImages(toDelete);
    }
  }

  /// يقرأ قائمة صور المنتج من عمود image_urls (الجديد)، ويرجع لعمود
  /// image_url القديم كاحتياط لو الصف قديم من قبل إضافة العمود الجديد.
  List<String> _imageUrlsFromRow(Map<String, dynamic> row) {
    final raw = row['image_urls'];
    if (raw is List && raw.isNotEmpty) {
      return raw.map((e) => e.toString()).toList();
    }
    final legacy = row['image_url'] as String?;
    if (legacy != null && legacy.isNotEmpty) return [legacy];
    return const [];
  }

  Product _productFromRow(Map<String, dynamic> row) {
    final id = row['id'] as String;
    final imageUrls = _imageUrlsFromRow(row);
    final createdAt =
        row['created_at'] == null ? null : DateTime.tryParse(row['created_at'] as String);
    return Product(
      // FIX: id الآن String مباشرة (uuid) بدل hashCode
      id: id,
      title: row['title'] ?? '',
      price: (row['price'] ?? 0).toDouble(),
      cat: row['cat'] ?? '',
      cond: row['cond'] ?? '',
      desc: row['desc'] ?? '',
      seller: row['seller_name'] ?? '',
      rating: (row['rating'] ?? 0).toDouble(),
      status: _statusFromString(row['status']),
      emoji: imageUrls.isEmpty ? (kThumbEmoji[row['cat']] ?? '📦') : '',
      imageUrls: imageUrls,
      date: _relativeDate(createdAt),
      sellerUid: row['seller_uid'] as String?,
      contactPhone: row['contact_phone'] as String?,
      contactAddress: row['contact_address'] as String?,
    );
  }

  String _relativeDate(DateTime? createdAt) {
    if (createdAt == null) return '';
    final diff = DateTime.now().difference(createdAt);
    if (diff.inHours < 24) return 'اليوم';
    if (diff.inDays == 1) return 'أمس';
    if (diff.inDays < 7) return 'قبل ${diff.inDays} أيام';
    final d = createdAt;
    return '${d.day}/${d.month}/${d.year}';
  }

  ProductStatus _statusFromString(String? s) {
    switch (s) {
      case 'approved':
        return ProductStatus.approved;
      case 'rejected':
        return ProductStatus.rejected;
      default:
        return ProductStatus.pending;
    }
  }

  // ---------------- المحادثات والرسائل ----------------

  /// يمنع إنشاء محادثتين مكررتين لنفس المنتج ونفس الطرفين لو ضغط
  /// المستخدم على "تواصل" أكثر من مرة بسرعة قبل انتهاء الطلب الأول.
  final Set<String> _creatingConversationFor = {};

  Future<String> getOrCreateConversation({
    required String productId,
    required String productTitle,
    required String buyerUid,
    required String buyerName,
    required String sellerUid,
    required String sellerName,
  }) async {
    final key = '$productId:$buyerUid:$sellerUid';

    Future<String?> findExisting() async {
      final existing = await _db
          .from('conversations')
          .select('id, participants')
          .eq('product_id', productId)
          .contains('participants', [buyerUid]);
      for (final row in (existing as List)) {
        if ((row['participants'] as List).contains(sellerUid)) return row['id'] as String;
      }
      return null;
    }

    final already = await findExisting();
    if (already != null) return already;

    // لو في طلب إنشاء جارٍ فعلًا لنفس المحادثة، ننتظر نتيجته بدل ما ننشئ وحدة جديدة.
    if (_creatingConversationFor.contains(key)) {
      while (_creatingConversationFor.contains(key)) {
        await Future.delayed(const Duration(milliseconds: 150));
      }
      return (await findExisting()) ?? '';
    }

    _creatingConversationFor.add(key);
    try {
      final row = await _db
          .from('conversations')
          .insert({
            'product_id': productId,
            'product_title': productTitle,
            'participants': [buyerUid, sellerUid],
            'names': {buyerUid: buyerName, sellerUid: sellerName},
          })
          .select('id')
          .single();
      return row['id'] as String;
    } finally {
      _creatingConversationFor.remove(key);
    }
  }

  Stream<List<Map<String, dynamic>>> watchConversations(String uid) {
    return _db
        .from('conversations')
        .stream(primaryKey: ['id'])
        .order('last_message_at', ascending: false)
        .limit(_conversationsLimit)
        .map((rows) => rows.where((r) => (r['participants'] as List).contains(uid)).toList());
  }

  Stream<List<Map<String, dynamic>>> watchMessages(String conversationId) {
    return _db
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('sent_at', ascending: true)
        .limit(_messagesLimit)
        .map((rows) => rows);
  }

  Future<void> sendMessage({
    required String conversationId,
    required String senderUid,
    required String text,
  }) async {
    await _db.from('messages').insert({
      'conversation_id': conversationId,
      'sender_uid': senderUid,
      'text': text,
    });
    await _db.from('conversations').update({
      'last_message': text,
      'last_message_at': DateTime.now().toIso8601String(),
    }).eq('id', conversationId);
  }
}
