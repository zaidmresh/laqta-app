/// يتحقق من قوة كلمة المرور: 8 أحرف على الأقل، حرف كبير، حرف صغير، رقم،
/// ورمز خاص واحد على الأقل. يُستخدم بشاشة التسجيل وشاشة إعادة تعيين
/// كلمة المرور معًا لضمان نفس السياسة بكل مكان.
class PasswordValidator {
  PasswordValidator._();

    static const String requirementsMessage =
      'كلمة المرور يجب أن تكون 8 أحرف على الأقل، وتحتوي على 3 على الأقل من: حرف كبير، حرف صغير، رقم، رمز خاص.';

  static String? validate(String password) {
    if (password.length < 8) return requirementsMessage;
    var categories = 0;
    if (RegExp(r'[A-Z]').hasMatch(password)) categories++;
    if (RegExp(r'[a-z]').hasMatch(password)) categories++;
    if (RegExp(r'[0-9]').hasMatch(password)) categories++;
    if (RegExp(r'[!@#\$%\^&\*()_\-+=\[\]{}|:;"<>,.?/~`]').hasMatch(password)) categories++;
    if (categories < 3) return requirementsMessage;
    return null;
  }

  /// تقدير بسيط لقوة كلمة المرور لعرض مؤشر بصري (ضعيفة/متوسطة/قوية).
  static PasswordStrength strength(String password) {
    if (password.isEmpty) return PasswordStrength.none;
    var score = 0;
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[a-z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[!@#\$%\^&\*()_\-+=\[\]{}|:;"<>,.?/~`]').hasMatch(password)) score++;

    if (score <= 2) return PasswordStrength.weak;
    if (score <= 4) return PasswordStrength.medium;
    return PasswordStrength.strong;
  }
}

enum PasswordStrength { none, weak, medium, strong }
