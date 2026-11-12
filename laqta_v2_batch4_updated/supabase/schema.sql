-- ============================================================================
-- سكيما لَقطة (Laqta) على Supabase Postgres — بديل كامل لمجموعات Firestore.
-- شغّل هذا الملف مرة وحدة من: Supabase Dashboard → SQL Editor → New query
-- (أو عبر: supabase db push إذا عم تستخدم Supabase CLI محليًا)
-- ============================================================================

create extension if not exists "pgcrypto"; -- عشان gen_random_uuid()

-- ---------------------------------------------------------------------------
-- profiles — تقابل مجموعة `users` بـ Firestore. صف واحد لكل مستخدم بـ
-- auth.users، يتربط تلقائيًا عن طريق trigger بالأسفل.
-- ---------------------------------------------------------------------------
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  name text,
  email text,
  role text not null default 'buyer',           -- 'buyer' | 'seller' (تسمية تاريخية فقط، كل حساب يقدر يبيع ويشتري)
  phone text,
  phone_verified boolean not null default false,
  location text,
  is_admin boolean not null default false,
  created_at timestamptz not null default now()
);

-- ينشئ صف profile تلقائيًا لأي مستخدم جديد بـ auth.users، آخذ الاسم/الهاتف/
-- الموقع من user_metadata اللي منبعتها وقت signUp() من التطبيق.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, name, email, role, phone, location)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'name', ''),
    new.email,
    coalesce(new.raw_user_meta_data ->> 'role', 'buyer'),
    new.raw_user_meta_data ->> 'phone',
    new.raw_user_meta_data ->> 'location'
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- يحدّث profiles.phone/phone_verified تلقائيًا لما phone يتوثق بـ auth.users
create or replace function public.handle_user_phone_update()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if new.phone is distinct from old.phone or new.phone_confirmed_at is distinct from old.phone_confirmed_at then
    update public.profiles
    set phone = new.phone,
        phone_verified = (new.phone_confirmed_at is not null)
    where id = new.id;
  end if;
  return new;
end;
$$;

create trigger on_auth_user_phone_updated
  after update on auth.users
  for each row execute procedure public.handle_user_phone_update();

-- ---------------------------------------------------------------------------
-- products — تقابل مجموعة `products`
-- ---------------------------------------------------------------------------
create table public.products (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  price numeric(12, 2) not null,
  cat text not null,
  cond text not null,
  "desc" text not null default '',
  seller_uid uuid not null references auth.users (id),
  seller_name text not null,
  contact_phone text not null,
  contact_address text not null default '',
  rating numeric(3, 2) not null default 0,
  status text not null default 'pending',        -- pending | approved | rejected
  image_url text,                                 -- الصورة الرئيسية (توافق قديم)
  image_urls text[] not null default '{}',        -- كل صور المنتج بالترتيب
  product_date text,
  created_at timestamptz not null default now()
);

create index products_status_idx on public.products (status, created_at desc);
create index products_seller_idx on public.products (seller_uid, created_at desc);

-- ---------------------------------------------------------------------------
-- conversations / messages — تقابل conversations + الفرعية messages
-- ---------------------------------------------------------------------------
create table public.conversations (
  id uuid primary key default gen_random_uuid(),
  product_id uuid references public.products (id),
  product_title text,
  participants uuid[] not null,
  names jsonb not null default '{}'::jsonb,
  last_message text default '',
  last_message_at timestamptz not null default now()
);

create index conversations_participants_idx on public.conversations using gin (participants);

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  sender_uid uuid not null references auth.users (id),
  text text not null,
  sent_at timestamptz not null default now()
);

create index messages_conversation_idx on public.messages (conversation_id, sent_at);

-- ---------------------------------------------------------------------------
-- favorites — منتجات مفضّلة لكل مستخدم، تبقى محفوظة بين الجلسات والأجهزة.
-- ---------------------------------------------------------------------------
create table public.favorites (
  uid uuid not null references auth.users (id) on delete cascade,
  product_id uuid not null references public.products (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (uid, product_id)
);

-- ---------------------------------------------------------------------------
-- دالة مساعدة: هل المستخدم الحالي أدمن؟ (بديل request.auth.token.admin)
-- ---------------------------------------------------------------------------
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer set search_path = public
as $$
  select coalesce((select is_admin from public.profiles where id = auth.uid()), false);
$$;

-- ============================================================================
-- Row Level Security — نفس منطق firestore.rules تقريبًا
-- ============================================================================
alter table public.profiles enable row level security;
alter table public.products enable row level security;
alter table public.conversations enable row level security;
alter table public.messages enable row level security;
alter table public.favorites enable row level security;

-- profiles: أي مستخدم مسجّل دخول يقدر يقرأ (بحاجتها أسماء البائعين مثلًا)،
-- بس يعدّل بياناته هو فقط.
create policy "profiles_select_authenticated" on public.profiles
  for select using (auth.role() = 'authenticated');
create policy "profiles_update_own" on public.profiles
  for update using (auth.uid() = id);

-- products: المعتمدة تظهر للجميع، وغير المعتمدة (قيد المراجعة/مرفوضة) ما
-- تظهر إلا لصاحبها أو للأدمن. الإضافة/التعديل/الحذف لصاحب المنتج أو الأدمن،
-- مع حماية إضافية (Trigger أدناه) تمنع أي مستخدم غير مشرف من تغيير حالة
-- الاعتماد (status) بنفسه.
create policy "products_select_visible" on public.products
  for select using (
    status = 'approved' or auth.uid() = seller_uid or public.is_admin()
  );
create policy "products_insert_own" on public.products
  for insert with check (auth.uid() = seller_uid and status = 'pending');
create policy "products_update_own_or_admin" on public.products
  for update using (auth.uid() = seller_uid or public.is_admin());
create policy "products_delete_own_or_admin" on public.products
  for delete using (auth.uid() = seller_uid or public.is_admin());

-- يمنع أي مستخدم غير مشرف من تعديل حالة اعتماد منتجه بنفسه (اعتماد ذاتي)،
-- بينما يسمح له بإرجاع منتجه لـ "قيد المراجعة" بنفسه (مطلوب عند التعديل).
create or replace function public.guard_product_status()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if new.status is distinct from old.status
     and not public.is_admin()
     and new.status <> 'pending' then
    new.status := old.status;
  end if;
  return new;
end;
$$;

create trigger products_status_guard
  before update on public.products
  for each row execute procedure public.guard_product_status();

-- conversations: بس طرفا المحادثة.
create policy "conversations_select_participant" on public.conversations
  for select using (auth.uid() = any (participants));
create policy "conversations_insert_participant" on public.conversations
  for insert with check (auth.uid() = any (participants));
create policy "conversations_update_participant" on public.conversations
  for update using (auth.uid() = any (participants));

-- messages: بس طرفا المحادثة اللي تتبعها الرسالة.
create policy "messages_select_participant" on public.messages
  for select using (
    exists (
      select 1 from public.conversations c
      where c.id = conversation_id and auth.uid() = any (c.participants)
    )
  );
create policy "messages_insert_participant" on public.messages
  for insert with check (
    sender_uid = auth.uid() and exists (
      select 1 from public.conversations c
      where c.id = conversation_id and auth.uid() = any (c.participants)
    )
  );

-- favorites: كل مستخدم يدير مفضّلته فقط.
create policy "favorites_owner_all" on public.favorites
  for all using (auth.uid() = uid) with check (auth.uid() = uid);

-- ============================================================================
-- تفعيل التحديثات اللحظية (Realtime) — بديل .snapshots() بفايرستور
-- ============================================================================
alter publication supabase_realtime add table public.products;
alter publication supabase_realtime add table public.conversations;
alter publication supabase_realtime add table public.messages;
alter publication supabase_realtime add table public.favorites;

-- ============================================================================
-- Storage policies لـ bucket "product-images" — لازم تنشئ الـ bucket أول
-- (Public bucket مفعّل) من Dashboard → Storage → New bucket، وبعدها شغّل هاد.
-- "Public bucket" لحاله بيسمح بالقراءة بس بدون توثيق — الرفع والحذف لازم
-- لهم RLS policy صريح بالضبط متل باقي الجداول.
-- كل بائع بيرفع تحت مجلد باسم uid تبعه (product-images/<uid>/xxx.jpg)
-- — نفس التركيب اللي بيستخدمه storage_service.dart — فمنقيّد كل مستخدم
-- إنه يرفع/يحذف بس تحت مجلده هو.
-- ============================================================================
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

-- ============================================================================
-- لجعل حسابك أدمن (بديل setAdmin.js) — شغّل بعد ما تنشئ حسابك بالتطبيق:
--   update public.profiles set is_admin = true where email = 'you@example.com';
-- ما في داعي تسجّل خروج/دخول من جديد — is_admin تُفحص من الجدول مباشرة
-- بكل استدعاء لـ Edge Function، مو من الـ JWT.
-- ============================================================================
