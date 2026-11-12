import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../supabase_config.dart';
import '../theme/app_theme.dart';
import '../utils/password_validator.dart';
import '../utils/phone_validator.dart';

/// شاشة تسجيل الدخول / إنشاء حساب جديد.
/// تظهر قبل RootShell إذا ما كان في مستخدم مسجّل دخول.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();

  bool _isSignUp = false;
  bool _loading = false;
  String? _error;

  // حالة تأكيد الحساب بكود من 4 أرقام بعد التسجيل (بدل رابط الإيميل).
  String? _pendingConfirmEmail;
  bool _confirmCodeSent = false;

  // حالة تحدي 2FA (لما الحساب يكون مفعّل فيه مصادقة ثنائية).
  // Supabase، خلافًا لفايربيس، ما بيرمي استثناء وقت signIn لو الحساب محتاج
  // 2FA — الجلسة بترجع بمستوى aal1 بس، فلازم نتحقق يدويًا بعد الدخول.
  String? _mfaFactorId;
  String? _mfaChallengeId;
  bool _mfaCodeSent = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_isSignUp) {
        await AuthService.instance.signUp(
          name: _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text,
          role: 'buyer', // كل حساب جديد يقدر يشتري ويبيع معًا — لا يوجد تمييز أدوار عند التسجيل
          phone: _phoneCtrl.text.trim(),
          location: _locationCtrl.text.trim(),
          emailRedirectTo: kEmailConfirmedUrl,
        );
        setState(() {
          _pendingConfirmEmail = _emailCtrl.text.trim();
          _confirmCodeSent = true;
        });
      } else {
        await AuthService.instance.signIn(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text,
        );
        if (await AuthService.instance.needsMfaChallenge()) {
          final factor = await AuthService.instance.primaryMfaFactor();
          if (factor != null) {
            setState(() => _mfaFactorId = factor.id);
            await _sendMfaCode();
          }
        }
      }
      // بعد النجاح (وبدون 2FA)، ينتقل StreamBuilder بـ main.dart تلقائيًا لـ RootShell
    } catch (e) {
      setState(() => _error = _friendlyError(e.toString()));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendMfaCode() async {
    if (_mfaFactorId == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final challengeId = await AuthService.instance.sendMfaChallenge(
      factorId: _mfaFactorId!,
      onCodeSent: () => setState(() => _mfaCodeSent = true),
      onError: (e) => setState(() => _error = 'تعذّر إرسال رمز التحقق: ${e.message}'),
    );
    if (challengeId != null) _mfaChallengeId = challengeId;
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _confirmMfaCode() async {
    if (_mfaFactorId == null || _mfaChallengeId == null) return;
    if (_otpCtrl.text.trim().length < 4) {
      setState(() => _error = 'أدخل رمز التحقق كامل');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService.instance.confirmMfaChallenge(
        factorId: _mfaFactorId!,
        challengeId: _mfaChallengeId!,
        smsCode: _otpCtrl.text.trim(),
      );
      // بعد النجاح، ينتقل StreamBuilder بـ main.dart تلقائيًا (بعد اكتمال aal2)
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      setState(() => _error = msg.contains('invalid') || msg.contains('expired')
          ? 'رمز التحقق غلط أو منتهي، جرّب تبعت رمز جديد'
          : 'حدث خطأ، يرجى المحاولة مرة أخرى');
    } catch (e) {
      setState(() => _error = 'حدث خطأ، يرجى المحاولة مرة أخرى');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _locationCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  void _cancelMfa() {
    setState(() {
      _mfaFactorId = null;
      _mfaChallengeId = null;
      _mfaCodeSent = false;
      _otpCtrl.clear();
      _error = null;
    });
  }

  Future<void> _showForgotPasswordDialog() async {
    final emailCtrl = TextEditingController(text: _emailCtrl.text.trim());
    String? dialogError;
    bool sending = false;
    bool sent = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('نسيت كلمة المرور؟'),
          content: sent
              ? const Text('تم إرسال رابط إعادة تعيين كلمة المرور لإيميلك ✅')
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('اكتب بريدك الإلكتروني وبنبعتلك رابط لإعادة تعيين كلمة المرور.'),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'البريد الإلكتروني'),
                    ),
                    if (dialogError != null) ...[
                      const SizedBox(height: 8),
                      Text(dialogError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                    ],
                  ],
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(sent ? 'تمام' : 'إلغاء'),
            ),
            if (!sent)
              TextButton(
                onPressed: sending
                    ? null
                    : () async {
                        if (!emailCtrl.text.contains('@')) {
                          setDialogState(() => dialogError = 'اكتب بريد صحيح');
                          return;
                        }
                        setDialogState(() {
                          sending = true;
                          dialogError = null;
                        });
                        try {
                          await AuthService.instance
                              .resetPassword(emailCtrl.text.trim(), redirectTo: kPasswordResetDeepLink);
                          setDialogState(() => sent = true);
                        } catch (e) {
                          setDialogState(() => dialogError = 'تعذّر الإرسال، تأكد من البريد');
                        } finally {
                          setDialogState(() => sending = false);
                        }
                      },
                child: sending
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('إرسال'),
              ),
          ],
        ),
      ),
    );
  }

  /// Supabase Auth ما بيرجع أكواد أخطاء بأسماء موحّدة متل فايربيس (user-not-found
  /// إلخ) — رسائله نصّية إنجليزية، فبنتحقق من مقاطع نصّية مألوفة منها.
  String _friendlyError(String raw) {
    final msg = raw.toLowerCase();
    if (msg.contains('already registered') || msg.contains('already exists')) {
      return 'هذا البريد الإلكتروني مستخدم مسبقًا';
    }
    if (msg.contains('unable to validate email') || msg.contains('invalid format') || msg.contains('invalid email')) {
      return 'صيغة البريد غير صحيحة';
    }
    if (msg.contains('password should be at least') || msg.contains('at least 6 characters') || msg.contains('weak')) {
      return 'كلمة المرور ضعيفة (6 أحرف كحد أدنى)';
    }
    if (msg.contains('invalid login credentials') || msg.contains('invalid_credentials')) {
      return 'البريد أو كلمة المرور غير صحيحة';
    }
    return 'حدث خطأ، يرجى المحاولة مرة أخرى';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1EAD9),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _pendingConfirmEmail != null
              ? _buildConfirmSignup()
              : (_mfaFactorId != null ? _buildMfaChallenge() : _buildForm()),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        const SizedBox(height: 40),
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(colors: [AppColors.teal, AppColors.tealDark]),
            ),
            alignment: Alignment.center,
            child: Text('ل', style: AppTextStyles.heading(size: 30, color: AppColors.brass)),
          ),
        ),
        const SizedBox(height: 12),
        Center(child: Text('لَقطة', style: AppTextStyles.heading(size: 26))),
      ],
    );
  }

  Widget _buildMfaChallenge() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildLogo(),
        const SizedBox(height: 8),
        Center(
          child: Text('التحقق بخطوتين (2FA)', style: AppTextStyles.body(size: 14, color: AppColors.inkSoft)),
        ),
        const SizedBox(height: 28),
        Text(
          _mfaCodeSent ? 'أدخل رمز التحقق المرسل لرقم هاتفك المسجّل' : 'عم نبعتلك رمز التحقق...',
          textAlign: TextAlign.center,
          style: AppTextStyles.body(size: 12.5, color: AppColors.inkSoft),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _otpCtrl,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          decoration: const InputDecoration(labelText: 'رمز التحقق'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
        ],
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _loading ? null : _confirmMfaCode,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.tealDark,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: _loading
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('تأكيد', style: TextStyle(color: Colors.white)),
        ),
        const SizedBox(height: 8),
        TextButton(onPressed: _loading ? null : _sendMfaCode, child: const Text('أعد إرسال الرمز')),
        TextButton(onPressed: _cancelMfa, child: const Text('رجوع')),
      ],
    );
  }

  Widget _buildConfirmSignup() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildLogo(),
        const SizedBox(height: 8),
        Center(
          child: Text('تأكيد الحساب', style: AppTextStyles.body(size: 14, color: AppColors.inkSoft)),
        ),
        const SizedBox(height: 28),
        Text(
          _confirmCodeSent
              ? 'أدخل رمز التحقق المرسل إلى بريدك الإلكتروني\n$_pendingConfirmEmail'
              : 'عم نبعتلك رمز التحقق...',
          textAlign: TextAlign.center,
          style: AppTextStyles.body(size: 12.5, color: AppColors.inkSoft),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _otpCtrl,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          decoration: const InputDecoration(labelText: 'رمز التحقق'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
        ],
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _loading ? null : _confirmSignupCode,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.tealDark,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: _loading
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('تأكيد', style: TextStyle(color: Colors.white)),
        ),
        const SizedBox(height: 8),
        TextButton(onPressed: _loading ? null : _resendSignupCode, child: const Text('أعد إرسال الرمز')),
        TextButton(
          onPressed: () => setState(() {
            _pendingConfirmEmail = null;
            _confirmCodeSent = false;
            _otpCtrl.clear();
            _error = null;
          }),
          child: const Text('رجوع'),
        ),
      ],
    );
  }

  Future<void> _confirmSignupCode() async {
    if (_pendingConfirmEmail == null) return;
    if (_otpCtrl.text.trim().length < 4) {
      setState(() => _error = 'أدخل رمز التحقق كامل');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.verifyOTP(
        email: _pendingConfirmEmail!,
        token: _otpCtrl.text.trim(),
        type: OtpType.signup,
      );
      // بعد النجاح، ينتقل StreamBuilder بـ main.dart تلقائيًا لـ RootShell
      // (verifyOTP بينشئ جلسة صالحة فورًا).
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      setState(() => _error = msg.contains('expired') || msg.contains('invalid')
          ? 'الرمز غير صحيح أو منتهي الصلاحية، اطلب رمزًا جديدًا'
          : 'صار خطأ، حاول مرة أخرى');
    } catch (e) {
      setState(() => _error = 'صار خطأ، حاول مرة أخرى');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resendSignupCode() async {
    if (_pendingConfirmEmail == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: _pendingConfirmEmail!,
        emailRedirectTo: kEmailConfirmedUrl,
      );
      if (mounted) setState(() => _confirmCodeSent = true);
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذّر إعادة الإرسال، حاول بعد قليل');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildLogo(),
          Center(
            child: Text(
              _isSignUp ? 'إنشاء حساب جديد' : 'تسجيل الدخول',
              style: AppTextStyles.body(size: 14, color: AppColors.inkSoft),
            ),
          ),
          const SizedBox(height: 28),
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'البريد الإلكتروني'),
            validator: (v) => (v == null || !v.contains('@')) ? 'اكتب بريد إلكتروني صحيح' : null,
          ),
          const SizedBox(height: 14),
          if (_isSignUp) ...[
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'الاسم الكامل'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'اكتب اسمك' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'رقم الهاتف', hintText: '07XXXXXXXX'),
              validator: (v) => PhoneValidator.validate(v ?? ''),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _locationCtrl,
              decoration: const InputDecoration(labelText: 'المدينة / المنطقة', hintText: 'مثال: عمّان - جبل الحسين'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'اكتب مدينتك أو منطقتك' : null,
            ),
            const SizedBox(height: 14),
          ],
          TextFormField(
            controller: _passCtrl,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'كلمة المرور'),
            validator: (v) {
              if (v == null || v.isEmpty) return 'اكتب كلمة المرور';
              if (!_isSignUp) return null; // تسجيل الدخول: لا نفرض سياسة القوة على كلمة مرور قديمة
              return PasswordValidator.validate(v);
            },
            onChanged: (_) {
              if (_isSignUp) setState(() {});
            },
          ),
          if (_isSignUp) ...[
            const SizedBox(height: 6),
            _StrengthBar(password: _passCtrl.text),
            const SizedBox(height: 14),
            TextFormField(
              controller: _confirmPassCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'تأكيد كلمة المرور'),
              validator: (v) => (v != _passCtrl.text) ? 'كلمتا المرور غير متطابقتين' : null,
            ),
          ],
          if (!_isSignUp)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _showForgotPasswordDialog,
                child: const Text('نسيت كلمة المرور؟'),
              ),
            ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.tealDark,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    _isSignUp ? 'إنشاء الحساب' : 'دخول',
                    style: const TextStyle(color: Colors.white),
                  ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => setState(() => _isSignUp = !_isSignUp),
            child: Text(_isSignUp ? 'عندك حساب؟ سجّل دخول' : 'ما عندك حساب؟ سجّل واحد جديد'),
          ),
        ],
      ),
    );
  }
}

class _StrengthBar extends StatelessWidget {
  final String password;
  const _StrengthBar({required this.password});

  @override
  Widget build(BuildContext context) {
    final strength = PasswordValidator.strength(password);
    if (strength == PasswordStrength.none) return const SizedBox.shrink();

    final (label, color, ratio) = switch (strength) {
      PasswordStrength.weak => ('ضعيفة', AppColors.danger, 0.33),
      PasswordStrength.medium => ('متوسطة', AppColors.brass, 0.66),
      PasswordStrength.strong => ('قوية', AppColors.teal, 1.0),
      PasswordStrength.none => ('', AppColors.inkSoft, 0.0),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 5,
            backgroundColor: AppColors.sandLine,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        const SizedBox(height: 3),
        Text('قوة كلمة المرور: $label', style: AppTextStyles.body(size: 10.5, color: color)),
      ],
    );
  }
}
