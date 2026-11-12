import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_deep_link_controller.dart';
import '../theme/app_theme.dart';
import '../utils/password_validator.dart';

/// تظهر تلقائيًا فوق أي شاشة تانية لما يفتح المستخدم رابط "استعادة كلمة
/// المرور" من إيميله (سواء كان مسجّل دخول أصلاً أو لأ) — راجع
/// main.dart::AuthGate و AuthDeepLinkController.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  bool _done = false;
  String? _error;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _passCtrl.text),
      );
      setState(() => _done = true);
      // نسجّل خروج بعد النجاح عشان يدخل المستخدم من جديد بكلمة المرور
      // الجديدة، بدل ما يضل بجلسة الاستعادة المؤقتة.
      await Future.delayed(const Duration(seconds: 2));
      await Supabase.instance.client.auth.signOut();
      AuthDeepLinkController.isPasswordRecovery.value = false;
    } on AuthException catch (e) {
      setState(() => _error = 'تعذّر تحديث كلمة المرور: ${e.message}');
    } catch (e) {
      setState(() => _error = 'حدث خطأ، يرجى المحاولة مرة أخرى');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1EAD9),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _done ? _buildSuccess() : _buildForm(),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccess() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('✅', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 16),
        Text('تم تحديث كلمة المرور بنجاح', style: AppTextStyles.heading(size: 18)),
        const SizedBox(height: 8),
        Text('يمكنك الآن تسجيل الدخول بكلمة المرور الجديدة...',
            style: AppTextStyles.body(size: 12.5, color: AppColors.inkSoft)),
      ],
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
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
          const SizedBox(height: 20),
          Center(child: Text('تعيين كلمة مرور جديدة', style: AppTextStyles.heading(size: 18))),
          const SizedBox(height: 6),
          Center(
            child: Text('اكتب كلمة مرور جديدة لحسابك',
                style: AppTextStyles.body(size: 12.5, color: AppColors.inkSoft)),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _passCtrl,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'كلمة المرور الجديدة'),
            validator: (v) => PasswordValidator.validate(v ?? ''),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 6),
          _StrengthIndicator(password: _passCtrl.text),
          const SizedBox(height: 14),
          TextFormField(
            controller: _confirmCtrl,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'تأكيد كلمة المرور'),
            validator: (v) => (v != _passCtrl.text) ? 'كلمتا المرور غير متطابقتين' : null,
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
                    height: 20, width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('حفظ كلمة المرور الجديدة', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _StrengthIndicator extends StatelessWidget {
  final String password;
  const _StrengthIndicator({required this.password});

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
