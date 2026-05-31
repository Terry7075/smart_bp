-- Extend health_connections_provider_check to allow 'google_health' provider.
-- Also update the default to 'google_health' since Health Connect is replaced.

ALTER TABLE public.health_connections
  DROP CONSTRAINT IF EXISTS health_connections_provider_check;

ALTER TABLE public.health_connections
  ADD CONSTRAINT health_connections_provider_check
    CHECK (provider IN ('health_connect', 'google_health'));

ALTER TABLE public.health_connections
  ALTER COLUMN provider SET DEFAULT 'google_health';
