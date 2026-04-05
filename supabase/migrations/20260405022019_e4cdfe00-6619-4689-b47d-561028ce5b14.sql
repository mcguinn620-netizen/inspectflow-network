
-- Create audit_log table
CREATE TABLE public.audit_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_type text NOT NULL,
  entity_id uuid NOT NULL,
  action text NOT NULL,
  changes jsonb,
  user_id uuid,
  created_at timestamptz DEFAULT now()
);
ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated access" ON public.audit_log FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Add soft-delete and audit columns to inspection_requests
ALTER TABLE public.inspection_requests
  ADD COLUMN IF NOT EXISTS deleted_at timestamptz,
  ADD COLUMN IF NOT EXISTS created_by uuid,
  ADD COLUMN IF NOT EXISTS updated_by uuid;

-- Add soft-delete and audit columns to inspectors
ALTER TABLE public.inspectors
  ADD COLUMN IF NOT EXISTS deleted_at timestamptz,
  ADD COLUMN IF NOT EXISTS created_by uuid,
  ADD COLUMN IF NOT EXISTS updated_by uuid;

-- Add soft-delete and audit columns to inspection_templates
ALTER TABLE public.inspection_templates
  ADD COLUMN IF NOT EXISTS deleted_at timestamptz,
  ADD COLUMN IF NOT EXISTS created_by uuid,
  ADD COLUMN IF NOT EXISTS updated_by uuid;

-- Add soft-delete and audit columns to companies
ALTER TABLE public.companies
  ADD COLUMN IF NOT EXISTS deleted_at timestamptz,
  ADD COLUMN IF NOT EXISTS created_by uuid,
  ADD COLUMN IF NOT EXISTS updated_by uuid;

-- Add soft-delete and audit columns to dispatch_assignments
ALTER TABLE public.dispatch_assignments
  ADD COLUMN IF NOT EXISTS deleted_at timestamptz,
  ADD COLUMN IF NOT EXISTS created_by uuid,
  ADD COLUMN IF NOT EXISTS updated_by uuid;

-- Create vehicles table (currently only exists as fields on inspection_requests)
CREATE TABLE public.vehicles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vin text NOT NULL,
  year text,
  make text,
  model text,
  trim text,
  mileage text,
  company_id uuid,
  is_archived boolean DEFAULT false,
  deleted_at timestamptz,
  created_by uuid,
  updated_by uuid,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
ALTER TABLE public.vehicles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated access" ON public.vehicles FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Add vehicle_id reference to inspection_requests
ALTER TABLE public.inspection_requests
  ADD COLUMN IF NOT EXISTS vehicle_id uuid REFERENCES public.vehicles(id);
