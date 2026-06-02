import { Navigate } from "react-router-dom";
import { DebugUserPicker } from "@/components/debug/DebugUserPicker";
import { isDebugMode } from "@/lib/debugAuth";

export default function DebugLogin() {
  if (!isDebugMode()) return <Navigate to="/auth" replace />;
  return (
    <div className="min-h-screen bg-background">
      <DebugUserPicker redirectTo="/" />
    </div>
  );
}
