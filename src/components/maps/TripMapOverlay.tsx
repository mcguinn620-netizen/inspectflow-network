import { useEffect, useMemo, useRef, useState } from "react";
import { MapContainer, TileLayer, Marker, Popup, Polyline, useMap, CircleMarker } from "react-leaflet";
import L from "leaflet";
import "leaflet/dist/leaflet.css";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { MapPin, Navigation, LocateFixed, X } from "lucide-react";
import { startTracking, type Position } from "@/platform/location";
import { cn } from "@/lib/utils";

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
  fullscreen?: boolean;
  actualRoutePoints?: Array<{ latitude: number; longitude: number }>;
}

function FitBounds({ points }: { points: [number, number][] }) {
  const map = useMap();
  useEffect(() => {
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

  useEffect(() => {
    const el = map.getContainer();
    const ro = new ResizeObserver(() => map.invalidateSize());
    ro.observe(el);
    return () => ro.disconnect();
  }, [map]);

  return null;
}

export function TripMapOverlay({
  stops,
  selectedId,
  onSelect,
  className,
  fullscreen = false,
  actualRoutePoints = [],
}: Props) {
  const points = useMemo(
    () =>
      stops
        .filter((s) => s.latitude != null && s.longitude != null)
        .map((s) => [Number(s.latitude), Number(s.longitude)] as [number, number]),
    [stops],
  );

  const breadcrumbLine = useMemo(
    () => actualRoutePoints.map((p) => [Number(p.latitude), Number(p.longitude)] as [number, number]),
    [actualRoutePoints],
  );

  const [routeGeometry, setRouteGeometry] = useState<[number, number][] | null>(null);

  useEffect(() => {
    if (points.length < 2 || breadcrumbLine.length > 1) {
      setRouteGeometry(null);
      return;
    }
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
    return () => {
      cancelled = true;
    };
  }, [points, breadcrumbLine.length]);

  const displayLine = breadcrumbLine.length > 1 ? breadcrumbLine : routeGeometry ?? points;
  const isActualRoute = breadcrumbLine.length > 1;
  const isPlannedRoute = !isActualRoute && !!routeGeometry?.length;

  const [navigating, setNavigating] = useState(fullscreen);
  const [userPos, setUserPos] = useState<Position | null>(null);
  const mapInstanceRef = useRef<L.Map | null>(null);

  useEffect(() => {
    if (!navigating) return;
    const stop = startTracking((p) => {
      setUserPos(p);
      const m = mapInstanceRef.current;
      if (m) m.setView([p.latitude, p.longitude], Math.max(m.getZoom(), 15), { animate: true });
    });
    return stop;
  }, [navigating]);

  if (points.length === 0 && breadcrumbLine.length === 0) {
    return (
      <Card className={cn(className, "w-full max-w-full overflow-hidden")}>
        <CardContent className="p-6 text-center min-h-[200px] flex flex-col items-center justify-center text-sm text-muted-foreground">
          <MapPin className="h-6 w-6 mb-2" />
          <p>No mapped stops yet.</p>
        </CardContent>
      </Card>
    );
  }

  const mapBlock = (
    <div className={cn("relative w-full", fullscreen ? "h-full" : "h-[220px] sm:h-[280px] lg:h-[320px]")}>
      <MapContainer
        center={displayLine[0] ?? points[0]}
        zoom={12}
        scrollWheelZoom={false}
        style={{ height: "100%", width: "100%", position: "absolute", inset: 0 }}
        ref={(m) => {
          mapInstanceRef.current = m as unknown as L.Map;
        }}
      >
        <TileLayer
          attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
          url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
        />
        <FitBounds points={navigating ? [] : [...displayLine, ...points]} />
        {displayLine.length > 1 && (
          <Polyline
            positions={displayLine}
            pathOptions={{
              color: "hsl(217, 91%, 60%)",
              weight: 4,
              opacity: isActualRoute ? 0.9 : isPlannedRoute ? 0.75 : 0.45,
              dashArray: isActualRoute ? undefined : isPlannedRoute ? undefined : "6 6",
            }}
          />
        )}
        {stops.map((s) => {
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
        {userPos && (
          <CircleMarker
            center={[userPos.latitude, userPos.longitude]}
            radius={7}
            pathOptions={{ color: "white", weight: 2, fillColor: "hsl(217, 91%, 60%)", fillOpacity: 1 }}
          />
        )}
      </MapContainer>

      <div className="absolute top-2 right-2 z-[400] flex flex-col gap-1.5">
        {!navigating && !fullscreen ? (
          <Button size="sm" variant="default" className="h-8 shadow-md" onClick={() => setNavigating(true)}>
            <Navigation className="h-3.5 w-3.5 mr-1" />
            Navigate
          </Button>
        ) : (
          <>
            <Button
              size="icon"
              variant="secondary"
              className="h-8 w-8 shadow-md"
              onClick={() => {
                if (userPos && mapInstanceRef.current) {
                  mapInstanceRef.current.setView([userPos.latitude, userPos.longitude], Math.max(mapInstanceRef.current.getZoom(), 15));
                }
              }}
            >
              <LocateFixed className="h-4 w-4" />
            </Button>
            {!fullscreen && (
              <Button size="icon" variant="secondary" className="h-8 w-8 shadow-md" onClick={() => setNavigating(false)}>
                <X className="h-4 w-4" />
              </Button>
            )}
          </>
        )}
      </div>
    </div>
  );

  return fullscreen ? mapBlock : <Card className={cn(className, "overflow-hidden")}>{mapBlock}</Card>;
}
