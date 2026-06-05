-- 社區活動：志工發布、長輩在日曆上瀏覽（可附活動照片）
-- 在 Supabase Dashboard → SQL Editor 整段貼上、按 Run 即可（可重複執行）。

-- =========================================================================
-- 1) 資料表
-- =========================================================================
create table if not exists public.community_events (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  title text not null,
  description text,
  event_date date not null,
  start_time text,
  location text,
  photo_url text,
  volunteer_id uuid references auth.users (id) on delete set null
);

comment on table public.community_events is
  '社區活動：event_date 為活動當天（日曆顯示用）；photo_url 為公開 bucket 的照片網址';

create index if not exists community_events_event_date_idx
  on public.community_events (event_date);

alter table public.community_events enable row level security;

-- 已登入者皆可讀
drop policy if exists community_events_select_authenticated on public.community_events;
create policy community_events_select_authenticated
  on public.community_events
  for select
  to authenticated
  using (true);

-- 志工可新增
drop policy if exists community_events_insert_volunteer on public.community_events;
create policy community_events_insert_volunteer
  on public.community_events
  for insert
  to authenticated
  with check (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'volunteer'
    )
  );

-- 志工可更新
drop policy if exists community_events_update_volunteer on public.community_events;
create policy community_events_update_volunteer
  on public.community_events
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

-- 志工可刪除
drop policy if exists community_events_delete_volunteer on public.community_events;
create policy community_events_delete_volunteer
  on public.community_events
  for delete
  to authenticated
  using (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'volunteer'
    )
  );

-- =========================================================================
-- 2) Realtime
-- =========================================================================
do $$
begin
  alter publication supabase_realtime add table public.community_events;
exception
  when duplicate_object then null;
end $$;

alter table public.community_events replica identity full;

grant select on table public.community_events to authenticated;
grant insert, update, delete on table public.community_events to authenticated;

-- =========================================================================
-- 3) Storage bucket（公開：活動海報長輩端直接看 public URL）
-- =========================================================================
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'community-event-photos',
  'community-event-photos',
  true,
  52428800,
  array['image/jpeg', 'image/jpg', 'image/png', 'image/webp']::text[]
)
on conflict (id) do update set
  name = excluded.name,
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- 公開讀取（任何人都能看活動照片）
drop policy if exists community_event_photos_select_public on storage.objects;
create policy community_event_photos_select_public
  on storage.objects
  for select
  to public
  using (bucket_id = 'community-event-photos');

-- 志工可上傳到自己的資料夾 {auth.uid()}/...
drop policy if exists community_event_photos_insert_volunteer on storage.objects;
create policy community_event_photos_insert_volunteer
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'community-event-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
    and exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'volunteer'
    )
  );

drop policy if exists community_event_photos_update_volunteer on storage.objects;
create policy community_event_photos_update_volunteer
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'community-event-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists community_event_photos_delete_volunteer on storage.objects;
create policy community_event_photos_delete_volunteer
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'community-event-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- =========================================================================
-- 4) 示範活動（固定 UUID，志工端可編輯／刪除；日期放在 2026/06，方便看綠點）
-- =========================================================================
insert into public.community_events (
  id, title, description, event_date, start_time, location, photo_url, volunteer_id
) values
  (
    'c1000001-0000-4000-8000-000000000001',
    '社區共餐日',
    '免費供餐，歡迎左鄰右舍一起來吃飯聊天，記得帶環保餐具喔！',
    '2026-06-08',
    '上午 11:30',
    '明德社區活動中心',
    'https://images.unsplash.com/photo-1543353071-873f17a7a088?w=800',
    null
  ),
  (
    'c1000001-0000-4000-8000-000000000002',
    '銀髮健康講座：血壓控制',
    '由社區護理師講解居家量血壓技巧與飲食注意事項，現場備有點心。',
    '2026-06-12',
    '下午 2:00',
    '衛生所二樓會議室',
    'https://images.unsplash.com/photo-1576091160550-2173dba999ef?w=800',
    null
  ),
  (
    'c1000001-0000-4000-8000-000000000003',
    '客語歌謠歡唱班',
    '一起唱客家老歌，懷念又開心，初學者也歡迎參加。',
    '2026-06-15',
    '上午 9:30',
    '社區活動中心大廳',
    null,
    null
  ),
  (
    'c1000001-0000-4000-8000-000000000004',
    '行動篩檢車到站',
    '提供血糖、血壓、視力免費檢查，記得攜帶健保卡。',
    '2026-06-20',
    '上午 8:30 - 11:00',
    '社區廣場',
    'https://images.unsplash.com/photo-1631815588090-d4bfec5b1ccb?w=800',
    null
  )
on conflict (id) do update set
  title = excluded.title,
  description = excluded.description,
  event_date = excluded.event_date,
  start_time = excluded.start_time,
  location = excluded.location,
  photo_url = excluded.photo_url;
