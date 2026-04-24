import { useEffect, useRef, useState } from "react";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { Loader2, MapPin, LocateFixed } from "lucide-react";
import { cn } from "@/lib/utils";
import { platformLocation } from "@/platform";

export interface ResolvedLocation {
  address: string;
  latitude?: number | null;
  longitude?: number | null;
}

interface Suggestion {
  display_name: string;
  lat: string;
  lon: string;
}

interface Props {
  value: string;
  onChange: (next: ResolvedLocation) => void;
  placeholder?: string;
  className?: string;
  /** Show "Use my current location" button (default true) */
  showCurrent?: boolean;
  /** Disable input */
  disabled?: boolean;
  id?: string;
}

/**
 * Address lookup field powered by OpenStreetMap Nominatim (free, no key).
 * Debounced typeahead + reverse-geocode for "use my location".
 * Returns { address, latitude, longitude } so call sites can persist coords.
 *
 * Capacitor-ready: location reads go through `platformLocation.getCurrent()`.
 */
export function LocationAutocomplete({
  value,
  onChange,
  placeholder = "Start typing an address…",
  className,
  showCurrent = true,
  disabled,
  id,
}: Props) {
  const [text, setText] = useState(value);
  const [items, setItems] = useState<Suggestion[]>([]);
  const [open, setOpen] = useState(false);
  const [loading, setLoading] = useState(false);
  const [locating, setLocating] = useState(false);
  const debounceRef = useRef<number | null>(null);
  const wrapRef = useRef<HTMLDivElement>(null);

  // keep external value in sync
  useEffect(() => { setText(value); }, [value]);

  // close on outside click
  useEffect(() => {
    const handler = (e: MouseEvent) => {
      if (!wrapRef.current?.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener("mousedown", handler);
    return () => document.removeEventListener("mousedown", handler);
  }, []);

  const search = async (q: string) => {
    if (q.trim().length < 3) { setItems([]); return; }
    setLoading(true);
    try {
      const res = await fetch(
        `https://nominatim.openstreetmap.org/search?format=json&addressdetails=0&limit=5&q=${encodeURIComponent(q)}`,
        { headers: { Accept: "application/json" } },
      );
      const data = (await res.json()) as Suggestion[];
      setItems(data || []);
      setOpen(true);
    } catch {
      setItems([]);
    } finally {
      setLoading(false);
    }
  };

  const handleType = (next: string) => {
    setText(next);
    if (debounceRef.current) window.clearTimeout(debounceRef.current);
    debounceRef.current = window.setTimeout(() => search(next), 350);
  };

  const pick = (s: Suggestion) => {
    setText(s.display_name);
    setOpen(false);
    onChange({ address: s.display_name, latitude: Number(s.lat), longitude: Number(s.lon) });
  };

  const useMyLocation = async () => {
    setLocating(true);
    try {
      const pos = await platformLocation.getCurrent();
      if (!pos) return;
      const res = await fetch(
        `https://nominatim.openstreetmap.org/reverse?format=json&lat=${pos.latitude}&lon=${pos.longitude}`,
        { headers: { Accept: "application/json" } },
      );
      const data = await res.json();
      const addr = data?.display_name || `${pos.latitude.toFixed(5)}, ${pos.longitude.toFixed(5)}`;
      setText(addr);
      onChange({ address: addr, latitude: pos.latitude, longitude: pos.longitude });
    } finally {
      setLocating(false);
    }
  };

  return (
    <div ref={wrapRef} className={cn("relative", className)}>
      <div className="flex gap-1.5">
        <div className="relative flex-1">
          <MapPin className="absolute left-2.5 top-1/2 -translate-y-1/2 h-3.5 w-3.5 text-muted-foreground pointer-events-none" />
          <Input
            id={id}
            value={text}
            disabled={disabled}
            placeholder={placeholder}
            onChange={(e) => handleType(e.target.value)}
            onBlur={() => onChange({ address: text })}
            onFocus={() => items.length && setOpen(true)}
            className="pl-8"
            autoComplete="off"
          />
          {loading && (
            <Loader2 className="absolute right-2.5 top-1/2 -translate-y-1/2 h-3.5 w-3.5 animate-spin text-muted-foreground" />
          )}
        </div>
        {showCurrent && (
          <Button
            type="button"
            variant="outline"
            size="icon"
            onClick={useMyLocation}
            disabled={disabled || locating}
            title="Use my location"
            aria-label="Use my location"
          >
            {locating ? <Loader2 className="h-3.5 w-3.5 animate-spin" /> : <LocateFixed className="h-3.5 w-3.5" />}
          </Button>
        )}
      </div>
      {open && items.length > 0 && (
        <div className="absolute z-50 mt-1 w-full rounded-md border bg-popover shadow-md max-h-60 overflow-y-auto">
          {items.map((s, i) => (
            <button
              key={`${s.lat}-${s.lon}-${i}`}
              type="button"
              onClick={() => pick(s)}
              className="block w-full text-left px-3 py-2 text-xs hover:bg-accent border-b last:border-b-0"
            >
              <div className="font-medium line-clamp-1">{s.display_name.split(",")[0]}</div>
              <div className="text-muted-foreground line-clamp-1">{s.display_name}</div>
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
