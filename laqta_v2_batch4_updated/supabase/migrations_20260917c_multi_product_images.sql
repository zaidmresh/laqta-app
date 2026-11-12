-- شغّل هذا الملف مرة واحدة على قاعدة بياناتك الحالية بـ Supabase:
-- Dashboard → SQL Editor → New query → الصق المحتوى → Run
--
-- يضيف دعم رفع أكثر من صورة لكل منتج. لا يحذف أو يعدّل أي بيانات موجودة:
-- عمود image_url القديم يبقى كما هو (الصورة الرئيسية)، ونضيف عمود جديد
-- image_urls (مصفوفة نصوص) فيه كل صور المنتج بالترتيب. أي منتج قديم
-- عنده صورة وحدة بس بيتحوّل تلقائيًا لمصفوفة من عنصر واحد.

alter table public.products
  add column if not exists image_urls text[] not null default '{}';

update public.products
set image_urls = array[image_url]
where image_url is not null
  and image_url <> ''
  and (image_urls is null or array_length(image_urls, 1) is null);
