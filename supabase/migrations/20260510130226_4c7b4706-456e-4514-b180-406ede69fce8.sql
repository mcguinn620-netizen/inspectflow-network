
-- device_tokens for push notifications
CREATE TABLE IF NOT EXISTS public.device_tokens (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  token text NOT NULL,
  platform text NOT NULL DEFAULT 'ios',
  app_version text,
  last_seen timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, token)
);

ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "self read device_tokens"
  ON public.device_tokens FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "self insert device_tokens"
  ON public.device_tokens FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "self update device_tokens"
  ON public.device_tokens FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "self delete device_tokens"
  ON public.device_tokens FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());

CREATE INDEX IF NOT EXISTS idx_device_tokens_user ON public.device_tokens(user_id);

-- inspection-photos bucket (private)
INSERT INTO storage.buckets (id, name, public)
VALUES ('inspection-photos', 'inspection-photos', false)
ON CONFLICT (id) DO NOTHING;

-- Path layout: {organization_id}/{inspection_id}/{filename}
CREATE POLICY "org members read inspection photos"
  ON storage.objects FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'inspection-photos'
    AND public.is_org_member(((storage.foldername(name))[1])::uuid)
  );

CREATE POLICY "org members upload inspection photos"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'inspection-photos'
    AND public.is_org_member(((storage.foldername(name))[1])::uuid)
  );

CREATE POLICY "org members update inspection photos"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'inspection-photos'
    AND public.is_org_member(((storage.foldername(name))[1])::uuid)
  );

CREATE POLICY "org members delete inspection photos"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'inspection-photos'
    AND public.is_org_member(((storage.foldername(name))[1])::uuid)
  );
