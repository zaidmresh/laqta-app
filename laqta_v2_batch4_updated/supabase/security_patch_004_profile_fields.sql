-- شغّل هذا مرة واحدة بـ SQL Editor عشان تفعيل حقلي الهاتف والموقع
-- بالتسجيل الجديد (البند 5 و7 بالطلب).

alter table public.profiles add column if not exists location text;

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
