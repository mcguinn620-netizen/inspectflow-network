import { AlertTriangle, X, UserCog } from "lucide-react";
import { Link } from "react-router-dom";
import { useDebugUser } from "@/hooks/useDebugUser";
import { roleLabel } from "@/lib/debugAuth";

export function DebugBanner() {
  const { debugUser, enabled, clearDebugUser } = useDebugUser();
  if (!enabled || !debugUser) return null;

  return (
    <div
      className="sticky top-0 z-[60] w-full bg-amber-500 text-amber-950 border-b border-amber-600"
      role="status"
      aria-label="Debug user mode active"
    >
      <div className="flex items-center justify-between gap-3 px-3 py-1.5 text-xs sm:text-sm font-medium">
        <div className="flex items-center gap-2 min-w-0">
          <AlertTriangle className="h-4 w-4 shrink-0" />
          <span className="font-bold tracking-wide shrink-0">DEBUG USER MODE</span>
          <span className="truncate opacity-90">
            — {debugUser.full_name ?? debugUser.id} ({roleLabel(debugUser.role)})
            {debugUser.organization_name ? ` · ${debugUser.organization_name}` : ""}
          </span>
        </div>
        <div className="flex items-center gap-1 shrink-0">
          <Link
            to="/debug"
            className="inline-flex items-center gap-1 rounded px-2 py-1 hover:bg-amber-600/30"
          >
            <UserCog className="h-3.5 w-3.5" /> Switch
          </Link>
          <button
            onClick={clearDebugUser}
            className="inline-flex items-center gap-1 rounded px-2 py-1 hover:bg-amber-600/30"
            aria-label="Clear debug user"
          >
            <X className="h-3.5 w-3.5" /> Clear
          </button>
        </div>
      </div>
    </div>
  );
}
