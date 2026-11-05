-- نظام الصيانة: انسخ الملف كله والصقه في Supabase > SQL Editor ثم اضغط Run

create table if not exists public.repairs (
  id bigint generated always as identity primary key,
  code text,                                   -- الكود
  company_name text not null,                  -- اسم الشركة
  received_by text,                            -- الاستلام
  description text,                            -- البيان
  inverter_type text,                          -- نوع الانفرتر
  components text,                             -- مكونات
  fault_reason text,                           -- سبب العطل
  serial_number text,                          -- السريال نمبر
  report_no text,                              -- رقم تقرير الصيانة
  received_date date not null default current_date,  -- تاريخ الوارد
  maintenance_cost numeric(12,2) default 0,    -- قيمة الصيانة
  total numeric(12,2) default 0,               -- الاجمالي
  status text default 'تم الاستلام',           -- الحالة
  delivery_date date,                          -- تاريخ التسليم
  created_at timestamptz default now(),
  created_by uuid default auth.uid()
);

create index if not exists repairs_received_date_idx on public.repairs (received_date);
create index if not exists repairs_company_idx on public.repairs (company_name);
create index if not exists repairs_serial_idx on public.repairs (serial_number);

-- الحماية: الوصول فقط للمستخدمين المسجلين دخول
alter table public.repairs enable row level security;

drop policy if exists "auth select" on public.repairs;
drop policy if exists "auth insert" on public.repairs;
drop policy if exists "auth update" on public.repairs;
drop policy if exists "auth delete" on public.repairs;

create policy "auth select" on public.repairs for select to authenticated using (true);
create policy "auth insert" on public.repairs for insert to authenticated with check (true);
create policy "auth update" on public.repairs for update to authenticated using (true) with check (true);
create policy "auth delete" on public.repairs for delete to authenticated using (true);
