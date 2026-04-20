import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { BrowserRouter, Route, Routes, Navigate } from "react-router-dom";
import { Toaster as Sonner } from "@/components/ui/sonner";
import { Toaster } from "@/components/ui/toaster";
import { TooltipProvider } from "@/components/ui/tooltip";
import { AuthProvider, useAuth } from "@/hooks/useAuth";
import { ThemeProvider } from "@/components/ThemeProvider";
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

const queryClient = new QueryClient();

function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const { user, loading } = useAuth();
  if (loading) return <div className="min-h-screen flex items-center justify-center bg-background"><div className="animate-spin h-8 w-8 border-2 border-primary border-t-transparent rounded-full" /></div>;
  if (!user) return <Navigate to="/auth" replace />;
  return <>{children}</>;
}

const AppRoutes = () => (
  <Routes>
    <Route path="/auth" element={<AuthPage />} />
    <Route path="/" element={<ProtectedRoute><Index /></ProtectedRoute>} />
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
            <AppRoutes />
          </AuthProvider>
        </BrowserRouter>
      </TooltipProvider>
    </ThemeProvider>
  </QueryClientProvider>
);

export default App;
