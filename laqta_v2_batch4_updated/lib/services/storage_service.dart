import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

/// خدمة رفع صور المنتجات إلى Supabase Storage.
/// لازم تنشئ bucket اسمه "product-images" وتخليه Public — الخطوات
/// موجودة بـ SUPABASE_SETUP.md.
class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  static const String _bucket = 'product-images';

  SupabaseStorageClient get _storage => Supabase.instance.client.storage;

  /// يرفع صورة منتج (كبايتات) ويرجع رابط عام (public URL).
  Future<String> uploadProductImage({
    required Uint8List bytes,
    required String sellerUid,
    int? uniqueSuffix,
  }) async {
    final millis = DateTime.now().millisecondsSinceEpoch;
    final fileName = uniqueSuffix == null ? '$millis.jpg' : '${millis}_$uniqueSuffix.jpg';
    final path = '$sellerUid/$fileName';

    await _storage
        .from(_bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        )
        .timeout(
      const Duration(seconds: 25),
      onTimeout: () => throw Exception(
        'انتهت مهلة رفع الصورة. غالبًا الـ bucket "product-images" مش '
        'موجود أو مش Public على مشروعك — راجع SUPABASE_SETUP.md.',
      ),
    );

    return _storage.from(_bucket).getPublicUrl(path);
  }

  /// يرفع عدة صور منتج دفعة واحدة (بالترتيب) ويرجع روابطها العامة بنفس
  /// الترتيب. كل صورة تاخذ اسم ملف فريد حتى لو انرفعت بنفس اللحظة تقريبًا.
  Future<List<String>> uploadProductImages({
    required List<Uint8List> images,
    required String sellerUid,
  }) async {
    final urls = <String>[];
    for (var i = 0; i < images.length; i++) {
      final url = await uploadProductImage(
        bytes: images[i],
        sellerUid: sellerUid,
        uniqueSuffix: i,
      );
      urls.add(url);
    }
    return urls;
  }

  /// يحذف صورة واحدة من Storage اعتمادًا على رابطها العام الكامل.
  /// يتجاهل الحذف بصمت لو الرابط ما يتبع نفس الـ bucket (حماية إضافية
  /// عشان ما نحذف شي بالغلط لو انمرر رابط خارجي أو غير متوقع).
  Future<void> deleteProductImage(String publicUrl) async {
    final path = _extractStoragePath(publicUrl);
    if (path == null) return;
    try {
      await _storage.from(_bucket).remove([path]);
    } catch (_) {
      // فشل حذف صورة وحدة ما لازم يوقف بقية العملية (حذف المنتج مثلاً) —
      // أسوأ سيناريو: ملف يتيم يضل بالتخزين، وهذا أهون من فشل كامل للعملية.
    }
  }

  /// يحذف عدة صور دفعة وحدة (أسرع من استدعاء الحذف مرة لكل صورة).
  Future<void> deleteProductImages(List<String> publicUrls) async {
    final paths = publicUrls.map(_extractStoragePath).whereType<String>().toList();
    if (paths.isEmpty) return;
    try {
      await _storage.from(_bucket).remove(paths);
    } catch (_) {
      // نفس المنطق: فشل الحذف من التخزين ما لازم يفشّل عملية حذف/تعديل
      // المنتج نفسها بقاعدة البيانات.
    }
  }

  /// يستخرج المسار الداخلي بالـ bucket (مثال: uid/12345.jpg) من رابط عام
  /// كامل. يرجع null لو الرابط ما يطابق شكل روابط الـ bucket المتوقع.
  String? _extractStoragePath(String publicUrl) {
    final marker = '/object/public/$_bucket/';
    final index = publicUrl.indexOf(marker);
    if (index == -1) return null;
    return publicUrl.substring(index + marker.length);
  }
}
