-- 修復 profiles RLS 無限遞迴（42P17 infinite recursion detected in policy）
--
-- 根因：profiles_select_admin 等政策在 profiles 表上以
--   exists (select 1 from public.profiles p where p.id = auth.uid() ...)
-- 判斷角色，每次 SELECT profiles 又觸發同一政策 → 無限遞迴。
--
-- 解法：以 SECURITY DEFINER 函式讀取當前使用者 role（繞過 RLS），
-- 再建立「讀自己」+「志工/管理讀全部」等簡潔政策。

create or replace function public.current_user_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select p.role::text from public.profiles p where p.id = auth.uid()),
    'elder'
  );
$$;

create or replace function public.is_staff_user()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (
      select p.role::text in ('volunteer', 'admin')
      from public.profiles p
      where p.id = auth.uid()
    ),
    false
  );
$$;

revoke all on function public.current_user_role() from public;
grant execute on function public.current_user_role() to authenticated;
revoke all on function public.is_staff_user() from public;
grant execute on function public.is_staff_user() to authenticated;

alter table public.profiles enable row level security;

drop policy if exists "profiles_select_admin" on public.profiles;
drop policy if exists "profiles_select_self" on public.profiles;
drop policy if exists "profiles_select_volunteer_demo" on public.profiles;
drop policy if exists "profiles_select_staff" on public.profiles;
drop policy if exists "profiles_insert_self" on public.profiles;
drop policy if exists "profiles_update_self" on public.profiles;

-- ① 每人可讀自己的 profile（登入後角色分流、Google OAuth 必備）
create policy "profiles_select_self"
on public.profiles for select to authenticated
using (auth.uid() = id);

-- ② 志工／管理可讀他人 profile（顯示長輩姓名、電話）
create policy "profiles_select_staff"
on public.profiles for select to authenticated
using (public.is_staff_user());

-- ③ OAuth / 註冊後建立 profile
create policy "profiles_insert_self"
on public.profiles for insert to authenticated
with check (auth.uid() = id);

-- ④ 編輯個人頁
create policy "profiles_update_self"
on public.profiles for update to authenticated
using (auth.uid() = id)
with check (auth.uid() = id);
