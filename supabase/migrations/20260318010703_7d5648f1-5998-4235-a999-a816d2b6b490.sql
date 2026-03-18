
-- Create storage bucket for intake source files
INSERT INTO storage.buckets (id, name, public) VALUES ('intake-files', 'intake-files', false);

-- Storage policies for intake files
CREATE POLICY "Authenticated users can upload intake files"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'intake-files');

CREATE POLICY "Authenticated users can view intake files"
ON storage.objects FOR SELECT TO authenticated
USING (bucket_id = 'intake-files');

-- Inspection requests table
CREATE TABLE public.inspection_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_name TEXT,
  company_name TEXT,
  vin TEXT,
  vehicle_year TEXT,
  vehicle_make TEXT,
  vehicle_model TEXT,
  mileage TEXT,
  inspection_location TEXT,
  requested_date TEXT,
  inspection_type TEXT,
  template_name TEXT,
  priority TEXT DEFAULT 'medium',
  status TEXT DEFAULT 'request_received',
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.inspection_requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can manage inspection_requests"
ON public.inspection_requests FOR ALL TO authenticated
USING (true) WITH CHECK (true);

-- Parsed documents table
CREATE TABLE public.parsed_documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  inspection_request_id UUID REFERENCES public.inspection_requests(id) ON DELETE CASCADE,
  source_type TEXT NOT NULL, -- 'email', 'pdf', 'image'
  original_text TEXT,
  parsed_data JSONB,
  source_file_path TEXT,
  source_file_name TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.parsed_documents ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can manage parsed_documents"
ON public.parsed_documents FOR ALL TO authenticated
USING (true) WITH CHECK (true);
