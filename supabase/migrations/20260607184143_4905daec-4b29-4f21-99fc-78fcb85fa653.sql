
CREATE TABLE public.intake_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  channel text NOT NULL CHECK (channel IN ('gmail','outlook','telegram','web_link','manual')),
  source_ref text,
  source_address text,
  subject text,
  raw_text text,
  raw_payload jsonb,
  attachments jsonb NOT NULL DEFAULT '[]'::jsonb,
  parsed_data jsonb,
  confidence numeric,
  status text NOT NULL DEFAULT 'new'
    CHECK (status IN ('new','parsing','needs_review','auto_created','converted','dismissed','error')),
  inspection_request_id uuid,
  error text,
  dedupe_hash text,
  created_by uuid,
  updated_by uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.intake_items TO authenticated;
GRANT ALL ON public.intake_items TO service_role;

ALTER TABLE public.intake_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "org members manage intake_items"
  ON public.intake_items
  FOR ALL
  TO authenticated
  USING (public.is_org_member(organization_id))
  WITH CHECK (public.is_org_member(organization_id));

CREATE INDEX idx_intake_items_org_status ON public.intake_items (organization_id, status);
CREATE INDEX idx_intake_items_created ON public.intake_items (organization_id, created_at DESC);
CREATE UNIQUE INDEX uniq_intake_items_org_dedupe
  ON public.intake_items (organization_id, dedupe_hash)
  WHERE dedupe_hash IS NOT NULL;

CREATE TRIGGER intake_items_touch_updated_at
  BEFORE UPDATE ON public.intake_items
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();
