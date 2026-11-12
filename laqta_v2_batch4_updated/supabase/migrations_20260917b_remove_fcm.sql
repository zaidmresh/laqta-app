-- شغّل هذا الملف مرة واحدة على قاعدة بياناتك الحالية بـ Supabase:
-- Dashboard → SQL Editor → New query → الصق المحتوى → Run
--
-- يُشغَّل بعد إزالة Firebase من التطبيق (لم تعد الإشعارات مستخدَمة).
-- لا يحذف أي بيانات أخرى.

alter table public.profiles drop column if exists fcm_token;
