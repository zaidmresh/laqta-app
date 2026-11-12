import 'package:flutter/material.dart';
import '../models/models.dart';

final List<Category> kCategories = [
  const Category(id: 'clothing', name: 'ملابس عتيقة', icon: '👘'),
  const Category(id: 'antiques', name: 'تحف وأثاث', icon: '🏺'),
  const Category(id: 'collect', name: 'مقتنيات', icon: '🧿'),
  const Category(id: 'coins', name: 'عملات نادرة', icon: '🪙'),
  const Category(id: 'access', name: 'إكسسوارات', icon: '📿'),
];

final Map<String, Category> kCatMap = {
  for (final c in kCategories) c.id: c,
};

/// لون خلفية مصغّرة لكل فئة
final Map<String, Color> kThumbColors = {
  'clothing': const Color(0xFFE7D9BE),
  'antiques': const Color(0xFFDCEAE6),
  'collect': const Color(0xFFF0E2CB),
  'coins': const Color(0xFFEADFC2),
  'access': const Color(0xFFE4D9EC),
};

/// خيارات حالة القطعة المعروضة في نموذج إضافة منتج
const List<String> kConditions = [
  'جديد - في غلاف أصلي',
  'مستعمل - حالة ممتازة',
  'مستعمل - حالة جيدة جداً',
  'مستعمل - حالة جيدة',
  'مستعمل - حالة متوسطة',
];

/// إيموجي مصغّر افتراضي حسب الفئة (يُستخدم عند غياب صورة حقيقية للمنتج)
const Map<String, String> kThumbEmoji = {
  'clothing': '👘',
  'antiques': '🏺',
  'collect': '🧿',
  'coins': '🪙',
  'access': '📿',
};
