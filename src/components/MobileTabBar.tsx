import { NavLink, useLocation } from "react-router-dom";
import { LayoutDashboard, CalendarDays, Route, Briefcase, Receipt } from "lucide-react";
import { useUserRoles } from "@/hooks/useUserRoles";
import { cn } from "@/lib/utils";

const tabs = [
  { to: "/app/inspector/dashboard", label: "Home", icon: LayoutDashboard },
  { to: "/app/inspector/schedule", label: "Schedule", icon: CalendarDays },
  { to: "/app/inspector/trips", label: "Trips", icon: Route, primary: true },
  { to: "/app/inspector/jobs", label: "Jobs", icon: Briefcase },
  { to: "/app/inspector/tax", label: "Tax", icon: Receipt },
];

/**
 * Mobile-only bottom tab bar for the inspector workspace.
 * - Hidden on desktop (md+)
 * - Hidden on auth & non-inspector pages
 * - Safe-area aware via env(safe-area-inset-bottom)
 * - Uses fixed positioning; the layout adds bottom padding so content doesn't hide.
 */
export function MobileTabBar() {
  const { hasRole, isAdmin } = useUserRoles();
  const { pathname } = useLocation();

  if (!pathname.startsWith("/app/inspector") && !pathname.startsWith("/app/")) return null;
  if (!hasRole("inspector") && !isAdmin) return null;

  return (
    <nav
      className={cn(
        "md:hidden fixed inset-x-0 bottom-0 z-40 border-t bg-card/95 backdrop-blur",
        "supports-[backdrop-filter]:bg-card/80",
      )}
      style={{ paddingBottom: "env(safe-area-inset-bottom)" }}
      aria-label="Inspector navigation"
    >
      <ul className="grid grid-cols-5">
        {tabs.map((t) => (
          <li key={t.to}>
            <NavLink
              to={t.to}
              className={({ isActive }) =>
                cn(
                  "flex flex-col items-center justify-center gap-0.5 py-2 text-[10px] font-medium min-h-[56px]",
                  "transition-colors active:bg-muted/60",
                  isActive ? "text-primary" : "text-muted-foreground hover:text-foreground",
                )
              }
            >
              {({ isActive }) => (
                <>
                  <span
                    className={cn(
                      "flex items-center justify-center rounded-full",
                      t.primary ? "h-9 w-9 -mt-1" : "h-6 w-6",
                      t.primary && isActive && "bg-primary text-primary-foreground shadow-md",
                      t.primary && !isActive && "bg-muted text-foreground",
                    )}
                  >
                    <t.icon className={t.primary ? "h-4 w-4" : "h-5 w-5"} />
                  </span>
                  <span>{t.label}</span>
                </>
              )}
            </NavLink>
          </li>
        ))}
      </ul>
    </nav>
  );
}
