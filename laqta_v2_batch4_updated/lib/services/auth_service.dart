import 'package:supabase_flutter/supabase_flutter.dart';

/// خدمة تسجيل الدخول / إنشاء الحساب عبر Supabase Auth.
/// كل مستخدم جديد يُنشأ له صف مقابل بجدول `profiles` تلقائيًا (عن طريق
/// trigger بقاعدة البيانات، راجع supabase/schema.sql)، يحمل الاسم والدور
/// (buyer/seller)، بالإضافة لحالة توثيق الهاتف.
///
/// ملاحظات مهمة قبل الاستخدام (راجع SUPABASE_SETUP.md):
/// - التحقق من رقم الهاتف (OTP) يحتاج مزوّد SMS مفعّل بـ Supabase:
///   Dashboard → Authentication → Providers → Phone.
/// - المصادقة الثنائية (2FA) بـ Supabase مبنية على factors (TOTP أو Phone)
///   عن طريق `auth.mfa` — لا تحتاج أي تفعيل إضافي غير مزوّد SMS نفسه.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  GoTrueClient get _auth => Supabase.instance.client.auth;
  SupabaseClient get _db => Supabase.instance.client;

  /// بث حالة الدخول (بديل authStateChanges بفايربيس).
  Stream<User?> get authStateChanges =>
      _auth.onAuthStateChange.map((state) => state.session?.user);
  User? get currentUser => _auth.currentUser;

  // ---------------- إنشاء حساب / دخول ----------------

  /// إنشاء حساب جديد بالبريد وكلمة المرور. الاسم والدور بينحفظوا تلقائيًا
  /// بجدول profiles عن طريق trigger بقاعدة البيانات (راجع schema.sql).
  /// Supabase بيرسل إيميل تحقق تلقائيًا حسب إعدادات المشروع.
  Future<User?> signUp({
    required String name,
    required String email,
    required String password,
    required String role, // 'buyer' or 'seller'
    String? phone,
    String? location,
    String? emailRedirectTo,
  }) async {
    final res = await _auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'name': name,
        'role': role,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (location != null && location.isNotEmpty) 'location': location,
      },
      emailRedirectTo: emailRedirectTo,
    );
    return res.user;
  }

  /// دخول بالبريد وكلمة المرور. إذا كان الحساب مفعّل فيه 2FA (aal2 required)،
  /// الجلسة بترجع بمستوى aal1 بس — على الواجهة تتحقق بـ [needsMfaChallenge]
  /// وتكمّل التحدي عن طريق [primaryMfaFactor] + [sendMfaChallenge] +
  /// [confirmMfaChallenge].
  Future<User?> signIn({required String email, required String password}) async {
    final res = await _auth.signInWithPassword(email: email.trim(), password: password);
    return res.user;
  }

  Future<void> signOut() => _auth.signOut();

  /// [redirectTo] لازم يكون رابط صفحة إعادة تعيين كلمة المرور المستضافة
  /// (راجع web_pages/reset-password.html) — بدونه، الرابط بالإيميل ما رح
  /// يوديك لمكان تقدر تكتب فيه كلمة مرور جديدة فعليًا.
  Future<void> resetPassword(String email, {String? redirectTo}) =>
      _auth.resetPasswordForEmail(email.trim(), redirectTo: redirectTo);

  /// يجيب بيانات المستخدم (الاسم/الدور/الهاتف) من جدول profiles.
  Future<Map<String, dynamic>?> fetchUserProfile(String uid) async {
    return _db.from('profiles').select().eq('id', uid).maybeSingle();
  }

  // ---------------- الملف الشخصي ----------------

  Future<void> updateProfile({required String name}) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _auth.updateUser(UserAttributes(data: {'name': name}));
    await _db.from('profiles').update({'name': name}).eq('id', user.id);
  }

  /// اسم العرض — Supabase ما عنده displayName جاهز متل فايربيس، فبنخزّنه
  /// بـ user_metadata وقت signUp/updateProfile ونرجّعه من هون.
  String? get displayName {
    final meta = _auth.currentUser?.userMetadata;
    return meta == null ? null : meta['name'] as String?;
  }

  // ---------------- التحقق من الإيميل ----------------

  /// Supabase بيأكد الإيميل تلقائيًا عن طريق الرابط اللي بيوصل — بمجرد ما
  /// email_confirmed_at يصير معبّى، بصير emailVerified true.
  bool get isEmailVerified => _auth.currentUser?.emailConfirmedAt != null;

  /// يعيد إرسال إيميل التحقق (Supabase resend API).
  Future<void> sendEmailVerification({String? emailRedirectTo}) async {
    final email = _auth.currentUser?.email;
    if (email == null) return;
    await _auth.resend(type: OtpType.signup, email: email, emailRedirectTo: emailRedirectTo);
  }

  /// يعيد تحميل بيانات المستخدم من الخادم.
  Future<void> reloadUser() async {
    await _auth.refreshSession();
  }

  // ---------------- التحقق من رقم الهاتف (بدون تسجيل دخول به) ----------------
  // يربط رقم هاتف موثّق (verified) بنفس حساب المستخدم الحالي — ليس وسيلة
  // دخول بديلة، بس تأكيد ملكية الرقم. بيستخدم OTP نفسه اللي بيستخدمه
  // Supabase لتغيير رقم الهاتف (phone_change).

  /// يبعت رمز SMS لرقم الهاتف الجديد المطلوب ربطه بالحساب.
  Future<void> startPhoneVerification({
    required String phoneNumber,
    required void Function() onCodeSent,
    required void Function(AuthException e) onError,
  }) async {
    try {
      await _auth.updateUser(UserAttributes(phone: phoneNumber));
      onCodeSent();
    } on AuthException catch (e) {
      onError(e);
    }
  }

  /// يأكد رمز الـ SMS ويربط رقم الهاتف كموثّق بنفس الحساب الحالي.
  Future<void> confirmPhoneNumber({
    required String smsCode,
    required String phoneNumber,
  }) async {
    await _auth.verifyOTP(
      type: OtpType.phoneChange,
      phone: phoneNumber,
      token: smsCode,
    );
    // profiles.phone/phone_verified بينحدّثوا تلقائيًا عن طريق trigger
    // (on_auth_user_phone_updated) بمجرد ما auth.users.phone يتأكد.
  }

  // ---------------- المصادقة الثنائية 2FA (عامل ثاني: رمز SMS) ----------------

  /// يتحقق إذا كان الحساب مفعّل فيه أي عامل MFA موثّق (verified).
  Future<bool> checkMfaEnrolled() async {
    final res = await _auth.mfa.listFactors();
    return res.all.any((f) => f.status == FactorStatus.verified);
  }

  /// يبلش تفعيل 2FA: يسجّل رقم الهاتف كعامل ثاني جديد. Supabase بيبعت
  /// رمز SMS تلقائيًا فور التسجيل لعامل من نوع phone. يرجع null إذا حدث
  /// خطأ (بعد ما يكون onError انفذ فعلاً).
  Future<String?> startMfaEnrollment({
    required String phoneNumber,
    required void Function() onCodeSent,
    required void Function(AuthException e) onError,
  }) async {
    try {
      final res = await _auth.mfa.enroll(
        factorType: FactorType.phone,
        phone: phoneNumber,
        friendlyName: 'رقم الهاتف',
      );
      onCodeSent();
      return res.id; // factorId — تستخدمه مع confirmMfaEnrollment
    } on AuthException catch (e) {
      onError(e);
      return null;
    }
  }

  /// يأكد رمز التحقق ويفعّل عامل الـ 2FA فعليًا على الحساب.
  Future<void> confirmMfaEnrollment({
    required String factorId,
    required String smsCode,
  }) async {
    final challenge = await _auth.mfa.challenge(factorId: factorId);
    await _auth.mfa.verify(
      factorId: factorId,
      challengeId: challenge.id,
      code: smsCode,
    );
  }

  /// يلغي عامل 2FA الأول المسجّل (لو المستخدم بدو يوقف الميزة).
  Future<void> unenrollMfa() async {
    final res = await _auth.mfa.listFactors();
    final verified = res.all.where((f) => f.status == FactorStatus.verified);
    if (verified.isEmpty) return;
    await _auth.mfa.unenroll(verified.first.id);
  }

  // ---------------- تحدي 2FA أثناء تسجيل الدخول ----------------

  /// هل الجلسة الحالية محتاجة تحدي 2FA (aal2) قبل ما تكتمل؟
  Future<bool> needsMfaChallenge() async {
    final res = await _auth.mfa.getAuthenticatorAssuranceLevel();
    return res.currentLevel == AuthenticatorAssuranceLevels.aal1 &&
        res.nextLevel == AuthenticatorAssuranceLevels.aal2;
  }

  /// يجيب أول عامل MFA موثّق مسجّل على الحساب (لعرضه بشاشة التحدي).
  Future<Factor?> primaryMfaFactor() async {
    final res = await _auth.mfa.listFactors();
    final verified = res.all.where((f) => f.status == FactorStatus.verified);
    return verified.isEmpty ? null : verified.first;
  }

  /// الخطوة 1 من تحدي 2FA أثناء تسجيل الدخول: يبعت رمز SMS للعامل المسجّل.
  /// يرجع null لو حدث خطأ (بعد ما يكون onError انفذ فعلاً).
  Future<String?> sendMfaChallenge({
    required String factorId,
    required void Function() onCodeSent,
    required void Function(AuthException e) onError,
  }) async {
    try {
      final challenge = await _auth.mfa.challenge(factorId: factorId);
      onCodeSent();
      return challenge.id;
    } on AuthException catch (e) {
      onError(e);
      return null;
    }
  }

  /// الخطوة 2: يكمّل تسجيل الدخول بعد إدخال رمز الـ SMS الصحيح.
  Future<void> confirmMfaChallenge({
    required String factorId,
    required String challengeId,
    required String smsCode,
  }) async {
    await _auth.mfa.verify(factorId: factorId, challengeId: challengeId, code: smsCode);
  }
}
