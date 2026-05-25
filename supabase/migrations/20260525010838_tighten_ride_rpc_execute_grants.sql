revoke execute on function public.accept_ride(uuid) from public, anon;
revoke execute on function public.manual_match_ride(uuid, uuid, numeric)
from public, anon;

grant execute on function public.accept_ride(uuid) to authenticated;
grant execute on function public.manual_match_ride(uuid, uuid, numeric)
to authenticated;
