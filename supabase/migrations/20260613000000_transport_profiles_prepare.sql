-- 社區交通模組整合（步驟 0）：調整 smart_bp 既有的 public.profiles
--
-- 1) 角色加入 'driver'（保留 smart_bp 既有的 elder/volunteer/family/admin）。
--    同時相容兩種設計：role 為 text + check 約束，或 role 為 enum 型別。
-- 2) 補上交通模組「個人資料設定」需要的緊急聯絡人欄位。
--
-- 注意：本檔刻意不重建 profiles、不更動其 RLS，避免影響 smart_bp 既有模組。

-- 1a) 若 role 是 text 欄位且帶 check 約束：移除舊 check，改成包含 driver 的超集。
do $$
declare
  v_conname text;
  v_is_text boolean;
begin
  select (data_type = 'text') into v_is_text
  from information_schema.columns
  where table_schema = 'public' and table_name = 'profiles' and column_name = 'role';

  if coalesce(v_is_text, false) then
    for v_conname in
      select c.conname
      from pg_constraint c
      join pg_class t on t.oid = c.conrelid
      join pg_namespace n on n.oid = t.relnamespace
      where n.nspname = 'public'
        and t.relname = 'profiles'
        and c.contype = 'c'
        and pg_get_constraintdef(c.oid) ilike '%role%'
    loop
      execute format('alter table public.profiles drop constraint %I', v_conname);
    end loop;

    alter table public.profiles
      add constraint profiles_role_check
      check (role in ('elder', 'volunteer', 'family', 'admin', 'driver'));
  end if;
end $$;

-- 1b) 若 role 是 enum 型別：補上 'driver' 值（若尚未存在）。
do $$
declare
  v_typname text;
begin
  select t.typname into v_typname
  from pg_type t
  join pg_attribute a on a.atttypid = t.oid
  join pg_class c on c.oid = a.attrelid
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relname = 'profiles'
    and a.attname = 'role'
    and t.typtype = 'e';

  if v_typname is not null then
    execute format('alter type public.%I add value if not exists %L', v_typname, 'driver');
  end if;
end $$;

-- 2) 緊急聯絡人欄位（交通模組 ProfileSetupPage 使用）。
alter table public.profiles add column if not exists emergency_contact_name text;
alter table public.profiles add column if not exists emergency_contact_phone text;
alter table public.profiles add column if not exists emergency_contact_relation text;
