-- إضافة حقل الفرع (شغّله مرة واحدة في Supabase > SQL Editor ثم Run)
-- آمن لو شغّلته أكثر من مرة، ولا يغيّر أي بيانات موجودة.
alter table public.maintenance_jobs add column if not exists branch text;
create index if not exists mj_branch_idx on public.maintenance_jobs (branch);

-- اختياري: تحديد فرع لكل السجلات الموجودة حالياً (غيّر الاسم ثم أزل علامتي التعليق)
/*
update public.maintenance_jobs set branch = 'الفرع الرئيسي' where branch is null;
*/
