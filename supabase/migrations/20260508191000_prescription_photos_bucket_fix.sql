-- 修復：建立 prescription-photos bucket（解決 App 上傳 404 Bucket not found）
-- 在 Supabase Dashboard → SQL Editor 執行本檔即可。

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'prescription-photos',
  'prescription-photos',
  false,
  52428800,
  array['image/jpeg', 'image/jpg', 'image/png', 'image/webp']::text[]
)
on conflict (id) do update set
  name = excluded.name,
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- 長輩端：只能讀寫自己資料夾 {auth.uid()}/...
drop policy if exists prescription_photos_select_own on storage.objects;
create policy prescription_photos_select_own
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'prescription-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists prescription_photos_insert_own on storage.objects;
create policy prescription_photos_insert_own
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'prescription-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists prescription_photos_update_own on storage.objects;
create policy prescription_photos_update_own
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'prescription-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists prescription_photos_delete_own on storage.objects;
create policy prescription_photos_delete_own
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'prescription-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
