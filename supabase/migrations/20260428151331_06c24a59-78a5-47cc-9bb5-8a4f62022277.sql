CREATE TABLE IF NOT EXISTS public.trip_location_points (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  trip_id uuid NOT NULL,
  organization_id uuid NOT NULL,
  user_id uuid NOT NULL,
  latitude double precision NOT NULL,
  longitude double precision NOT NULL,
  accuracy double precision,
  speed double precision,
  heading double precision,
  distance_from_previous_miles numeric DEFAULT 0,
  recorded_at timestamp with time zone NOT NULL DEFAULT now(),
  created_at timestamp with time zone NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_trip_location_points_trip_id_recorded_at
  ON public.trip_location_points (trip_id, recorded_at DESC);

CREATE INDEX IF NOT EXISTS idx_trip_location_points_org
  ON public.trip_location_points (organization_id);

ALTER TABLE public.trip_location_points ENABLE ROW LEVEL SECURITY;

CREATE POLICY "org members manage trip_location_points"
  ON public.trip_location_points
  FOR ALL
  TO authenticated
  USING (public.is_org_member(organization_id))
  WITH CHECK (public.is_org_member(organization_id));