/// يتحقق من رقم هاتف أردني بصيغة محلية (07XXXXXXXX) أو دولية
/// (+9627XXXXXXXX). يُستخدم بنموذج التسجيل وشاشة توثيق الهاتف معًا.
class PhoneValidator {
  PhoneValidator._();

  static const String errorMessage = 'رقم الهاتف غير صحيح — يجب أن يبدأ بـ 07 ويتكوّن من 10 أرقام (مثال: 0791234567)';

  /// يرجع null إذا كان الرقم مقبولاً، أو رسالة خطأ واضحة إذا لم يكن كذلك.
  static String? validate(String input) {
    final digits = input.trim();
    // نقبل الصيغة المحلية 07XXXXXXXX أو الدولية +9627XXXXXXXX / 009627XXXXXXXX
    final local = RegExp(r'^07[789]\d{7}$');
    final international = RegExp(r'^(\+962|00962)7[789]\d{7}$');
    if (local.hasMatch(digits) || international.hasMatch(digits)) return null;
    return errorMessage;
  }
}
