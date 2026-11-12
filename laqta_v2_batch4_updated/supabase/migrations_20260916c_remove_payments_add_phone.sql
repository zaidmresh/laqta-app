-- تشغّل هذا الملف مرة واحدة على قاعدة بياناتك الحالية بـ Supabase:
-- Dashboard → SQL Editor → New query → الصق المحتوى → Run
--
-- ⚠️ تحذير مهم: هذا الملف يحذف جداول الدفع بالكامل (orders, order_groups,
-- seller_balances, seller_balance_ledger, payout_requests, carts) وكل
-- البيانات بداخلها بشكل نهائي لا يمكن التراجع عنه. لا تُشغّله إذا كان عندك
-- طلبات شراء حقيقية تحتاج الاحتفاظ بسجلّها. خذ نسخة احتياطية أولاً إذا لزم.

-- 1) إضافة رقم هاتف التواصل لكل منتج
alter table public.products add column if not exists contact_phone text not null default '';
alter table public.products alter column contact_phone drop default;

-- 2) إزالة أعمدة حجز الدفع (لم تعد مستخدمة)
alter table public.products drop column if exists order_status;
alter table public.products drop column if exists reserved_order_id;

-- 3) إصلاح تسريب: المنتجات قيد المراجعة/المرفوضة ما تظهر إلا لصاحبها أو الأدمن
drop policy if exists "products_select_authenticated" on public.products;
drop policy if exists "products_select_visible" on public.products;
create policy "products_select_visible" on public.products
  for select using (
    status = 'approved' or auth.uid() = seller_uid or public.is_admin()
  );

drop policy if exists "products_insert_own" on public.products;
create policy "products_insert_own" on public.products
  for insert with check (auth.uid() = seller_uid and status = 'pending');

-- 4) حذف جداول نظام الدفع بالكامل (الشراء أصبح عبر التواصل الهاتفي فقط)
drop table if exists public.payout_requests cascade;
drop table if exists public.seller_balance_ledger cascade;
drop table if exists public.seller_balances cascade;
drop table if exists public.orders cascade;
drop table if exists public.order_groups cascade;
drop table if exists public.carts cascade;

-- 5) حذف دوال RPC الخاصة بالدفع (لم تعد مستخدمة، وأصبحت غير صالحة أصلًا
-- بعد حذف الجداول أعلاه)
drop function if exists public.create_order_group(uuid, text, text, jsonb);
drop function if exists public.process_payment_result(uuid, text, text);
drop function if exists public.confirm_cod_delivery(uuid, uuid, boolean);
drop function if exists public.request_payout(uuid);
drop function if exists public.mark_payout_sent(uuid, text);
