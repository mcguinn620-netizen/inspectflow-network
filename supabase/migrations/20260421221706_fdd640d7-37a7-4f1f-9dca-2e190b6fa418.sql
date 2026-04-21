-- Extend role enum (idempotent)
DO $$ BEGIN
  ALTER TYPE public.app_role ADD VALUE IF NOT EXISTS 'mechanic';
EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN
  ALTER TYPE public.app_role ADD VALUE IF NOT EXISTS 'dispatcher';
EXCEPTION WHEN others THEN NULL; END $$;

-- Organizations
CREATE TABLE IF NOT EXISTS public.organizations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  slug text,
  type text NOT NULL DEFAULT 'solo', -- solo | team | enterprise
  owner_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);
ALTER TABLE public.organizations ENABLE ROW LEVEL SECURITY;

CREATE TABLE IF NOT EXISTS public.organization_users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  user_id uuid NOT NULL,
  role public.app_role NOT NULL DEFAULT 'inspector',
  is_default boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (organization_id, user_id)
);
ALTER TABLE public.organization_users ENABLE ROW LEVEL SECURITY;

-- Helper: is current user a member of org?
CREATE OR REPLACE FUNCTION public.is_org_member(_org_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.organization_users
    WHERE organization_id = _org_id AND user_id = auth.uid()
  )
$$;

-- Jobs (inspector-first, but reusable across roles)
CREATE TABLE IF NOT EXISTS public.jobs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  assigned_to uuid, -- user id
  inspection_request_id uuid, -- optional link to existing inspection
  vehicle_id uuid,
  title text NOT NULL,
  customer_name text,
  location text,
  scheduled_at timestamptz,
  estimated_duration_minutes integer DEFAULT 60,
  actual_start_time timestamptz,
  actual_end_time timestamptz,
  status text NOT NULL DEFAULT 'scheduled', -- scheduled | in_progress | completed | canceled
  fee_override numeric, -- per-job flat fee override
  notes text,
  created_by uuid,
  updated_by uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);
ALTER TABLE public.jobs ENABLE ROW LEVEL SECURITY;
CREATE INDEX IF NOT EXISTS idx_jobs_org ON public.jobs(organization_id);
CREATE INDEX IF NOT EXISTS idx_jobs_assigned ON public.jobs(assigned_to);
CREATE INDEX IF NOT EXISTS idx_jobs_scheduled ON public.jobs(scheduled_at);

-- Trips
CREATE TABLE IF NOT EXISTS public.trips (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  user_id uuid NOT NULL,
  trip_date date NOT NULL DEFAULT CURRENT_DATE,
  start_time timestamptz,
  end_time timestamptz,
  total_miles numeric DEFAULT 0,
  drive_minutes integer DEFAULT 0,
  work_minutes integer DEFAULT 0,
  status text NOT NULL DEFAULT 'planned', -- planned | active | completed
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.trips ENABLE ROW LEVEL SECURITY;
CREATE INDEX IF NOT EXISTS idx_trips_org ON public.trips(organization_id);
CREATE INDEX IF NOT EXISTS idx_trips_user_date ON public.trips(user_id, trip_date);

-- Trip stops (placeholder for GPS, manual now)
CREATE TABLE IF NOT EXISTS public.trip_stops (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id uuid NOT NULL REFERENCES public.trips(id) ON DELETE CASCADE,
  job_id uuid REFERENCES public.jobs(id) ON DELETE SET NULL,
  sort_order integer NOT NULL DEFAULT 0,
  label text,
  address text,
  latitude numeric,
  longitude numeric,
  arrived_at timestamptz,
  departed_at timestamptz,
  miles_from_previous numeric DEFAULT 0,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.trip_stops ENABLE ROW LEVEL SECURITY;
CREATE INDEX IF NOT EXISTS idx_trip_stops_trip ON public.trip_stops(trip_id);

-- Earnings settings (per user, per org) - flat job fee + mileage fee
CREATE TABLE IF NOT EXISTS public.earnings_settings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  user_id uuid NOT NULL,
  default_job_fee numeric NOT NULL DEFAULT 75,
  mileage_rate numeric NOT NULL DEFAULT 0.67, -- IRS-style $/mile
  estimated_tax_rate numeric NOT NULL DEFAULT 0.25,
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (organization_id, user_id)
);
ALTER TABLE public.earnings_settings ENABLE ROW LEVEL SECURITY;

-- RLS POLICIES (org-scoped)
DROP POLICY IF EXISTS "org members read" ON public.organizations;
CREATE POLICY "org members read" ON public.organizations FOR SELECT TO authenticated
USING (public.is_org_member(id));
DROP POLICY IF EXISTS "owner manages org" ON public.organizations;
CREATE POLICY "owner manages org" ON public.organizations FOR ALL TO authenticated
USING (owner_id = auth.uid()) WITH CHECK (owner_id = auth.uid());

DROP POLICY IF EXISTS "members read memberships" ON public.organization_users;
CREATE POLICY "members read memberships" ON public.organization_users FOR SELECT TO authenticated
USING (user_id = auth.uid() OR public.is_org_member(organization_id));
DROP POLICY IF EXISTS "self insert membership" ON public.organization_users;
CREATE POLICY "self insert membership" ON public.organization_users FOR INSERT TO authenticated
WITH CHECK (user_id = auth.uid());
DROP POLICY IF EXISTS "self update membership" ON public.organization_users;
CREATE POLICY "self update membership" ON public.organization_users FOR UPDATE TO authenticated
USING (user_id = auth.uid());

DROP POLICY IF EXISTS "org members manage jobs" ON public.jobs;
CREATE POLICY "org members manage jobs" ON public.jobs FOR ALL TO authenticated
USING (public.is_org_member(organization_id))
WITH CHECK (public.is_org_member(organization_id));

DROP POLICY IF EXISTS "org members manage trips" ON public.trips;
CREATE POLICY "org members manage trips" ON public.trips FOR ALL TO authenticated
USING (public.is_org_member(organization_id))
WITH CHECK (public.is_org_member(organization_id));

DROP POLICY IF EXISTS "org members manage trip_stops" ON public.trip_stops;
CREATE POLICY "org members manage trip_stops" ON public.trip_stops FOR ALL TO authenticated
USING (EXISTS (SELECT 1 FROM public.trips t WHERE t.id = trip_id AND public.is_org_member(t.organization_id)))
WITH CHECK (EXISTS (SELECT 1 FROM public.trips t WHERE t.id = trip_id AND public.is_org_member(t.organization_id)));

DROP POLICY IF EXISTS "self manage earnings settings" ON public.earnings_settings;
CREATE POLICY "self manage earnings settings" ON public.earnings_settings FOR ALL TO authenticated
USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- updated_at triggers (reuse existing function if present)
CREATE OR REPLACE FUNCTION public.touch_updated_at()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END $$;

DROP TRIGGER IF EXISTS trg_jobs_updated ON public.jobs;
CREATE TRIGGER trg_jobs_updated BEFORE UPDATE ON public.jobs
FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();
DROP TRIGGER IF EXISTS trg_trips_updated ON public.trips;
CREATE TRIGGER trg_trips_updated BEFORE UPDATE ON public.trips
FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();
DROP TRIGGER IF EXISTS trg_orgs_updated ON public.organizations;
CREATE TRIGGER trg_orgs_updated BEFORE UPDATE ON public.organizations
FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

-- Replace handle_new_user to bootstrap org + role from signup metadata
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_org_id uuid;
  v_role public.app_role;
  v_role_text text;
BEGIN
  INSERT INTO public.profiles (id, full_name)
  VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email))
  ON CONFLICT (id) DO NOTHING;

  v_role_text := COALESCE(NEW.raw_user_meta_data->>'role', 'inspector');
  BEGIN
    v_role := v_role_text::public.app_role;
  EXCEPTION WHEN others THEN
    v_role := 'inspector'::public.app_role;
  END;

  INSERT INTO public.organizations (name, type, owner_id)
  VALUES (COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email,'@',1)) || '''s Workspace', 'solo', NEW.id)
  RETURNING id INTO v_org_id;

  INSERT INTO public.organization_users (organization_id, user_id, role, is_default)
  VALUES (v_org_id, NEW.id, v_role, true);

  INSERT INTO public.user_roles (user_id, role)
  VALUES (NEW.id, v_role)
  ON CONFLICT DO NOTHING;

  INSERT INTO public.earnings_settings (organization_id, user_id)
  VALUES (v_org_id, NEW.id)
  ON CONFLICT DO NOTHING;

  RETURN NEW;
END $$;

-- Ensure trigger exists on auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();