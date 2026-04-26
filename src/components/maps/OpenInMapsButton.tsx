import { Button } from "@/components/ui/button";
import { Navigation, ChevronDown } from "lucide-react";
import { platformMaps } from "@/platform";
import { PROVIDER_LABELS, type MapProvider, type MapTarget } from "@/platform/maps";
import { cn } from "@/lib/utils";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";

interface Props {
  target: MapTarget;
  size?: "sm" | "default" | "icon";
  variant?: "outline" | "ghost" | "secondary" | "default";
  iconOnly?: boolean;
  className?: string;
  label?: string;
  /** Hide the provider chooser (right-side caret). */
  hideMenu?: boolean;
}

const PROVIDERS: MapProvider[] = ["auto", "apple", "google", "waze"];

/**
 * Reusable map handoff button — single integration point for CarPlay /
 * Android Auto bindings. Hides itself if no target data exists.
 *
 * Tap → opens the user's preferred provider (set in Settings or via the
 * caret menu here). Long-press / caret → choose provider for this trip.
 */
export function OpenInMapsButton({
  target,
  size = "sm",
  variant = "ghost",
  iconOnly,
  className,
  label = "Navigate",
  hideMenu,
}: Props) {
  const url = platformMaps.buildMapsUrl(target);
  if (!url) return null;

  const main = (
    <Button
      size={iconOnly ? "icon" : size}
      variant={variant}
      onClick={(e) => {
        e.stopPropagation();
        e.preventDefault();
        platformMaps.open(target);
      }}
      className={cn(iconOnly && "h-8 w-8", className)}
      aria-label={label}
      title={label}
    >
      <Navigation className={cn("h-3.5 w-3.5", !iconOnly && "mr-1.5")} />
      {!iconOnly && label}
    </Button>
  );

  // Always defer to the device's default maps app — no provider chooser.
  return main;
}
