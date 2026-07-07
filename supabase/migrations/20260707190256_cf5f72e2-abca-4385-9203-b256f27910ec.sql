-- Submission mode enum (only 'draft' is wired now; other values are UI stubs)
DO $$ BEGIN
  CREATE TYPE public.lemonsquad_submission_mode AS ENUM ('draft', 'review_confirm', 'auto_on_complete');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- 1) external_site_credentials
CREATE TABLE IF NOT EXISTS public.external_site_credentials (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  site text NOT NULL,
  username text NOT NULL,
  password_ciphertext text,
  submission_mode public.lemonsquad_submission_mode NOT NULL DEFAULT 'draft',
  is_active boolean NOT NULL DEFAULT true,
  last_login_at timestamptz,
  last_error text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, site)
);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.external_site_credentials TO authenticated;
GRANT ALL ON public.external_site_credentials TO service_role;
ALTER TABLE public.external_site_credentials ENABLE ROW LEVEL SECURITY;

CREATE POLICY "own creds - select" ON public.external_site_credentials
  FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "own creds - insert" ON public.external_site_credentials
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY "own creds - update" ON public.external_site_credentials
  FOR UPDATE TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "own creds - delete" ON public.external_site_credentials
  FOR DELETE TO authenticated USING (auth.uid() = user_id);

CREATE TRIGGER external_site_credentials_touch
  BEFORE UPDATE ON public.external_site_credentials
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

-- 2) lemonsquad_sessions
CREATE TABLE IF NOT EXISTS public.lemonsquad_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
  cookies_json jsonb,
  user_agent text,
  expires_at timestamptz,
  pending_challenge_url text,
  pending_challenge_started_at timestamptz,
  last_used_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.lemonsquad_sessions TO authenticated;
GRANT ALL ON public.lemonsquad_sessions TO service_role;
ALTER TABLE public.lemonsquad_sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "own session - select" ON public.lemonsquad_sessions
  FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "own session - insert" ON public.lemonsquad_sessions
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY "own session - update" ON public.lemonsquad_sessions
  FOR UPDATE TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "own session - delete" ON public.lemonsquad_sessions
  FOR DELETE TO authenticated USING (auth.uid() = user_id);

CREATE TRIGGER lemonsquad_sessions_touch
  BEFORE UPDATE ON public.lemonsquad_sessions
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

-- 3) lemonsquad_field_maps (shared cache)
CREATE TABLE IF NOT EXISTS public.lemonsquad_field_maps (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  form_key text NOT NULL,
  form_hash text NOT NULL,
  mapping_json jsonb NOT NULL,
  sample_fields_json jsonb,
  created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (form_key, form_hash)
);

GRANT SELECT ON public.lemonsquad_field_maps TO authenticated;
GRANT ALL ON public.lemonsquad_field_maps TO service_role;
ALTER TABLE public.lemonsquad_field_maps ENABLE ROW LEVEL SECURITY;

CREATE POLICY "field maps - read for authed" ON public.lemonsquad_field_maps
  FOR SELECT TO authenticated USING (true);
-- writes go through service role only (edge function)

CREATE TRIGGER lemonsquad_field_maps_touch
  BEFORE UPDATE ON public.lemonsquad_field_maps
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();