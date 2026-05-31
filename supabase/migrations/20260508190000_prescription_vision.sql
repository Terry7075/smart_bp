-- 藥單 Vision（Gemini）與 prescription-photos Storage

alter table public.prescriptions
  add column if not exists photo_storage_path text;

alter table public.prescriptions
  add column if not exists vision_status text not null default 'none';

alter table public.prescriptions
  add column if not exists medications_detail jsonb not null default '[]'::jsonb;

comment on column public.prescriptions.photo_storage_path is
  'Supabase Storage object path（bucket: prescription-photos）';

comment on column public.prescriptions.vision_status is
  'none | processing | completed | failed';

alter table public.prescriptions
  drop constraint if exists prescriptions_vision_status_check;

alter table public.prescriptions
  add constraint prescriptions_vision_status_check
  check (
    vision_status = any (
      array[
        'none'::text,
        'processing'::text,
        'completed'::text,
        'failed'::text
      ]
    )
  );

-- Storage bucket（私人：僅本人上傳／讀取自己的路徑）
insert into storage.buckets (id, name, public)
values ('prescription-photos', 'prescription-photos', false)
on conflict (id) do nothing;

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
