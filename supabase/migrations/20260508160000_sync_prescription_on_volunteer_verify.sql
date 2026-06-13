-- 志工將 volunteer_tasks 標為 active 時，同步更新同 id 的 prescriptions（長輩端 Realtime 才會顯示使用中藥單）。
create or replace function public.sync_prescription_on_volunteer_task_active()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'UPDATE'
     and new.status = 'active'
     and (old.status is distinct from new.status) then
    update public.prescriptions
    set
      status = 'active',
      hospital_name = coalesce(new.hospital_name, prescriptions.hospital_name),
      pickup_date = coalesce(new.pickup_date, prescriptions.pickup_date),
      take_medicine_times = coalesce(
        new.take_medicine_times,
        prescriptions.take_medicine_times
      ),
      source = 'volunteer'
    where id = new.id;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_sync_prescription_on_volunteer_task_active
  on public.volunteer_tasks;

create trigger trg_sync_prescription_on_volunteer_task_active
  after update on public.volunteer_tasks
  for each row
  execute function public.sync_prescription_on_volunteer_task_active();

-- 志工確認時，App 端 upsert 備援（需與既有 RLS 相容；若無 policy 仍靠上方 trigger）。
drop policy if exists volunteer_update_prescription_on_verify on public.prescriptions;

create policy volunteer_update_prescription_on_verify
  on public.prescriptions
  for update
  to authenticated
  using (
    exists (
      select 1
      from public.volunteer_tasks vt
      where vt.id = prescriptions.id
        and vt.claimed_by = auth.uid()
        and vt.status = 'active'
    )
  )
  with check (
    exists (
      select 1
      from public.volunteer_tasks vt
      where vt.id = prescriptions.id
        and vt.claimed_by = auth.uid()
    )
  );
