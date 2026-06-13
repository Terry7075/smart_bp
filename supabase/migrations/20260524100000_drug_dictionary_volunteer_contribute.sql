-- 志工可新增藥典：補齊 drug_dictionary 欄位、開放志工 insert、允許志工上傳藥品照片
-- 在 Supabase Dashboard → SQL Editor 整段貼上、按 Run 即可（可重複執行）。

-- =========================================================================
-- 1) 確保資料表與欄位齊全（冪等；不破壞既有資料）
-- =========================================================================
create table if not exists public.drug_dictionary (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now()
);

alter table public.drug_dictionary
  add column if not exists name_zh text;
alter table public.drug_dictionary
  add column if not exists name_en text;
alter table public.drug_dictionary
  add column if not exists generic_name text;
alter table public.drug_dictionary
  add column if not exists manufacturer text;
alter table public.drug_dictionary
  add column if not exists image_url text;
alter table public.drug_dictionary
  add column if not exists created_by uuid references auth.users (id) on delete set null;

comment on table public.drug_dictionary is
  '社區藥典：name_zh／name_en／generic_name／manufacturer + image_url（drug-images bucket）。志工可逐步新增。';

create index if not exists drug_dictionary_name_zh_idx
  on public.drug_dictionary (name_zh);
create index if not exists drug_dictionary_name_en_idx
  on public.drug_dictionary (name_en);

-- =========================================================================
-- 2) RLS：所有登入者可讀；志工可新增
-- =========================================================================
alter table public.drug_dictionary enable row level security;

drop policy if exists drug_dictionary_select_authenticated on public.drug_dictionary;
create policy drug_dictionary_select_authenticated
  on public.drug_dictionary
  for select
  to authenticated
  using (true);

drop policy if exists drug_dictionary_insert_volunteer on public.drug_dictionary;
create policy drug_dictionary_insert_volunteer
  on public.drug_dictionary
  for insert
  to authenticated
  with check (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'volunteer'
    )
  );

-- 志工可更新／刪除自己新增的藥典列（修正錯字、換圖）
drop policy if exists drug_dictionary_update_volunteer on public.drug_dictionary;
create policy drug_dictionary_update_volunteer
  on public.drug_dictionary
  for update
  to authenticated
  using (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'volunteer'
    )
  )
  with check (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'volunteer'
    )
  );

grant select on table public.drug_dictionary to authenticated;
grant insert, update on table public.drug_dictionary to authenticated;

-- =========================================================================
-- 3) Storage：志工可上傳藥品照片到 drug-images（私有 bucket）
-- =========================================================================
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'drug-images',
  'drug-images',
  false,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- 讀取維持：所有登入者可讀（打卡頁看圖認藥）
drop policy if exists drug_images_select_authenticated on storage.objects;
create policy drug_images_select_authenticated
  on storage.objects
  for select
  to authenticated
  using (bucket_id = 'drug-images');

-- 志工可上傳到自己的資料夾 {auth.uid()}/...
drop policy if exists drug_images_insert_volunteer on storage.objects;
create policy drug_images_insert_volunteer
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'drug-images'
    and (storage.foldername(name))[1] = auth.uid()::text
    and exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'volunteer'
    )
  );

drop policy if exists drug_images_update_volunteer on storage.objects;
create policy drug_images_update_volunteer
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'drug-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

notify pgrst, 'reload schema';
