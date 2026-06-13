revoke all on table public.profiles from anon;
revoke all on table public.drivers from anon;
revoke all on table public.ride_requests from anon;
revoke all on table public.ride_matches from anon;
revoke all on table public.ride_events from anon;
revoke all on table public.ride_feedback from anon;
revoke all on table public.driver_locations from anon;
revoke all on table public.notifications from anon;

revoke all on table public.profiles from authenticated;
revoke all on table public.drivers from authenticated;
revoke all on table public.ride_requests from authenticated;
revoke all on table public.ride_matches from authenticated;
revoke all on table public.ride_events from authenticated;
revoke all on table public.ride_feedback from authenticated;
revoke all on table public.driver_locations from authenticated;
revoke all on table public.notifications from authenticated;

grant select, insert, update on table public.profiles to authenticated;
grant select, insert, update on table public.drivers to authenticated;
grant select, insert, update on table public.ride_requests to authenticated;
grant select, insert, update on table public.ride_matches to authenticated;
grant select on table public.ride_events to authenticated;
grant select, insert, update on table public.ride_feedback to authenticated;
grant select, insert, update on table public.driver_locations to authenticated;
grant select, update on table public.notifications to authenticated;
