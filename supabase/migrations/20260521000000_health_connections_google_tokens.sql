-- Migration: Google Health API token storage
-- Adds OAuth 2.0 token columns to health_connections for Google Health API.
-- These tokens allow the app to call https://health.googleapis.com on behalf of the elder.

ALTER TABLE public.health_connections
  ADD COLUMN IF NOT EXISTS access_token     text,
  ADD COLUMN IF NOT EXISTS refresh_token    text,
  ADD COLUMN IF NOT EXISTS token_expires_at timestamptz;

-- Tokens are sensitive. Supabase RLS already limits rows to own data,
-- but ensure token columns are never exposed in any anon/public select.
-- The existing RLS policies on health_connections cover this.

-- Update the provider value used by new Google Health API connections.
-- (existing 'health_connect' rows are kept for reference but the app will
-- create new rows with provider = 'google_health'.)
