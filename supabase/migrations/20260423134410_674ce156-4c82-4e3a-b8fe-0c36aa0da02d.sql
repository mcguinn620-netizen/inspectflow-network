
-- Extend earnings_settings with state/federal/mileage fee
ALTER TABLE public.earnings_settings
  ADD COLUMN IF NOT EXISTS default_mileage_fee numeric NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS state_code text,
  ADD COLUMN IF NOT EXISTS federal_tax_rate numeric NOT NULL DEFAULT 0.15,
  ADD COLUMN IF NOT EXISTS state_tax_rate numeric NOT NULL DEFAULT 0.05,
  ADD COLUMN IF NOT EXISTS self_employment_tax_rate numeric NOT NULL DEFAULT 0.153,
  ADD COLUMN IF NOT EXISTS filing_status text NOT NULL DEFAULT 'single';

-- Add mileage_fee to jobs
ALTER TABLE public.jobs
  ADD COLUMN IF NOT EXISTS mileage_fee numeric;

-- Add fields to trips for full editing + vehicle link
ALTER TABLE public.trips
  ADD COLUMN IF NOT EXISTS title text,
  ADD COLUMN IF NOT EXISTS inspector_vehicle_id uuid;

-- Inspector-owned vehicles (separate from customer vehicles table)
CREATE TABLE IF NOT EXISTS public.inspector_vehicles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  organization_id uuid NOT NULL,
  nickname text NOT NULL,
  year text,
  make text,
  model text,
  license_plate text,
  is_default boolean NOT NULL DEFAULT false,
  is_archived boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.inspector_vehicles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "self manage inspector vehicles" ON public.inspector_vehicles;
CREATE POLICY "self manage inspector vehicles"
  ON public.inspector_vehicles
  FOR ALL
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

DROP TRIGGER IF EXISTS inspector_vehicles_touch ON public.inspector_vehicles;
CREATE TRIGGER inspector_vehicles_touch
  BEFORE UPDATE ON public.inspector_vehicles
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

CREATE INDEX IF NOT EXISTS inspector_vehicles_user_idx ON public.inspector_vehicles(user_id);
