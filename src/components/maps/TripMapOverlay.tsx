import { useEffect, useMemo, useRef, useState } from "react";
import { MapContainer, TileLayer, Marker, Popup, Polyline, useMap, CircleMarker } from "react-leaflet";
import L from "leaflet";
import "leaflet/dist/leaflet.css";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { MapPin, Navigation, LocateFixed, X } from "lucide-react";
import { startTracking, type Position } from "@/platform/location";

// Fix default marker icon paths for Leaflet under Vite
delete (L.Icon.Default.prototype as any)._getIconUrl;
L.Icon.Default.mergeOptions({
  iconRetinaUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png",
  iconUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png",
  shadowUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png",
});

const selectedIcon = new L.DivIcon({
  className: "",
  html: `<div style="background:hsl(217 91% 60%);width:18px;height:18px;border-radius:9999px;border:3px solid white;box-shadow:0 0 0 2px hsl(217 91% 60%);"></div>`,
  iconSize: [18, 18],
  iconAnchor: [9, 9],
});

const defaultIcon = new L.DivIcon({
  className: "",
  html: `<div style="background:hsl(215 20% 65%);width:14px;height:14px;border-radius:9999px;border:2px solid white;box-shadow:0 1px 2px rgba(0,0,0,.4);"></div>`,
  iconSize: [14, 14],
  iconAnchor: [7, 7],
});

export interface MapStop {
  id: string;
  label?: string | null;
  address?: string | null;
  latitude?: number | null;
  longitude?: number | null;
}

interface Props {
  stops: MapStop[];
  selectedId?: string | null;
  onSelect?: (id: string) => void;
  className?: string;
}

function FitBounds({ points }: { points: [number, number][] }) {
  const map = useMap();
  useEffect(() => {
    // Force layout recalculation — Leaflet often paints blank when mounted
    // inside flex/grid containers whose height is determined after first paint.
    const ids: number[] = [];
    ids.push(window.setTimeout(() => map.invalidateSize(), 0));
    ids.push(window.setTimeout(() => map.invalidateSize(), 200));
    ids.push(window.setTimeout(() => {
      if (!points.length) return;
      if (points.length === 1) map.setView(points[0], 13);
      else map.fitBounds(L.latLngBounds(points), { padding: [40, 40], maxZoom: 14 });
    }, 50));
    return () => ids.forEach((i) => window.clearTimeout(i));
  }, [points, map]);

  // Re-invalidate on container resize (e.g. orientation change, sidebar toggle)
  useEffect(() => {
    const el = map.getContainer();
    const ro = new ResizeObserver(() => map.invalidateSize());
    ro.observe(el);
    return () => ro.disconnect();
  }, [map]);

  return null;
}

// localStorage cache for geocoded addresses (Nominatim is rate-limited; never re-geocode the same string).
const GEO_CACHE_KEY = "geo:addr-cache:v1";
type GeoCache = Record<string, { lat: number; lon: number } | null>;
function readGeoCache(): GeoCache {
  if (typeof localStorage === "undefined") return {};
  try { return JSON.parse(localStorage.getItem(GEO_CACHE_KEY) || "{}"); } catch { return {}; }
}
function writeGeoCache(c: GeoCache) {
  if (typeof localStorage === "undefined") return;
  try { localStorage.setItem(GEO_CACHE_KEY, JSON.stringify(c)); } catch { /* quota */ }
}

export function TripMapOverlay({ stops, selectedId, onSelect, className }: Props) {
  // Geocode stops that have an address but no coords (cached forever in localStorage).
  const [geocoded, setGeocoded] = useState<Record<string, { lat: number; lon: number }>>({});

  useEffect(() => {
    const needs = stops.filter(
      (s) => (s.latitude == null || s.longitude == null) && (s.address?.trim()?.length ?? 0) > 3,
    );
    if (needs.length === 0) return;
    const cache = readGeoCache();
    let cancelled = false;

    (async () => {
      const next: Record<string, { lat: number; lon: number }> = {};
      for (const s of needs) {
        const key = (s.address || "").trim();
        if (!key) continue;
        // Cache hit (including negative cache → null)
        if (key in cache) {
          if (cache[key]) next[s.id] = cache[key]!;
          continue;
        }
        try {
          const res = await fetch(
            `https://nominatim.openstreetmap.org/search?format=json&limit=1&q=${encodeURIComponent(key)}`,
            { headers: { Accept: "application/json" } },
          );
          const json = await res.json();
          const hit = Array.isArray(json) && json[0];
          if (hit && hit.lat && hit.lon) {
            const v = { lat: Number(hit.lat), lon: Number(hit.lon) };
            cache[key] = v;
            next[s.id] = v;
          } else {
            cache[key] = null;
          }
        } catch {
          // network blip — leave uncached so we can retry next mount
        }
        // be polite: 1 req/sec to Nominatim
        await new Promise((r) => setTimeout(r, 1100));
        if (cancelled) return;
      }
      writeGeoCache(cache);
      if (!cancelled && Object.keys(next).length) {
        setGeocoded((prev) => ({ ...prev, ...next }));
      }
    })();

    return () => { cancelled = true; };
  }, [stops]);

  // Merge live coords with geocoded fallbacks
  const resolvedStops = useMemo(
    () =>
      stops.map((s) => {
        if (s.latitude != null && s.longitude != null) return s;
        const g = geocoded[s.id];
        if (g) return { ...s, latitude: g.lat, longitude: g.lon };
        return s;
      }),
    [stops, geocoded],
  );

  const points = useMemo(
    () =>
      resolvedStops
        .filter((s) => s.latitude != null && s.longitude != null)
        .map((s) => [Number(s.latitude), Number(s.longitude)] as [number, number]),
    [resolvedStops],
  );

  const containerRef = useRef<HTMLDivElement>(null);

  // Road-following route geometry from OSRM public demo. Falls back to
  // straight-line connectors if the request fails or returns no route.
  const [routeGeometry, setRouteGeometry] = useState<[number, number][] | null>(null);

  useEffect(() => {
    if (points.length < 2) { setRouteGeometry(null); return; }
    let cancelled = false;
    const coords = points.map(([lat, lon]) => `${lon},${lat}`).join(";");
    const url = `https://router.project-osrm.org/route/v1/driving/${coords}?overview=full&geometries=geojson`;
    (async () => {
      try {
        const res = await fetch(url);
        if (!res.ok) throw new Error(String(res.status));
        const json = await res.json();
        const line = json?.routes?.[0]?.geometry?.coordinates;
        if (!cancelled && Array.isArray(line) && line.length) {
          setRouteGeometry(line.map((c: [number, number]) => [c[1], c[0]]));
        } else if (!cancelled) {
          setRouteGeometry(null);
        }
      } catch {
        if (!cancelled) setRouteGeometry(null);
      }
    })();
    return () => { cancelled = true; };
  }, [points]);

  const pendingGeocode = stops.some(
    (s) => (s.latitude == null || s.longitude == null) && (s.address?.trim()?.length ?? 0) > 3 && !geocoded[s.id],
  );

  if (points.length === 0) {
    return (
      <Card className={className}>
        <CardContent className="p-6 text-center min-h-[260px] flex flex-col items-center justify-center text-sm text-muted-foreground">
          <MapPin className="h-6 w-6 mb-2" />
          {pendingGeocode ? (
            <>
              <p>Locating stops…</p>
              <p className="text-xs mt-1">Looking up addresses on the map.</p>
            </>
          ) : (
            <>
              <p>No mapped stops yet.</p>
              <p className="text-xs mt-1">Add an address (with location lookup) to see stops on the map.</p>
            </>
          )}
        </CardContent>
      </Card>
    );
  }

  return (
    <Card className={className} ref={containerRef as any}>
      <CardContent className="p-0 overflow-hidden rounded-lg">
        {/* Explicit pixel height — Leaflet requires an absolute height to paint */}
        <div className="relative w-full" style={{ height: 320 }}>
          <MapContainer
            center={points[0]}
            zoom={12}
            scrollWheelZoom={false}
            style={{ height: "100%", width: "100%", position: "absolute", inset: 0 }}
          >
            <TileLayer
              attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
              url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
            />
            <FitBounds points={points} />
            {points.length > 1 && (
              <Polyline
                positions={routeGeometry ?? points}
                pathOptions={{
                  color: "hsl(217, 91%, 60%)",
                  weight: 4,
                  opacity: routeGeometry ? 0.75 : 0.45,
                  dashArray: routeGeometry ? undefined : "6 6",
                }}
              />
            )}
            {resolvedStops.map((s) => {
              if (s.latitude == null || s.longitude == null) return null;
              const isSelected = s.id === selectedId;
              return (
                <Marker
                  key={s.id}
                  position={[Number(s.latitude), Number(s.longitude)]}
                  icon={isSelected ? selectedIcon : defaultIcon}
                  eventHandlers={{ click: () => onSelect?.(s.id) }}
                >
                  <Popup>
                    <div className="text-xs">
                      <div className="font-medium">{s.label || "Stop"}</div>
                      {s.address && <div className="text-muted-foreground mt-0.5">{s.address}</div>}
                    </div>
                  </Popup>
                </Marker>
              );
            })}
          </MapContainer>
        </div>
      </CardContent>
    </Card>
  );
}
