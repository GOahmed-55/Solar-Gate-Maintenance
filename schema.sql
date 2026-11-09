-- نظام الصيانة (الإصدار 2)
-- انسخ الملف كله والصقه في Supabase > SQL Editor ثم اضغط Run
-- الجدول القديم (repairs) لا يتم حذفه ولا تعديله.

create sequence if not exists public.maintenance_code_seq;

create table if not exists public.maintenance_jobs (
  id bigint generated always as identity primary key,
  code text unique,                                   -- الكود (تسلسلي تلقائي)
  branch text,                                        -- الفرع
  customer_name text,                                 -- اسم العميل
  company_name text,                                  -- اسم الشركة
  device_type text,                                   -- نوع الجهاز
  brand text,                                         -- البراند
  color text,                                         -- لون الجهاز
  capacity text,                                      -- قدرة الجهاز
  serial_number text,                                 -- السريال نمبر
  status text not null default 'تم الاستلام',         -- الحالة
  fault_reason text,                                  -- العطل / سبب العطل
  engineer text,                                      -- مهندس الصيانة المسئول
  required_components text,                           -- المكونات المطلوبة للصيانة
  received_date date not null default current_date,   -- تاريخ الاستلام
  delivery_date date,                                 -- تاريخ التسليم للعميل
  maintenance_cost numeric(12,2) not null default 0,  -- قيمة الصيانة
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  created_by uuid default auth.uid()
);

create index if not exists mj_received_idx on public.maintenance_jobs (received_date);
create index if not exists mj_delivery_idx on public.maintenance_jobs (delivery_date);
create index if not exists mj_branch_idx on public.maintenance_jobs (branch);
create index if not exists mj_status_idx on public.maintenance_jobs (status);
create index if not exists mj_serial_idx on public.maintenance_jobs (serial_number);

-- سجل تغيّر الحالات (يتعبّأ تلقائياً)
create table if not exists public.job_status_log (
  id bigint generated always as identity primary key,
  job_id bigint not null references public.maintenance_jobs(id) on delete cascade,
  status text not null,
  changed_at timestamptz default now(),
  changed_by uuid default auth.uid()
);
create index if not exists jsl_job_idx on public.job_status_log (job_id);

-- توليد الكود تلقائياً ومنع تعديله + تعبئة تاريخ التسليم عند التسليم
create or replace function public.jobs_before_write() returns trigger
language plpgsql as $$
begin
  if tg_op = 'INSERT' then
    new.code := 'SG-' || lpad(nextval('public.maintenance_code_seq')::text, 5, '0');
  else
    new.code := old.code;
    new.updated_at := now();
  end if;
  if new.status = 'تم التسليم' and new.delivery_date is null then
    new.delivery_date := current_date;
  end if;
  return new;
end $$;

create or replace function public.jobs_log_status() returns trigger
language plpgsql as $$
begin
  if tg_op = 'INSERT' or new.status is distinct from old.status then
    insert into public.job_status_log (job_id, status) values (new.id, new.status);
  end if;
  return null;
end $$;

drop trigger if exists trg_jobs_before on public.maintenance_jobs;
create trigger trg_jobs_before before insert or update on public.maintenance_jobs
  for each row execute function public.jobs_before_write();

drop trigger if exists trg_jobs_log on public.maintenance_jobs;
create trigger trg_jobs_log after insert or update on public.maintenance_jobs
  for each row execute function public.jobs_log_status();

-- الحماية: الوصول فقط للمستخدمين المسجلين دخول
alter table public.maintenance_jobs enable row level security;
alter table public.job_status_log enable row level security;

drop policy if exists "auth select" on public.maintenance_jobs;
drop policy if exists "auth insert" on public.maintenance_jobs;
drop policy if exists "auth update" on public.maintenance_jobs;
drop policy if exists "auth delete" on public.maintenance_jobs;
create policy "auth select" on public.maintenance_jobs for select to authenticated using (true);
create policy "auth insert" on public.maintenance_jobs for insert to authenticated with check (true);
create policy "auth update" on public.maintenance_jobs for update to authenticated using (true) with check (true);
create policy "auth delete" on public.maintenance_jobs for delete to authenticated using (true);

drop policy if exists "auth select" on public.job_status_log;
drop policy if exists "auth insert" on public.job_status_log;
create policy "auth select" on public.job_status_log for select to authenticated using (true);
create policy "auth insert" on public.job_status_log for insert to authenticated with check (true);

-- ====================================================================
-- اختياري: نقل بيانات الجدول القديم (repairs) إلى الجدول الجديد
-- شغّله مرة واحدة فقط، وبعد إزالة علامات التعليق (/* و */)
-- ====================================================================
/*
insert into public.maintenance_jobs
  (company_name, brand, serial_number, fault_reason, required_components,
   received_date, delivery_date, maintenance_cost, status)
select company_name, inverter_type, serial_number, fault_reason, components,
       received_date, delivery_date,
       coalesce(nullif(total,0), maintenance_cost, 0),
       case when status = 'تم التسليم' then 'تم التسليم' else 'تم الاستلام' end
from public.repairs
order by received_date, id;
*/
