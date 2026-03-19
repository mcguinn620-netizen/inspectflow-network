
-- Companies table (multi-tenant core)
CREATE TABLE public.companies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  slug text UNIQUE NOT NULL,
  logo_url text,
  contact_email text,
  contact_phone text,
  address text,
  city text,
  state text,
  zip text,
  subscription_tier text DEFAULT 'basic',
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Profiles table (linked to auth.users)
CREATE TABLE public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name text,
  avatar_url text,
  phone text,
  company_id uuid REFERENCES public.companies(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- User roles table
CREATE TYPE public.app_role AS ENUM ('super_admin', 'network_admin', 'company_admin', 'repair_shop_manager', 'inspector', 'technician', 'client', 'fleet_manager');

CREATE TABLE public.user_roles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  role app_role NOT NULL,
  UNIQUE (user_id, role)
);

-- Security definer function for role checks
CREATE OR REPLACE FUNCTION public.has_role(_user_id uuid, _role app_role)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_roles WHERE user_id = _user_id AND role = _role
  )
$$;

-- Inspectors table
CREATE TABLE public.inspectors (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  company_id uuid REFERENCES public.companies(id) ON DELETE CASCADE,
  name text NOT NULL,
  avatar_url text,
  email text,
  phone text,
  rating numeric(3,2) DEFAULT 0,
  completed_jobs integer DEFAULT 0,
  status text DEFAULT 'available',
  certifications text[] DEFAULT '{}',
  hourly_rate numeric(10,2),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Territories
CREATE TABLE public.territories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  inspector_id uuid REFERENCES public.inspectors(id) ON DELETE CASCADE NOT NULL,
  name text NOT NULL,
  zip_codes text[] DEFAULT '{}',
  city text,
  state text,
  radius_miles numeric(6,2) DEFAULT 25,
  latitude numeric(10,7),
  longitude numeric(10,7),
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now()
);

-- Availability schedules
CREATE TABLE public.availability_schedules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  inspector_id uuid REFERENCES public.inspectors(id) ON DELETE CASCADE NOT NULL,
  day_of_week integer NOT NULL,
  start_time time NOT NULL,
  end_time time NOT NULL,
  is_available boolean DEFAULT true,
  created_at timestamptz DEFAULT now()
);

-- Time-off / blocked dates
CREATE TABLE public.inspector_blocked_dates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  inspector_id uuid REFERENCES public.inspectors(id) ON DELETE CASCADE NOT NULL,
  blocked_date date NOT NULL,
  reason text,
  created_at timestamptz DEFAULT now()
);

-- Inspection templates
CREATE TABLE public.inspection_templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id uuid REFERENCES public.companies(id) ON DELETE CASCADE,
  name text NOT NULL,
  description text,
  source_provider text,
  inspection_type text DEFAULT 'warranty',
  is_published boolean DEFAULT false,
  is_marketplace boolean DEFAULT false,
  version integer DEFAULT 1,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Template sections
CREATE TABLE public.template_sections (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  template_id uuid REFERENCES public.inspection_templates(id) ON DELETE CASCADE NOT NULL,
  name text NOT NULL,
  sort_order integer DEFAULT 0,
  description text,
  created_at timestamptz DEFAULT now()
);

-- Template checklist items
CREATE TABLE public.template_checklist_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  section_id uuid REFERENCES public.template_sections(id) ON DELETE CASCADE NOT NULL,
  label text NOT NULL,
  input_type text DEFAULT 'pass_fail',
  options jsonb,
  is_required boolean DEFAULT true,
  requires_photo boolean DEFAULT false,
  requires_video boolean DEFAULT false,
  weight numeric(5,2) DEFAULT 1,
  sort_order integer DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

-- Template required photos
CREATE TABLE public.template_required_photos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  template_id uuid REFERENCES public.inspection_templates(id) ON DELETE CASCADE NOT NULL,
  label text NOT NULL,
  description text,
  sort_order integer DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

-- Template special instructions
CREATE TABLE public.template_special_instructions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  template_id uuid REFERENCES public.inspection_templates(id) ON DELETE CASCADE NOT NULL,
  instruction text NOT NULL,
  sort_order integer DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

-- Dispatch assignments
CREATE TABLE public.dispatch_assignments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  inspection_request_id uuid REFERENCES public.inspection_requests(id) ON DELETE CASCADE NOT NULL,
  inspector_id uuid REFERENCES public.inspectors(id) ON DELETE SET NULL,
  assigned_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  assignment_type text DEFAULT 'auto',
  status text DEFAULT 'pending',
  scheduled_date date,
  scheduled_time time,
  dispatch_score numeric(5,2),
  distance_miles numeric(6,2),
  notes text,
  accepted_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Marketplace subscriptions
CREATE TABLE public.template_subscriptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  template_id uuid REFERENCES public.inspection_templates(id) ON DELETE CASCADE NOT NULL,
  company_id uuid REFERENCES public.companies(id) ON DELETE CASCADE NOT NULL,
  subscribed_at timestamptz DEFAULT now(),
  is_active boolean DEFAULT true,
  UNIQUE (template_id, company_id)
);

-- Inspection scores
CREATE TABLE public.inspection_scores (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  inspection_request_id uuid REFERENCES public.inspection_requests(id) ON DELETE CASCADE NOT NULL,
  overall_score numeric(5,2),
  vehicle_condition_rating text,
  section_scores jsonb,
  created_at timestamptz DEFAULT now()
);

-- Inspector ratings
CREATE TABLE public.inspector_ratings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  inspector_id uuid REFERENCES public.inspectors(id) ON DELETE CASCADE NOT NULL,
  inspection_request_id uuid REFERENCES public.inspection_requests(id) ON DELETE CASCADE,
  rated_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  score integer,
  comment text,
  created_at timestamptz DEFAULT now()
);

-- Repair estimates
CREATE TABLE public.repair_estimates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  inspection_request_id uuid REFERENCES public.inspection_requests(id) ON DELETE CASCADE NOT NULL,
  item_label text NOT NULL,
  estimated_cost numeric(10,2),
  labor_hours numeric(5,2),
  labor_rate numeric(10,2),
  parts_cost numeric(10,2),
  status text DEFAULT 'draft',
  notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Enable RLS on all tables
ALTER TABLE public.companies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inspectors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.territories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.availability_schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inspector_blocked_dates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inspection_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.template_sections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.template_checklist_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.template_required_photos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.template_special_instructions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dispatch_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.template_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inspection_scores ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inspector_ratings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.repair_estimates ENABLE ROW LEVEL SECURITY;

-- RLS policies
CREATE POLICY "Authenticated access" ON public.companies FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Authenticated access" ON public.profiles FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Authenticated access" ON public.user_roles FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Authenticated access" ON public.inspectors FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Authenticated access" ON public.territories FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Authenticated access" ON public.availability_schedules FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Authenticated access" ON public.inspector_blocked_dates FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Authenticated access" ON public.inspection_templates FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Authenticated access" ON public.template_sections FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Authenticated access" ON public.template_checklist_items FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Authenticated access" ON public.template_required_photos FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Authenticated access" ON public.template_special_instructions FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Authenticated access" ON public.dispatch_assignments FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Authenticated access" ON public.template_subscriptions FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Authenticated access" ON public.inspection_scores FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Authenticated access" ON public.inspector_ratings FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Authenticated access" ON public.repair_estimates FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Auto-create profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name)
  VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email));
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Add columns to inspection_requests for multi-tenant support
ALTER TABLE public.inspection_requests ADD COLUMN IF NOT EXISTS company_id uuid REFERENCES public.companies(id) ON DELETE SET NULL;
ALTER TABLE public.inspection_requests ADD COLUMN IF NOT EXISTS template_id uuid REFERENCES public.inspection_templates(id) ON DELETE SET NULL;
ALTER TABLE public.inspection_requests ADD COLUMN IF NOT EXISTS inspector_id uuid REFERENCES public.inspectors(id) ON DELETE SET NULL;
ALTER TABLE public.inspection_requests ADD COLUMN IF NOT EXISTS overall_score numeric(5,2);
ALTER TABLE public.inspection_requests ADD COLUMN IF NOT EXISTS vehicle_condition_rating text;
