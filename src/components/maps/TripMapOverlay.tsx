import { useEffect, useMemo, useRef } from "react";
import { MapContainer, TileLayer, Marker, Popup, Polyline, useMap } from "react-leaflet";
import L from "leaflet";
import "leaflet/dist/leaflet.css";
import { Card, CardContent } from "@/components/ui/card";
import { MapPin } from "lucide-react";

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
    if (!points.length) return;
    if (points.length === 1) {
      map.setView(points[0], 13);
      return;
    }
    map.fitBounds(L.latLngBounds(points), { padding: [40, 40], maxZoom: 14 });
  }, [points, map]);
  return null;
}

export function TripMapOverlay({ stops, selectedId, onSelect, className }: Props) {
  const points = useMemo(
    () =>
      stops
        .filter((s) => s.latitude != null && s.longitude != null)
        .map((s) => [Number(s.latitude), Number(s.longitude)] as [number, number]),
    [stops],
  );

  const containerRef = useRef<HTMLDivElement>(null);

  if (points.length === 0) {
    return (
      <Card className={className}>
        <CardContent className="p-6 text-center min-h-[260px] flex flex-col items-center justify-center text-sm text-muted-foreground">
          <MapPin className="h-6 w-6 mb-2" />
          <p>No mapped stops yet.</p>
          <p className="text-xs mt-1">Add coordinates to stops to see them on the map.</p>
        </CardContent>
      </Card>
    );
  }

  return (
    <Card className={className} ref={containerRef as any}>
      <CardContent className="p-0 overflow-hidden rounded-lg">
        <div style={{ height: 320, width: "100%" }}>
          <MapContainer
            center={points[0]}
            zoom={12}
            scrollWheelZoom={false}
            style={{ height: "100%", width: "100%" }}
          >
            <TileLayer
              attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
              url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
            />
            <FitBounds points={points} />
            {points.length > 1 && (
              <Polyline positions={points} pathOptions={{ color: "hsl(217, 91%, 60%)", weight: 3, opacity: 0.6 }} />
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
          </MapContainer>
        </div>
      </CardContent>
    </Card>
  );
}
