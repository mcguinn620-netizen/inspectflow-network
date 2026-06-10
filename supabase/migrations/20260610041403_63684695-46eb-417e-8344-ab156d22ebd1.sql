ALTER TABLE public.trips ADD COLUMN IF NOT EXISTS note text;
ALTER TABLE public.trips ADD COLUMN IF NOT EXISTS job_category text;