import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { BrowserRouter, Route, Routes, Navigate } from "react-router-dom";
import { Toaster as Sonner } from "@/components/ui/sonner";
import { Toaster } from "@/components/ui/toaster";
import { TooltipProvider } from "@/components/ui/tooltip";
import { InstallPrompt } from "@/components/InstallPrompt";
import { AuthProvider, useAuth } from "@/hooks/useAuth";
import { ThemeProvider } from "@/components/ThemeProvider";
import { useUserRoles } from "@/hooks/useUserRoles";
import { ActiveTripProvider } from "@/hooks/useActiveTrip";
import Index from "./pages/Index";
import AuthPage from "./pages/Auth";
import DispatchPage from "./pages/Dispatch";
import InspectorsPage from "./pages/Inspectors";
import VehiclesPage from "./pages/Vehicles";
import MarketplacePage from "./pages/Marketplace";
import InspectionsPage from "./pages/Inspections";
import {
  ReportsPage,
  RepairShopPage,
  ClientPortalPage,
} from "./pages/PlaceholderPages";
import SettingsPage from "./pages/Settings";
import NotFound from "./pages/NotFound";
import InspectorDashboard from "./pages/inspector/InspectorDashboard";
import InspectorSchedule from "./pages/inspector/InspectorSchedule";
import InspectorJobs from "./pages/inspector/InspectorJobs";
import InspectorTrips from "./pages/inspector/InspectorTrips";
import InspectorTax from "./pages/inspector/InspectorTax";
import MechanicDashboard from "./pages/mechanic/MechanicDashboard";
import DispatchDashboard from "./pages/dispatch/DispatchDashboard";
import { RoleRoute } from "./components/RoleRoute";

const queryClient = new QueryClient();

function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const { user, loading } = useAuth();
  if (loading) return <div className="min-h-screen flex items-center justify-center bg-background"><div className="animate-spin h-8 w-8 border-2 border-primary border-t-transparent rounded-full" /></div>;
  if (!user) return <Navigate to="/auth" replace />;
  return <>{children}</>;
}

function HomeRedirect() {
  const { isAdmin, loading } = useUserRoles();
  if (loading) return <div className="min-h-screen flex items-center justify-center bg-background"><div className="animate-spin h-8 w-8 border-2 border-primary border-t-transparent rounded-full" /></div>;
  return isAdmin ? <Index /> : <Navigate to="/app/inspector/dashboard" replace />;
}

const AppRoutes = () => (
  <Routes>
    <Route path="/auth" element={<AuthPage />} />
    <Route path="/" element={<ProtectedRoute><HomeRedirect /></ProtectedRoute>} />

    {/* Inspector workspace */}
    <Route path="/app/inspector/dashboard" element={<ProtectedRoute><InspectorDashboard /></ProtectedRoute>} />
    <Route path="/app/inspector/schedule" element={<ProtectedRoute><InspectorSchedule /></ProtectedRoute>} />
    <Route path="/app/inspector/jobs" element={<ProtectedRoute><InspectorJobs /></ProtectedRoute>} />
    <Route path="/app/inspector/trips" element={<ProtectedRoute><InspectorTrips /></ProtectedRoute>} />
    <Route path="/app/inspector/tax" element={<ProtectedRoute><InspectorTax /></ProtectedRoute>} />

    {/* Future role workspaces */}
    <Route path="/app/mechanic/dashboard" element={<ProtectedRoute><RoleRoute role="mechanic"><MechanicDashboard /></RoleRoute></ProtectedRoute>} />
    <Route path="/app/dispatch/dashboard" element={<ProtectedRoute><RoleRoute role="dispatcher"><DispatchDashboard /></RoleRoute></ProtectedRoute>} />

    {/* Existing admin/ops pages */}
    <Route path="/dispatch" element={<ProtectedRoute><DispatchPage /></ProtectedRoute>} />
    <Route path="/marketplace" element={<ProtectedRoute><MarketplacePage /></ProtectedRoute>} />
    <Route path="/inspections" element={<ProtectedRoute><InspectionsPage /></ProtectedRoute>} />
    <Route path="/inspectors" element={<ProtectedRoute><InspectorsPage /></ProtectedRoute>} />
    <Route path="/vehicles" element={<ProtectedRoute><VehiclesPage /></ProtectedRoute>} />
    <Route path="/reports" element={<ProtectedRoute><ReportsPage /></ProtectedRoute>} />
    <Route path="/repair-shop" element={<ProtectedRoute><RepairShopPage /></ProtectedRoute>} />
    <Route path="/client-portal" element={<ProtectedRoute><ClientPortalPage /></ProtectedRoute>} />
    <Route path="/settings" element={<ProtectedRoute><SettingsPage /></ProtectedRoute>} />
    <Route path="*" element={<NotFound />} />
  </Routes>
);

const App = () => (
  <QueryClientProvider client={queryClient}>
    <ThemeProvider attribute="class" defaultTheme="system" enableSystem>
      <TooltipProvider>
        <Toaster />
        <Sonner />
        <BrowserRouter>
          <AuthProvider>
            <ActiveTripProvider>
              <AppRoutes />
              <InstallPrompt />
            </ActiveTripProvider>
          </AuthProvider>
        </BrowserRouter>
      </TooltipProvider>
    </ThemeProvider>
  </QueryClientProvider>
);

export default App;
