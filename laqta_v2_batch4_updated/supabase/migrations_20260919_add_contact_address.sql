-- شغّل هذا الملف مرة واحدة على قاعدة بياناتك الحالية بـ Supabase:
-- Dashboard → SQL Editor → New query → الصق المحتوى → Run
--
-- يضيف عمود عنوان التواصل (عنوان البائع) لكل منتج، يُدخله البائع إلزاميًا
-- عند نشر المنتج. لا يحذف أو يعدّل أي بيانات موجودة. المنتجات القديمة
-- (قبل هذا التحديث) بتاخذ قيمة فاضية افتراضيًا.

alter table public.products
  add column if not exists contact_address text not null default '';
