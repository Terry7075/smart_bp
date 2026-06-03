revoke all on table public.standing_ride_requests from anon;
revoke all on table public.driver_standing_ride_offers from anon;

revoke delete, truncate, references, trigger
on table public.standing_ride_requests
from authenticated;

revoke delete, truncate, references, trigger
on table public.driver_standing_ride_offers
from authenticated;

grant select, insert, update
on table public.standing_ride_requests
to authenticated;

grant select, insert, update
on table public.driver_standing_ride_offers
to authenticated;
