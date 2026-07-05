import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { AUTH_BYPASS, clearMockUser, getMockUser } from "@/lib/authBypass";
import { Button } from "@/components/ui/button";

export function DevRoleSwitcher() {
  const navigate = useNavigate();
  const [user, setUser] = useState(() => getMockUser());

  useEffect(() => {
    const handler = () => setUser(getMockUser());
    window.addEventListener("mock-auth-change", handler);
    window.addEventListener("storage", handler);
    return () => {
      window.removeEventListener("mock-auth-change", handler);
      window.removeEventListener("storage", handler);
    };
  }, []);

  if (!AUTH_BYPASS || !user) return null;

  return (
    <div className="fixed bottom-4 right-4 z-50 flex items-center gap-2 rounded-full border bg-background/95 backdrop-blur px-3 py-1.5 shadow-lg">
      <span className="text-xs text-muted-foreground">Role:</span>
      <span className="text-xs font-mono font-semibold">{user.role}</span>
      <Button
        size="sm"
        variant="ghost"
        className="h-7 text-xs"
        onClick={() => {
          clearMockUser();
          navigate("/pick-role");
        }}
      >
        Switch
      </Button>
    </div>
  );
}
