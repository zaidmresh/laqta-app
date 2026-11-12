import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../supabase_config.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/phone_validator.dart';
import '../widgets/common_widgets.dart';

class EditProfileScreen extends StatefulWidget {
  final AppState appState;
  const EditProfileScreen({super.key, required this.appState});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();

  bool _savingName = false;
  bool _sendingVerifyEmail = false;
  bool _checkingEmail = false;

  // تحقق الهاتف
  bool _phoneStep = false; // true = ظاهر حقل إدخال الرمز
  bool _sendingOtp = false;
  bool _confirmingOtp = false;
  String? _phoneError;

  // 2FA
  bool _mfaStep = false;
  bool _sendingMfaOtp = false;
  bool _confirmingMfaOtp = false;
  String? _mfaFactorId;
  String? _mfaError;
  bool _mfaOn = false;
  bool _mfaLoading = true;
  final _mfaOtpCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final user = Supabase.instance.client.auth.currentUser;
    final meta = user?.userMetadata;
    _nameCtrl.text = (meta == null ? null : meta['name'] as String?) ?? '';
    _loadMfaStatus();
  }

  Future<void> _loadMfaStatus() async {
    final enrolled = await AuthService.instance.checkMfaEnrolled();
    if (!mounted) return;
    setState(() {
      _mfaOn = enrolled;
      _mfaLoading = false;
    });
  }

  User? get _user => Supabase.instance.client.auth.currentUser;

  Future<void> _saveName() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _savingName = true);
    try {
      await AuthService.instance.updateProfile(name: _nameCtrl.text.trim());
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ الاسم ✅')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذّر الحفظ، يرجى المحاولة مرة أخرى')));
    } finally {
      if (mounted) setState(() => _savingName = false);
    }
  }

  Future<void> _sendVerifyEmail() async {
    setState(() => _sendingVerifyEmail = true);
    try {
      await AuthService.instance.sendEmailVerification(emailRedirectTo: kEmailConfirmedUrl);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال رابط التحقق لإيميلك — افتحه ثم ارجع هون واضغط "تحقّق الآن"')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذّر الإرسال، حاول بعد شوي')));
    } finally {
      if (mounted) setState(() => _sendingVerifyEmail = false);
    }
  }

  Future<void> _checkEmailVerified() async {
    setState(() => _checkingEmail = true);
    try {
      await AuthService.instance.reloadUser();
    } finally {
      if (mounted) setState(() => _checkingEmail = false);
    }
    if (!mounted) return;
    if (!AuthService.instance.isEmailVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لسا ما انتحقق — تأكد إنك ضغطت الرابط اللي وصلك بإيميلك')),
      );
    }
  }

  Future<void> _sendPhoneOtp() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) return;
    final validationError = PhoneValidator.validate(phone);
    if (validationError != null) {
      setState(() => _phoneError = validationError);
      return;
    }
    setState(() {
      _sendingOtp = true;
      _phoneError = null;
    });
    try {
      await AuthService.instance.startPhoneVerification(
        phoneNumber: phone,
        onCodeSent: () {
          if (!mounted) return;
          setState(() {
            _phoneStep = true;
            _sendingOtp = false;
          });
        },
        onError: (e) {
          if (!mounted) return;
          setState(() {
            _phoneError = 'تعذّر إرسال الرمز: ${e.message}';
            _sendingOtp = false;
          });
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _phoneError = 'تعذّر إرسال الرمز، تأكد من رقم الهاتف (بصيغة دولية مثل +962...)';
          _sendingOtp = false;
        });
      }
    }
  }

  Future<void> _confirmPhoneOtp() async {
    if (_otpCtrl.text.trim().isEmpty) return;
    setState(() {
      _confirmingOtp = true;
      _phoneError = null;
    });
    try {
      await AuthService.instance.confirmPhoneNumber(
        smsCode: _otpCtrl.text.trim(),
        phoneNumber: _phoneCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _phoneStep = false;
        _otpCtrl.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم توثيق رقم الهاتف ✅')));
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      setState(() => _phoneError =
          msg.contains('invalid') || msg.contains('expired') ? 'رمز التحقق غلط' : 'حدث خطأ، يرجى المحاولة مرة أخرى');
    } catch (e) {
      setState(() => _phoneError = 'حدث خطأ، يرجى المحاولة مرة أخرى');
    } finally {
      if (mounted) setState(() => _confirmingOtp = false);
    }
  }

  Future<void> _sendMfaOtp() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      setState(() => _mfaError = 'وثّق رقم هاتفك أول (بالأعلى) قبل ما تفعّل 2FA');
      return;
    }
    setState(() {
      _sendingMfaOtp = true;
      _mfaError = null;
    });
    final factorId = await AuthService.instance.startMfaEnrollment(
      phoneNumber: phone,
      onCodeSent: () {
        if (!mounted) return;
        setState(() {
          _mfaStep = true;
          _sendingMfaOtp = false;
        });
      },
      onError: (e) {
        if (!mounted) return;
        setState(() {
          _mfaError = 'تعذّر إرسال الرمز: ${e.message}';
          _sendingMfaOtp = false;
        });
      },
    );
    if (factorId != null) _mfaFactorId = factorId;
  }

  Future<void> _confirmMfaOtp() async {
    if (_mfaFactorId == null || _mfaOtpCtrl.text.trim().isEmpty) return;
    setState(() {
      _confirmingMfaOtp = true;
      _mfaError = null;
    });
    try {
      await AuthService.instance.confirmMfaEnrollment(
        factorId: _mfaFactorId!,
        smsCode: _mfaOtpCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _mfaStep = false;
        _mfaOtpCtrl.clear();
      });
      await _loadMfaStatus();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تفعيل التحقق بخطوتين (2FA) ✅')));
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      setState(() => _mfaError =
          msg.contains('invalid') || msg.contains('expired') ? 'رمز التحقق غلط' : 'حدث خطأ، يرجى المحاولة مرة أخرى');
    } catch (e) {
      setState(() => _mfaError = 'حدث خطأ، يرجى المحاولة مرة أخرى');
    } finally {
      if (mounted) setState(() => _confirmingMfaOtp = false);
    }
  }

  Future<void> _disableMfa() async {
    try {
      await AuthService.instance.unenrollMfa();
      if (!mounted) return;
      await _loadMfaStatus();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إيقاف 2FA')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذّر الإيقاف')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final emailVerified = AuthService.instance.isEmailVerified;
    final phoneVerified = user?.phoneConfirmedAt != null;
    final mfaOn = _mfaOn;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 30),
      children: [
        SubHeader(title: 'تعديل الملف الشخصي', onBack: widget.appState.back),

        Text('الاسم', style: AppTextStyles.body(size: 12.5, weight: FontWeight.bold)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(child: TextField(controller: _nameCtrl, decoration: const InputDecoration(hintText: 'اسمك'))),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _savingName ? null : _saveName,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.tealDark),
              child: _savingName
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('حفظ', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),

        const SizedBox(height: 22),
        Text('البريد الإلكتروني', style: AppTextStyles.body(size: 12.5, weight: FontWeight.bold)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.card,
            border: Border.all(color: AppColors.sandLine),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            children: [
              Expanded(child: Text(user?.email ?? '', style: AppTextStyles.body(size: 12.5))),
              if (emailVerified)
                const _Badge(text: 'موثّق ✓', color: AppColors.teal)
              else
                Row(
                  children: [
                    TextButton(
                      onPressed: _checkingEmail ? null : _checkEmailVerified,
                      child: Text(_checkingEmail ? '...' : 'تحقّق الآن'),
                    ),
                    TextButton(
                      onPressed: _sendingVerifyEmail ? null : _sendVerifyEmail,
                      child: Text(_sendingVerifyEmail ? '...' : 'إرسال رابط'),
                    ),
                  ],
                ),
            ],
          ),
        ),

        const SizedBox(height: 22),
        Text('رقم الهاتف', style: AppTextStyles.body(size: 12.5, weight: FontWeight.bold)),
        const SizedBox(height: 6),
        if (phoneVerified)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.card,
              border: Border.all(color: AppColors.sandLine),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Row(
              children: [
                Expanded(child: Text(user!.phone ?? '', style: AppTextStyles.body(size: 12.5))),
                const _Badge(text: 'موثّق ✓', color: AppColors.teal),
              ],
            ),
          )
        else ...[
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(hintText: '+962 7X XXX XXXX'),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _sendingOtp ? null : _sendPhoneOtp,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.tealDark),
                child: _sendingOtp
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('إرسال رمز', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
          if (_phoneStep) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _otpCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: 'رمز التحقق'),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _confirmingOtp ? null : _confirmPhoneOtp,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.brass),
                  child: _confirmingOtp
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text('تأكيد', style: AppTextStyles.body(size: 12.5, weight: FontWeight.bold, color: AppColors.tealDark)),
                ),
              ],
            ),
          ],
          if (_phoneError != null) ...[
            const SizedBox(height: 6),
            Text(_phoneError!, style: AppTextStyles.body(size: 11.5, color: AppColors.danger)),
          ],
        ],

        const SizedBox(height: 22),
        Text('التحقق بخطوتين (2FA)', style: AppTextStyles.body(size: 12.5, weight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(
          'طبقة حماية إضافية — بعد كلمة المرور، رح تحتاج رمز SMS كل ما تسجّل دخول من جهاز جديد.',
          style: AppTextStyles.body(size: 11, color: AppColors.inkSoft),
        ),
        const SizedBox(height: 8),
        if (_mfaLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (mfaOn)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.tealTint, borderRadius: BorderRadius.circular(11)),
            child: Row(
              children: [
                Expanded(
                  child: Text('مفعّل ✓', style: AppTextStyles.body(size: 12.5, weight: FontWeight.bold, color: AppColors.tealDark)),
                ),
                TextButton(onPressed: _disableMfa, child: const Text('إيقاف')),
              ],
            ),
          )
        else ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _sendingMfaOtp ? null : _sendMfaOtp,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.tealDark,
                side: const BorderSide(color: AppColors.teal, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(_sendingMfaOtp ? '...' : 'فعّل التحقق بخطوتين'),
            ),
          ),
          if (_mfaStep) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _mfaOtpCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: 'رمز التحقق'),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _confirmingMfaOtp ? null : _confirmMfaOtp,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.brass),
                  child: _confirmingMfaOtp
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text('تفعيل', style: AppTextStyles.body(size: 12.5, weight: FontWeight.bold, color: AppColors.tealDark)),
                ),
              ],
            ),
          ],
          if (_mfaError != null) ...[
            const SizedBox(height: 6),
            Text(_mfaError!, style: AppTextStyles.body(size: 11.5, color: AppColors.danger)),
          ],
        ],
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: AppTextStyles.body(size: 10.5, weight: FontWeight.bold, color: color)),
    );
  }
}
