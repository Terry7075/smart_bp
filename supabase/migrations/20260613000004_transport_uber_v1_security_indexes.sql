revoke execute on function public.cancel_ride_request(uuid, text) from public, anon;
revoke execute on function public.reschedule_ride_request(uuid, date, time, time) from public, anon;
revoke execute on function public.reassign_ride(uuid, uuid) from public, anon;
revoke execute on function public.submit_ride_feedback(uuid, integer, text, text, text) from public, anon;
revoke execute on function public.resolve_ride_feedback(uuid) from public, anon;
revoke execute on function public.upsert_driver_location(uuid, double precision, double precision, double precision, double precision, double precision) from public, anon;

grant execute on function public.cancel_ride_request(uuid, text) to authenticated;
grant execute on function public.reschedule_ride_request(uuid, date, time, time) to authenticated;
grant execute on function public.reassign_ride(uuid, uuid) to authenticated;
grant execute on function public.submit_ride_feedback(uuid, integer, text, text, text) to authenticated;
grant execute on function public.resolve_ride_feedback(uuid) to authenticated;
grant execute on function public.upsert_driver_location(uuid, double precision, double precision, double precision, double precision, double precision) to authenticated;

create index if not exists ride_events_actor_id_idx
  on public.ride_events(actor_id);
create index if not exists ride_events_ride_match_id_idx
  on public.ride_events(ride_match_id);
create index if not exists ride_feedback_reporter_id_idx
  on public.ride_feedback(reporter_id);
create index if not exists ride_feedback_resolved_by_idx
  on public.ride_feedback(resolved_by);
create index if not exists ride_feedback_ride_match_id_idx
  on public.ride_feedback(ride_match_id);
