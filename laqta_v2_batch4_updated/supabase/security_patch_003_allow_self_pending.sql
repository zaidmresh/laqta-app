-- شغّل هذا مرة واحدة بـ SQL Editor عشان تفعيل ميزة "تعديل الإعلان" الجديدة.
-- يسمح لصاحب المنتج إنه يرجّع حالة منتجه لـ "قيد المراجعة" بنفسه (لازم هذا
-- لما يعدّل إعلان معتمد أصلًا)، بينما يبقى ممنوع عليه إنه يعتمد أو يرفض
-- منتجه بنفسه مباشرة — هذا يبقى صلاحية الأدمن حصرًا.

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
