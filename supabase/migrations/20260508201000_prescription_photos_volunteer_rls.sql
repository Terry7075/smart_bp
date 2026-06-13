-- 讓志工可讀 prescription-photos bucket（代領時核對長輩原始藥單照片）
-- 長輩自己的 SELECT / INSERT / UPDATE / DELETE 政策不受影響。

drop policy if exists prescription_photos_select_volunteer on storage.objects;
create policy prescription_photos_select_volunteer
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'prescription-photos'
    and exists (
      select 1
      from public.profiles p
      where p.id = auth.uid()
        and p.role = 'volunteer'
    )
  );
