CREATE TABLE IF NOT EXISTS public.quarterly_tax_overrides (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL,
  organization_id uuid NOT NULL,
  year integer NOT NULL,
  quarter integer NOT NULL CHECK (quarter BETWEEN 1 AND 4),
  income_override numeric,
  deductions_override numeric,
  estimated_tax_override numeric,
  is_paid boolean NOT NULL DEFAULT false,
  paid_amount numeric,
  paid_at date,
  notes text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  UNIQUE(user_id, year, quarter)
);

ALTER TABLE public.quarterly_tax_overrides ENABLE ROW LEVEL SECURITY;

CREATE POLICY "self manage quarterly tax overrides"
  ON public.quarterly_tax_overrides
  FOR ALL
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE TRIGGER trg_quarterly_tax_overrides_updated_at
  BEFORE UPDATE ON public.quarterly_tax_overrides
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

CREATE INDEX IF NOT EXISTS idx_qto_user_year ON public.quarterly_tax_overrides(user_id, year);