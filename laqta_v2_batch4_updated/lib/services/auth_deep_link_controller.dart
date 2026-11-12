import 'package:flutter/foundation.dart';

/// يتتبّع إذا كان التطبيق انفتح حاليًا بسبب رابط "استعادة كلمة المرور"
/// (Deep Link)، عشان main.dart يقدر يعرض شاشة "كلمة مرور جديدة" مباشرة
/// بدل شاشة الدخول العادية، بغض النظر عن حالة تسجيل الدخول الحالية.
class AuthDeepLinkController {
  AuthDeepLinkController._();

  static final ValueNotifier<bool> isPasswordRecovery = ValueNotifier<bool>(false);
}
