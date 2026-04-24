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

  if (hideMenu || iconOnly) return main;

  return (
    <div className="inline-flex">
      {main}
      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <Button
            variant={variant}
            size="icon"
            className="h-8 w-7 -ml-1"
            onClick={(e) => e.stopPropagation()}
            aria-label="Choose maps app"
          >
            <ChevronDown className="h-3 w-3" />
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end">
          <DropdownMenuLabel className="text-xs">Open with</DropdownMenuLabel>
          <DropdownMenuSeparator />
          {PROVIDERS.map((p) => (
            <DropdownMenuItem
              key={p}
              onClick={(e) => {
                e.stopPropagation();
                platformMaps.open(target, p);
              }}
            >
              {PROVIDER_LABELS[p]}
            </DropdownMenuItem>
          ))}
        </DropdownMenuContent>
      </DropdownMenu>
    </div>
  );
}
