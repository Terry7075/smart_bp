create table if not exists public.fixed_ride_suggestions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid,
  destination text not null,
  weekday int,
  suggested_time text,
  occurrence_count int default 0,
  status text default 'pending',
  created_at timestamptz default now(),
  confirmed_at timestamptz null
);

create index if not exists fixed_ride_suggestions_created_at_idx
  on public.fixed_ride_suggestions(created_at desc);

create index if not exists fixed_ride_suggestions_user_id_idx
  on public.fixed_ride_suggestions(user_id);

alter table public.fixed_ride_suggestions enable row level security;

drop policy if exists "fixed_ride_suggestions_select_authenticated"
  on public.fixed_ride_suggestions;
drop policy if exists "fixed_ride_suggestions_insert_authenticated"
  on public.fixed_ride_suggestions;
drop policy if exists "fixed_ride_suggestions_update_authenticated"
  on public.fixed_ride_suggestions;

create policy "fixed_ride_suggestions_select_authenticated"
on public.fixed_ride_suggestions
for select
to authenticated
using (true);

create policy "fixed_ride_suggestions_insert_authenticated"
on public.fixed_ride_suggestions
for insert
to authenticated
with check (user_id = (select auth.uid()) or private.is_admin());

create policy "fixed_ride_suggestions_update_authenticated"
on public.fixed_ride_suggestions
for update
to authenticated
using (user_id = (select auth.uid()) or private.is_admin())
with check (user_id = (select auth.uid()) or private.is_admin());

revoke all on table public.fixed_ride_suggestions from anon;
revoke all on table public.fixed_ride_suggestions from authenticated;
grant select, insert, update on table public.fixed_ride_suggestions to authenticated;

do $$
begin
  alter publication supabase_realtime add table public.fixed_ride_suggestions;
exception
  when duplicate_object then null;
end $$;
