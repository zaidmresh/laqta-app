# دليل إعداد لَقطة على Supabase

هذا الدليل يشرح خطوة بخطوة كيف تجهّز مشروع Supabase من الصفر وتربطه
بالتطبيق. التطبيق لا يعتمد على أي خدمة خارج Supabase.

---

## 0) الأدوات المطلوبة على جهازك

- حساب مجاني على [supabase.com](https://supabase.com)
- [Supabase CLI](https://supabase.com/docs/guides/cli) لنشر الـ Edge Functions:
  ```bash
  npm install -g supabase
  ```
- Flutter SDK (نفس اللي كنت تستخدمه قبل).

---

## 1) إنشاء مشروع Supabase

1. سجّل دخول على supabase.com → **New Project**.
2. اختر اسم، باسورد لقاعدة البيانات (احفظه بمكان آمن)، والمنطقة الأقرب لك.
3. انتظر لين يخلص التجهيز (دقيقتين تقريبًا).
4. من **Project Settings → Data API** انسخ:
   - **Project URL**
   - **anon public key**
   حطهم بملف `lib/supabase_config.dart` (أو مرّرهم وقت البناء بـ
   `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`).

---

## 2) تشغيل السكيما (الجداول + الصلاحيات)

من لوحة تحكم مشروعك: **SQL Editor → New query**.

الصق محتوى `supabase/schema.sql` بالكامل واضغط **Run**.

للتأكد إنه كل شي تمام: **Table Editor** المفروض تشوف فيه profiles,
products, conversations, messages.

---

## 3) إنشاء Storage bucket لصور المنتجات

من **Storage → New bucket**:
- الاسم بالضبط: `product-images`
- فعّل **Public bucket** ✅ (عشان روابط الصور تشتغل مباشرة بالتطبيق بدون توقيع)
- **Restrict file size**: 5 MB مثلًا (اختياري بس منطقي لصور منتجات)
- **Restrict MIME types**: `image/jpeg,image/png,image/webp` (اختياري)

⚠️ "Public bucket" بيسمح بالقراءة بس بدون توثيق — الرفع/الحذف محتاجين
RLS policy صريح. هاد موجود أصلًا بآخر `supabase/schema.sql` (قسم
"Storage policies") — إذا شغّلت schema.sql *قبل* ما تنشئ الـ bucket،
لازم ترجع تشغّل هالجزء بمفرده من SQL Editor بعد إنشاء الـ bucket:

```sql
create policy "product_images_public_read" on storage.objects
  for select using (bucket_id = 'product-images');

create policy "product_images_owner_insert" on storage.objects
  for insert with check (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "product_images_owner_delete" on storage.objects
  for delete using (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
```

---

## 4) إعداد تسجيل الدخول بالهاتف (Phone OTP + 2FA)

التطبيق بيستخدم رقم الهاتف لشيئين: توثيق ملكية الرقم، والمصادقة الثنائية
(2FA). كلاهما محتاج مزوّد SMS مفعّل:

1. **Authentication → Providers → Phone** → فعّله.
2. اختر مزوّد SMS (Twilio, MessageBird, Vonage...) وحط بياناته (Account
   SID / Auth Token / رقم المرسل). Twilio أسهل خيار للبداية.
3. **Authentication → Multi-Factor Authentication** → تأكد إنه Phone
   factor type مفعّل (مفعّل افتراضيًا بمعظم المشاريع الجديدة).

> ملاحظة: بدون هالخطوة، أزرار "توثيق رقم الهاتف" و"تفعيل 2FA" بالتطبيق
> رح ترجع خطأ من Supabase — باقي التطبيق (تسجيل دخول بالإيميل، تصفح،
> شراء) بيشتغل طبيعي بدونها.

---

## 5) قالب إيميل تأكيد الحساب (Confirm signup)

التطبيق يستخدم رمز تأكيد من 4-6 أرقام (OTP) بدل رابط تأكيد — المستخدم
يدخل الرمز مباشرة داخل التطبيق بعد التسجيل. لازم تعدّلي قالب الإيميل
الافتراضي من Supabase عشان يعرض الرمز بدل الرابط:

1. من **Authentication → Email Templates** اختاري **Confirm signup**.
2. امسحي محتوى الحقل بالكامل، والصقي بدله:
   ```html
   <h2>تأكيد حسابك بلَقطة</h2>
   <p>استخدم الرمز التالي لتأكيد حسابك داخل التطبيق:</p>
   <h1 style="letter-spacing: 4px; font-size: 32px;">{{ .Token }}</h1>
   <p>هذا الرمز صالح لمدة محدودة فقط.</p>
   ```
3. احفظي (**Save**).

> `{{ .Token }}` هو المتغيّر اللي بيحط Supabase مكانه رمز الأرقام تلقائيًا
> — ما تعدّليه. هذا القالب خاص بـ *Confirm signup* فقط؛ قوالب "Reset
> password" و"Magic Link" وغيرها تبقى منفصلة (Reset password مربوط
> بصفحة ويب، راجع القسم التالي).

---

## 6) رفع صفحة إعادة تعيين كلمة المرور

التطبيق بيرسل بريد "نسيت كلمة المرور" فيه رابط بيوجّه المستخدم لصفحة ويب
(مش شاشة داخل التطبيق) لإدخال كلمة مرور جديدة. هاي الصفحة (`web_pages/reset-password.html`)
لازم تُرفع يدويًا لمرة واحدة على Supabase Storage:

1. من **Storage → New bucket**: اسم الـ bucket بالضبط `site`، وفعّل
   **Public bucket** ✅.
2. ادخل على الـ bucket، اضغط **Upload file**، واختر ملف
   `web_pages/reset-password.html` من جهازك مباشرة (**لا تنسخ-تلصق محتواه
   بأي محرر نصوص أو مربع نص** — النسخ واللصق بيفسد ترميز الأحرف العربية
   ويظهرها مشوّهة عند فتح الرابط. ارفعي الملف نفسه كما هو).
3. بعد الرفع، تأكدي إن رابط الملف مطابق تمامًا للقيمة الافتراضية
   بـ `lib/supabase_config.dart` (`kPasswordResetUrl`). لو غيّرتِ اسم
   المشروع أو الـ bucket، حدّثي هذا الرابط بنفس الملف.
4. من **Authentication → URL Configuration**: أضيفي نفس الرابط لقائمة
   **Redirect URLs** المسموحة (وإلا Supabase برفض التوجيه إليه).

---

## 7) تفعيل حساب أدمن

بعد ما تسجّل حساب بالتطبيق عاديًا (بالإيميل)، شغّل بـ SQL Editor:

```sql
update public.profiles set is_admin = true where email = 'you@example.com';
```

ما في داعي تسجّل خروج/دخول من جديد — `is_admin` تُفحص من الجدول مباشرة.

---

## 8) تشغيل التطبيق

```bash
flutter pub get
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR-PROJECT-REF.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR-ANON-KEY
```

أو بكل بساطة عدّل القيم الافتراضية مباشرة بملف `lib/supabase_config.dart`
وشغّل `flutter run` عادي بدون `--dart-define`.

---

## ملاحظات مهمة

- **لا يوجد إشعارات push بالتطبيق حاليًا.** تم إزالة Firebase بالكامل.
  إذا بدك تضيفها لاحقًا، Supabase نفسه ما عنده حل push جاهز، فبتحتاج خدمة
  خارجية (OneSignal مثلًا) أو تربط Firebase من جديد لهذا الغرض فقط.
- محادثات شاشة الدردشة (`chat_screen.dart` / `messages_screen.dart`)
  مربوطة فعليًا بجداول `conversations` و`messages` الحقيقية (بث لحظي عبر
  Realtime) — مش بيانات وهمية.
- **لا يوجد نظام دفع أو سلة أو طلبات بالتطبيق.** عملية الشراء بالكامل
  تتم عبر التواصل المباشر: كل منتج فيه رقم هاتف تواصل (`contact_phone`)
  يُدخله البائع إلزاميًا عند النشر، وزر "اتصل بالبائع" بشاشة تفاصيل
  المنتج بيفتح تطبيق الهاتف مباشرة على هذا الرقم.
