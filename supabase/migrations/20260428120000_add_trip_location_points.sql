CREATE TABLE IF NOT EXISTS public.trip_location_points (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id uuid NOT NULL REFERENCES public.trips(id) ON DELETE CASCADE,
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  user_id uuid NOT NULL,
  latitude numeric NOT NULL,
  longitude numeric NOT NULL,
  accuracy numeric,
  speed numeric,
  heading numeric,
  distance_from_previous_miles numeric NOT NULL DEFAULT 0,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_trip_location_points_trip_recorded
  ON public.trip_location_points(trip_id, recorded_at);
CREATE INDEX IF NOT EXISTS idx_trip_location_points_user_recorded
  ON public.trip_location_points(user_id, recorded_at);
CREATE INDEX IF NOT EXISTS idx_trip_location_points_org_recorded
  ON public.trip_location_points(organization_id, recorded_at);

ALTER TABLE public.trip_location_points ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "org members manage trip_location_points" ON public.trip_location_points;
CREATE POLICY "org members manage trip_location_points"
  ON public.trip_location_points
  FOR ALL
  TO authenticated
  USING (public.is_org_member(organization_id))
  WITH CHECK (public.is_org_member(organization_id) AND user_id = auth.uid());
