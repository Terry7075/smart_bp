revoke execute on function public.create_standing_ride_request(text, text, text, time, integer, boolean, time, text, text, date, date) from public, anon;
revoke execute on function public.approve_standing_ride_request(uuid) from public, anon;
revoke execute on function public.reject_standing_ride_request(uuid, text) from public, anon;
revoke execute on function public.cancel_standing_ride_request(uuid) from public, anon;
revoke execute on function public.generate_standing_ride_requests(uuid) from public, anon;

grant execute on function public.create_standing_ride_request(text, text, text, time, integer, boolean, time, text, text, date, date) to authenticated;
grant execute on function public.approve_standing_ride_request(uuid) to authenticated;
grant execute on function public.reject_standing_ride_request(uuid, text) to authenticated;
grant execute on function public.cancel_standing_ride_request(uuid) to authenticated;
grant execute on function public.generate_standing_ride_requests(uuid) to authenticated;

create index if not exists standing_ride_requests_reviewed_by_idx
  on public.standing_ride_requests(reviewed_by);
