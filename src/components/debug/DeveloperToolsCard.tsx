import { useDebugUser } from "@/hooks/useDebugUser";
import { roleBadgeClasses, roleLabel } from "@/lib/debugAuth";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Link } from "react-router-dom";
import { AlertTriangle, UserCog, X, RotateCcw } from "lucide-react";

/**
 * DEV-only Developer Tools card. Renders nothing in production builds.
 */
export function DeveloperToolsCard() {
  const { debugUser, enabled, clearDebugUser } = useDebugUser();
  if (!enabled) return null;

  return (
    <Card className="border-amber-500/40">
      <CardHeader>
        <div className="flex items-center gap-2">
          <AlertTriangle className="h-4 w-4 text-amber-600 dark:text-amber-400" />
          <CardTitle className="text-base">Developer Tools</CardTitle>
        </div>
        <CardDescription>
          Development build only. These controls are stripped from production.
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        {debugUser ? (
          <>
            <dl className="grid grid-cols-1 sm:grid-cols-3 gap-3 text-sm">
              <div>
                <dt className="text-xs text-muted-foreground">Current User</dt>
                <dd className="font-medium truncate">{debugUser.full_name ?? debugUser.id}</dd>
              </div>
              <div>
                <dt className="text-xs text-muted-foreground">Current Role</dt>
                <dd>
                  <span
                    className={`inline-flex items-center rounded-full border px-2 py-0.5 text-xs font-semibold ${roleBadgeClasses(debugUser.role)}`}
                  >
                    {roleLabel(debugUser.role)}
                  </span>
                </dd>
              </div>
              <div>
                <dt className="text-xs text-muted-foreground">Current Organization</dt>
                <dd className="font-medium truncate">{debugUser.organization_name ?? "—"}</dd>
              </div>
            </dl>
            <div className="flex flex-wrap gap-2 pt-2 border-t">
              <Button asChild variant="outline" size="sm">
                <Link to="/debug"><UserCog className="h-4 w-4 mr-1.5" />Switch User</Link>
              </Button>
              <Button variant="outline" size="sm" onClick={clearDebugUser}>
                <X className="h-4 w-4 mr-1.5" />Clear User
              </Button>
              <Button
                variant="outline"
                size="sm"
                onClick={() => {
                  clearDebugUser();
                  window.location.href = "/debug";
                }}
              >
                <RotateCcw className="h-4 w-4 mr-1.5" />Reset Debug Session
              </Button>
            </div>
          </>
        ) : (
          <div className="flex items-center justify-between gap-3">
            <p className="text-sm text-muted-foreground">No debug user selected.</p>
            <Button asChild size="sm">
              <Link to="/debug">Pick Debug User</Link>
            </Button>
          </div>
        )}
      </CardContent>
    </Card>
  );
}
