-- 藥典圖片 bucket：已登入使用者可讀（打卡頁「看圖認藥」、OCR 確認頁）
-- image_url 若為 `drug-images/xxx.jpg` 或純檔名，App 以 signed URL 讀取。

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'drug-images',
  'drug-images',
  false,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists drug_images_select_authenticated on storage.objects;
create policy drug_images_select_authenticated
  on storage.objects
  for select
  to authenticated
  using (bucket_id = 'drug-images');
