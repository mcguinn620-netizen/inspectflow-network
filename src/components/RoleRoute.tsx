import { Navigate } from "react-router-dom";
import { useUserRoles, type AppRole } from "@/hooks/useUserRoles";

/**
 * Role-guarded route. If the user lacks the role and isn't an admin,
 * redirect to a safe default. Loading state mirrors ProtectedRoute.
 */
export function RoleRoute({
  role,
  children,
  fallback = "/app/inspector/dashboard",
}: {
  role: AppRole;
  children: React.ReactNode;
  fallback?: string;
}) {
  const { hasRole, isAdmin, loading } = useUserRoles();
  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-background">
        <div className="animate-spin h-8 w-8 border-2 border-primary border-t-transparent rounded-full" />
      </div>
    );
  }
  if (!hasRole(role) && !isAdmin) return <Navigate to={fallback} replace />;
  return <>{children}</>;
}
