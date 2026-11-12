-- شغّل هذا الملف مرة واحدة على قاعدة بياناتك الحالية بـ Supabase:
-- Dashboard → SQL Editor → New query → الصق المحتوى → Run
--
-- يضيف جدول المفضّلة (favorites) فقط — لا يحذف أو يعدّل أي بيانات موجودة.

create table if not exists public.favorites (
  uid uuid not null references auth.users (id) on delete cascade,
  product_id uuid not null references public.products (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (uid, product_id)
);

alter table public.favorites enable row level security;

drop policy if exists "favorites_owner_all" on public.favorites;
create policy "favorites_owner_all" on public.favorites
  for all using (auth.uid() = uid) with check (auth.uid() = uid);

alter publication supabase_realtime add table public.favorites;
