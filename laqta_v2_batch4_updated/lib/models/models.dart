class Category {
  final String id;
  final String name;
  final String icon;
  const Category({required this.id, required this.name, required this.icon});
}

class Review {
  final String name;
  final int stars;
  final String text;
  const Review({required this.name, required this.stars, required this.text});
}

enum ProductStatus { approved, pending, rejected }

class Product {
  /// معرّف المنتج الحقيقي بقاعدة البيانات (UUID كنص مباشرة، بدل hashCode
  /// اللي كان فيه احتمال تصادم بين منتجين مختلفين).
  final String id;
  String title;
  double price;
  String cat;
  String cond;
  String desc;
  final String seller;
  final double rating;
  ProductStatus status;
  final String emoji;
  final String date;
  final List<Review> reviews;

  /// كل صور المنتج (يقدر البائع يرفع أكثر من صورة). الصورة الأولى بالقائمة
  /// هي الصورة الرئيسية المستخدمة كمصغّرة (thumbnail) في البطاقات.
  final List<String> imageUrls;

  /// معرّف المستخدم المالك للمنتج (Supabase Auth).
  final String? sellerUid;

  /// رقم هاتف التواصل الخاص بهذا المنتج تحديدًا (يدخله البائع عند النشر).
  final String? contactPhone;

  /// عنوان البائع الخاص بهذا المنتج تحديدًا (يدخله البائع إلزاميًا عند النشر).
  final String? contactAddress;

  /// اسم بديل لنفس id، محفوظ للتوافق مع أي كود قديم يستخدم firestoreId.
  String? get firestoreId => id;

  Product({
    required this.id,
    required this.title,
    required this.price,
    required this.cat,
    required this.cond,
    required this.desc,
    required this.seller,
    required this.rating,
    required this.status,
    required this.emoji,
    required this.date,
    this.reviews = const [],
    this.imageUrls = const [],
    this.sellerUid,
    this.contactPhone,
    this.contactAddress,
  });

  /// الصورة الرئيسية (أول صورة)، للتوافق مع أي مكان لسا بيستخدم صورة وحدة
  /// فقط (مثل مصغّرات البطاقات).
  String? get imageUrl => imageUrls.isNotEmpty ? imageUrls.first : null;
}

enum UserRole { buyer, seller, admin }
