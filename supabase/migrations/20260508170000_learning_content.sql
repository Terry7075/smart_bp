-- 社區學習 / 客語資訊動態內容（志工發布、長輩與志工可讀）

create table if not exists public.learning_content (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  title text not null,
  description text,
  category text not null,
  content_type text not null,
  url text not null,
  volunteer_id uuid references auth.users (id) on delete set null
);

comment on table public.learning_content is
  '社區學習與客語資訊：category 見 App 常數；content_type 為 video 或 article';

alter table public.learning_content
  drop constraint if exists learning_content_category_check;

alter table public.learning_content
  add constraint learning_content_category_check
  check (
    category = any (
      array[
        'anti_fraud'::text,
        'health'::text,
        'hakka_vocab'::text,
        'hakka_song'::text,
        'hakka_story'::text
      ]
    )
  );

alter table public.learning_content
  drop constraint if exists learning_content_type_check;

alter table public.learning_content
  add constraint learning_content_type_check
  check (content_type = any (array['video'::text, 'article'::text]));

create index if not exists learning_content_category_created_idx
  on public.learning_content (category, created_at desc);

alter table public.learning_content enable row level security;

-- 已登入使用者皆可讀取
drop policy if exists learning_content_select_authenticated on public.learning_content;
create policy learning_content_select_authenticated
  on public.learning_content
  for select
  to authenticated
  using (true);

-- 志工可新增
drop policy if exists learning_content_insert_volunteer on public.learning_content;
create policy learning_content_insert_volunteer
  on public.learning_content
  for insert
  to authenticated
  with check (
    exists (
      select 1
      from public.profiles p
      where p.id = auth.uid()
        and p.role = 'volunteer'
    )
  );

-- 志工可更新／刪除（內容管理）
drop policy if exists learning_content_update_volunteer on public.learning_content;
create policy learning_content_update_volunteer
  on public.learning_content
  for update
  to authenticated
  using (
    exists (
      select 1
      from public.profiles p
      where p.id = auth.uid()
        and p.role = 'volunteer'
    )
  )
  with check (
    exists (
      select 1
      from public.profiles p
      where p.id = auth.uid()
        and p.role = 'volunteer'
    )
  );

drop policy if exists learning_content_delete_volunteer on public.learning_content;
create policy learning_content_delete_volunteer
  on public.learning_content
  for delete
  to authenticated
  using (
    exists (
      select 1
      from public.profiles p
      where p.id = auth.uid()
        and p.role = 'volunteer'
    )
  );

-- 示範資料（固定 UUID，志工端可編輯／刪除後重新發布）
insert into public.learning_content (
  id, title, description, category, content_type, url, volunteer_id
) values
  (
    'a1000001-0000-4000-8000-000000000001',
    '假檢警真詐騙！千萬別去 ATM',
    '認識假檢警話術，保護自己的存款安全。',
    'anti_fraud',
    'video',
    'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
    null
  ),
  (
    'a1000001-0000-4000-8000-000000000002',
    '常見投資詐騙手法解析',
    '高報酬、低風險都是警訊，請多與家人討論。',
    'anti_fraud',
    'article',
    'https://www.cib.gov.tw/',
    null
  ),
  (
    'a1000001-0000-4000-8000-000000000003',
    '如何辨識詐騙簡訊與假連結',
    '不要點陌生連結，有疑慮請撥 165 反詐騙專線。',
    'anti_fraud',
    'article',
    'https://165.npa.gov.tw/',
    null
  ),
  (
    'a1000002-0000-4000-8000-000000000001',
    '銀髮族血壓控制小撇步',
    '定時量血壓、少鹽飲食、規律服藥。',
    'health',
    'video',
    'https://www.youtube.com/watch?v=ysz5S6PUM-U',
    null
  ),
  (
    'a1000002-0000-4000-8000-000000000002',
    '糖尿病飲食與運動',
    '均衡飲食搭配散步，血糖更穩定。',
    'health',
    'video',
    'https://www.youtube.com/watch?v=jNQXAC9IVRw',
    null
  ),
  (
    'a1000002-0000-4000-8000-000000000003',
    '衛福部健康促進專區',
    '更多免費健康衛教文章與資源。',
    'health',
    'article',
    'https://www.hpa.gov.tw/',
    null
  ),
  (
    'b1000001-0000-4000-8000-000000000001',
    '基礎客語問候：食飽吂（吃飽沒）',
    '學會最親切的客語打招呼方式。',
    'hakka_vocab',
    'video',
    'https://www.youtube.com/watch?v=ScMzIvxBSi4',
    null
  ),
  (
    'b1000001-0000-4000-8000-000000000002',
    '客語數字 1 到 10 認讀',
    '跟著影片一起念，每天練一點點。',
    'hakka_vocab',
    'video',
    'https://www.youtube.com/watch?v=kJQP7kiw5Fk',
    null
  ),
  (
    'b1000002-0000-4000-8000-000000000001',
    '客家本色（精選片段）',
    '感受客家文化的熱情與精神。',
    'hakka_song',
    'video',
    'https://www.youtube.com/watch?v=9bZkp7q19f0',
    null
  ),
  (
    'b1000002-0000-4000-8000-000000000002',
    '傳統山歌欣賞',
    '悠揚山歌，傳承客家庄園的聲音。',
    'hakka_song',
    'video',
    'https://www.youtube.com/watch?v=RgKAFK5djSk',
    null
  ),
  (
    'b1000003-0000-4000-8000-000000000001',
    '苗栗在地故事：山城歲月',
    '認識家鄉的人事物與歷史記憶。',
    'hakka_story',
    'video',
    'https://www.youtube.com/watch?v=OPf0YbXqDm0',
    null
  ),
  (
    'b1000003-0000-4000-8000-000000000002',
    '客庄生活文化介紹',
    '從節慶與飲食認識客家族群。',
    'hakka_story',
    'article',
    'https://www.hakka.gov.tw/',
    null
  )
on conflict (id) do update set
  title = excluded.title,
  description = excluded.description,
  category = excluded.category,
  content_type = excluded.content_type,
  url = excluded.url;
