-- =============================================================================
-- 明德 e 達人 — 小幫手對話歷史（assistant_chat_sessions）
-- =============================================================================
--
-- 【在 Supabase 怎麼執行】
-- 1. 打開 https://supabase.com → 你的專案
-- 2. 左側 SQL Editor → New query
-- 3. 整份貼上此檔 → Run
-- 4. 確認 Table Editor 出現 `assistant_chat_sessions`
--
-- 【App 端】執行 SQL 後，小幫手會自動把過往對話寫入／讀取雲端（需已登入）。
-- 每筆對話的訊息存在 `messages`（JSON 陣列），與 Flutter 序列化格式一致。
--
-- =============================================================================

-- 1) 資料表
create table if not exists public.assistant_chat_sessions (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null default '對話紀錄',
  messages jsonb not null default '[]'::jsonb,
  started_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.assistant_chat_sessions is
  '長輩小幫手對話場次；messages 為 AssistantMessage[] JSON';

create index if not exists assistant_chat_sessions_user_updated_idx
  on public.assistant_chat_sessions (user_id, updated_at desc);

-- 2) 自動更新 updated_at
create or replace function public.set_assistant_chat_sessions_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists assistant_chat_sessions_set_updated_at
  on public.assistant_chat_sessions;

create trigger assistant_chat_sessions_set_updated_at
before update on public.assistant_chat_sessions
for each row execute function public.set_assistant_chat_sessions_updated_at();

-- 3) RLS：僅本人可讀寫自己的對話（志工不可讀長輩聊天內容）
alter table public.assistant_chat_sessions enable row level security;

drop policy if exists "assistant_sessions_select_own" on public.assistant_chat_sessions;
create policy "assistant_sessions_select_own"
on public.assistant_chat_sessions for select
using (auth.uid() = user_id);

drop policy if exists "assistant_sessions_insert_own" on public.assistant_chat_sessions;
create policy "assistant_sessions_insert_own"
on public.assistant_chat_sessions for insert
with check (auth.uid() = user_id);

drop policy if exists "assistant_sessions_update_own" on public.assistant_chat_sessions;
create policy "assistant_sessions_update_own"
on public.assistant_chat_sessions for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "assistant_sessions_delete_own" on public.assistant_chat_sessions;
create policy "assistant_sessions_delete_own"
on public.assistant_chat_sessions for delete
using (auth.uid() = user_id);

-- 4) （選用）只保留最近 50 場 — 可在 App 端 trim；若要 DB 定期清理可再加 cron。
