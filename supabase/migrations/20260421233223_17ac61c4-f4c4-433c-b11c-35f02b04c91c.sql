
-- Phase 2: extend trip and stop state machines

-- Trip status: planned/active are existing values; add 'paused' and 'completed' (already used).
-- Add timestamps for trip lifecycle and a job link on stops.
ALTER TABLE public.trips
  ADD COLUMN IF NOT EXISTS started_at timestamptz,
  ADD COLUMN IF NOT EXISTS paused_at timestamptz,
  ADD COLUMN IF NOT EXISTS completed_at timestamptz;

-- Stop state model
ALTER TABLE public.trip_stops
  ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS completed_at timestamptz;

-- Lightweight validation triggers (not CHECK, per instructions)
CREATE OR REPLACE FUNCTION public.validate_trip_status()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  IF NEW.status NOT IN ('draft','planned','active','paused','completed','canceled') THEN
    RAISE EXCEPTION 'Invalid trip status: %', NEW.status;
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trips_validate_status ON public.trips;
CREATE TRIGGER trips_validate_status BEFORE INSERT OR UPDATE ON public.trips
  FOR EACH ROW EXECUTE FUNCTION public.validate_trip_status();

CREATE OR REPLACE FUNCTION public.validate_trip_stop_status()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  IF NEW.status NOT IN ('pending','arrived','completed','skipped') THEN
    RAISE EXCEPTION 'Invalid trip stop status: %', NEW.status;
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trip_stops_validate_status ON public.trip_stops;
CREATE TRIGGER trip_stops_validate_status BEFORE INSERT OR UPDATE ON public.trip_stops
  FOR EACH ROW EXECUTE FUNCTION public.validate_trip_stop_status();

-- Helpful index for "build trip from today" lookups
CREATE INDEX IF NOT EXISTS idx_trip_stops_job_id ON public.trip_stops(job_id);
CREATE INDEX IF NOT EXISTS idx_trips_user_status ON public.trips(user_id, status);
