create table if not exists public.fixed_ride_suggestions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid null,
  destination text not null,
  weekday int null,
  suggested_time text null,
  occurrence_count int default 0,
  status text default 'pending',
  created_at timestamptz default now(),
  confirmed_at timestamptz null
);

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
with check (true);

create policy "fixed_ride_suggestions_update_authenticated"
on public.fixed_ride_suggestions
for update
to authenticated
using (true)
with check (true);

grant select, insert, update on table public.fixed_ride_suggestions to authenticated;

notify pgrst, 'reload schema';
