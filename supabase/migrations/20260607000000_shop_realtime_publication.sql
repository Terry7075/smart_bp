-- 物資子系統 Realtime publication（冪等，可重複執行）
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public' and tablename = 'orders'
  ) then
    alter publication supabase_realtime add table public.orders;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public' and tablename = 'demand_records'
  ) then
    alter publication supabase_realtime add table public.demand_records;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public' and tablename = 'demand_record_items'
  ) then
    alter publication supabase_realtime add table public.demand_record_items;
  end if;
end $$;
