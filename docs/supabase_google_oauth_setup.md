# Supabase + Google OAuth setup

## 1. Create Supabase project

From Supabase Dashboard, copy:

- Project URL
- Publishable key

Use these values only through `--dart-define`; do not hardcode them in Dart source.

## 2. Apply database migrations

Run the SQL files in order:

1. `supabase/migrations/202605150001_mvp_schema.sql`
2. `supabase/migrations/20260515163710_mvp_hardening.sql`
3. `supabase/migrations/20260516020000_uber_v1.sql`

The v1 migration adds:

- `driver_locations`
- `ride_events`
- `ride_feedback`
- emergency contact columns on `profiles`
- cancellation, rescheduling, reassignment, GPS, and feedback RPCs

## 3. Configure app redirect URL

In Supabase Dashboard:

- Authentication
- URL Configuration
- Redirect URLs

Add:

```text
tw.mingde.transport://login-callback/
```

## 4. Configure Google OAuth

In Google Cloud Console, create a Web application OAuth client.

Authorized redirect URI:

```text
https://YOUR_PROJECT_REF.supabase.co/auth/v1/callback
```

Then enable Google provider in Supabase:

- Authentication
- Providers
- Google
- Add Client ID and Client Secret

## 5. Create first admin

Sign in once with Google so Supabase creates a `profiles` row, then run:

```sql
update public.profiles
set role = 'admin'
where email = 'admin@example.com';
```

## 6. Runtime checks

- Elder account can create and track rides.
- Driver account can submit an application and be approved.
- Approved driver can accept rides and update GPS.
- Admin can manually match, cancel, reschedule, reassign, and resolve reports.
