-- 志工會員管理：長輩(elder)個人資料瀏覽 / 編輯 / 共享備註
--
-- 背景：
--   * profiles 已啟用 RLS，is_staff_user() 對 volunteer/admin 回 true。
--   * profiles_select_staff policy 已允許志工讀取全部 profiles（瀏覽不需改動）。
--   * 目前只有 profiles_update_self，志工無法編輯其他人。
--
-- 本 migration：
--   1. 在 public.profiles 新增共享備註欄位 volunteer_note。
--   2. 新增 SECURITY DEFINER RPC，讓志工/管理員只能更新 elder 的
--      姓名 / 電話 / 備註三個欄位，role 等其他欄位無法被竄改，
--      避免直接對整張表開放 UPDATE policy 造成權限提升風險。

alter table public.profiles
  add column if not exists volunteer_note text;

create or replace function public.volunteer_update_elder_member(
  p_target_id uuid,
  p_name text,
  p_phone text,
  p_note text
)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if not public.is_staff_user() then
    raise exception 'not authorized';
  end if;

  update public.profiles
     set name = coalesce(nullif(trim(p_name), ''), name),
         phone = nullif(trim(p_phone), ''),
         volunteer_note = nullif(p_note, '')
   where id = p_target_id
     and role = 'elder';

  if not found then
    raise exception 'elder not found';
  end if;
end;
$$;

revoke all on function public.volunteer_update_elder_member(uuid, text, text, text) from public;
grant execute on function public.volunteer_update_elder_member(uuid, text, text, text) to authenticated;

-- 讓 PostgREST 立即重新載入 schema cache，否則 app 端 .rpc() 會回
-- PGRST202「找不到函式」直到下次自動 reload。
notify pgrst, 'reload schema';
