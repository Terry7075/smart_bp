-- 讓 learning_content 支援 Realtime（若已加入 publication 可略過錯誤）
do $$
begin
  alter publication supabase_realtime add table public.learning_content;
exception
  when duplicate_object then null;
end $$;

alter table public.learning_content replica identity full;

grant select on table public.learning_content to authenticated;
grant insert, update, delete on table public.learning_content to authenticated;
