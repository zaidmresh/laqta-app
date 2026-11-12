/// إعدادات الاتصال بمشروع Supabase الخاص فيك.
///
/// كيف تجيبهم (بعد ما تنشئ مشروع على supabase.com — راجع SUPABASE_SETUP.md
/// خطوة 1): من لوحة تحكم المشروع → Project Settings → Data API
///   - Project URL             → SUPABASE_URL
///   - anon / public API key   → SUPABASE_ANON_KEY
///
/// ملاحظة أمان: anon key هذا آمن وضعه بكود التطبيق (client-side) — هو
/// مصمم لهيك، ومحمي بواسطة RLS policies بقاعدة البيانات (schema.sql).
/// الذي لا تضعه أبدًا بالتطبيق هو service_role key — يبقى هذا فقط داخل
/// Edge Functions (متوفر تلقائيًا هناك، ما بتحتاج تدخله يدويًا).
library;

const String kSupabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://laufdfvzodhyrwvhlttm.supabase.co',
);

/// اسمه القديم "anon key"، والاسم الجديد "publishable key" — نفس المفتاح
/// بالضبط، بس Supabase غيّر التسمية بآخر نسخة.
const String kSupabasePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
  defaultValue:
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxhdWZkZnZ6b2RoeXJ3dmhsdHRtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODk0Mjg1NjUsImV4cCI6MjEwNTAwNDU2NX0.n-murWHf02aMMG3u70LjwL6HkpR-MEXRMLv8CwSDr3s',
);

/// رابط صفحة إعادة تعيين كلمة المرور بعد رفعها لـ Storage — بدّله بالرابط
/// العام الحقيقي بعد ما تتّبع خطوات SUPABASE_SETUP.md (قسم إعادة تعيين
/// كلمة المرور).
const String kPasswordResetUrl = String.fromEnvironment(
  'PASSWORD_RESET_URL',
  defaultValue: 'https://laufdfvzodhyrwvhlttm.supabase.co/storage/v1/object/public/site/reset-password.html',
);

/// رابط صفحة تأكيد الحساب بعد رفعها لنفس مجلد Storage. بدونه، رابط تأكيد
/// الإيميل بيرجعك للـ Site URL الافتراضي بلوحة Supabase (غالبًا رابط
/// تطوير محلي زي localhost غير مناسب للمستخدم النهائي).
const String kEmailConfirmedUrl = String.fromEnvironment(
  'EMAIL_CONFIRMED_URL',
  defaultValue: 'https://laufdfvzodhyrwvhlttm.supabase.co/storage/v1/object/public/site/email-confirmed.html',
);

/// رابط Deep Link الحقيقي لإعادة تعيين كلمة المرور — بيفتح التطبيق نفسه
/// مباشرة (مو صفحة ويب) عند الضغط على رابط الإيميل من الموبايل. لازم
/// يكون مضاف حرفيًا لقائمة Redirect URLs بلوحة Supabase (راجع
/// SUPABASE_SETUP.md)، ومطابق تمامًا للمخطط المسجّل بـ AndroidManifest.xml.
const String kPasswordResetDeepLink = 'io.supabase.laqta://reset-callback';
