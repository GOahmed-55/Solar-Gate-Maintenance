-- صلاحيات المستخدمين (شغّله بعد schema.sql)
-- انسخ الملف كله والصقه في Supabase > SQL Editor ثم Run
-- الفكرة: التكلفة تتنقل لجدول منفصل محمي، فلا يقدر الموظف يقرأها أو يكتبها حتى لو فتح الـ API مباشرة.

-- 1) جدول الصلاحيات
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  role text not null default 'staff' check (role in ('admin','staff')),
  created_at timestamptz default now()
);

create or replace function public.is_admin() returns boolean
language sql security definer stable set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')
$$;

-- أي مستخدم جديد يتسجل في Supabase يصير "موظف" تلقائياً (بدون تكلفة)
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, email, role) values (new.id, new.email, 'staff')
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- المستخدمون الموجودون حالياً يصيرون "مدير" (حتى لا يُقفل عليك). غيّر من تريده موظفاً من تبويب "المستخدمون" في النظام.
insert into public.profiles (id, email, role)
select id, email, 'admin' from auth.users
on conflict (id) do nothing;

alter table public.profiles enable row level security;
drop policy if exists "read own or admin" on public.profiles;
drop policy if exists "admin update" on public.profiles;
create policy "read own or admin" on public.profiles for select to authenticated
  using (id = auth.uid() or public.is_admin());
create policy "admin update" on public.profiles for update to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- 2) جدول التكلفة (للمدير فقط)
create table if not exists public.job_costs (
  job_id bigint primary key references public.maintenance_jobs(id) on delete cascade,
  maintenance_cost numeric(12,2) not null default 0,
  updated_at timestamptz default now()
);

-- نقل التكاليف الموجودة من الجدول الرئيسي ثم حذف العمود منه
do $$
begin
  if exists (select 1 from information_schema.columns
             where table_schema = 'public' and table_name = 'maintenance_jobs' and column_name = 'maintenance_cost') then
    insert into public.job_costs (job_id, maintenance_cost)
      select id, maintenance_cost from public.maintenance_jobs where coalesce(maintenance_cost, 0) <> 0
      on conflict (job_id) do nothing;
    alter table public.maintenance_jobs drop column maintenance_cost;
  end if;
end $$;

alter table public.job_costs enable row level security;
drop policy if exists "admin all" on public.job_costs;
create policy "admin all" on public.job_costs for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- 3) الحذف للمدير فقط (الموظف يسجّل ويعدّل لكن لا يحذف)
drop policy if exists "auth delete" on public.maintenance_jobs;
drop policy if exists "admin delete" on public.maintenance_jobs;
create policy "admin delete" on public.maintenance_jobs for delete to authenticated
  using (public.is_admin());

-- لتغيير صلاحية مستخدم يدوياً (بديل عن تبويب المستخدمين):
--   update public.profiles set role = 'staff' where email = 'user@example.com';
--   update public.profiles set role = 'admin' where email = 'user@example.com';
