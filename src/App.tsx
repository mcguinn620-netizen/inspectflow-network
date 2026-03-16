import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { BrowserRouter, Route, Routes } from "react-router-dom";
import { Toaster as Sonner } from "@/components/ui/sonner";
import { Toaster } from "@/components/ui/toaster";
import { TooltipProvider } from "@/components/ui/tooltip";
import Index from "./pages/Index.tsx";
import InspectorsPage from "./pages/Inspectors.tsx";
import VehiclesPage from "./pages/Vehicles.tsx";
import MarketplacePage from "./pages/Marketplace.tsx";
import {
  DispatchPage,
  InspectionsPage,
  ReportsPage,
  RepairShopPage,
  ClientPortalPage,
  SettingsPage,
} from "./pages/PlaceholderPages.tsx";
import NotFound from "./pages/NotFound.tsx";

const queryClient = new QueryClient();

const App = () => (
  <QueryClientProvider client={queryClient}>
    <TooltipProvider>
      <Toaster />
      <Sonner />
      <BrowserRouter>
        <Routes>
          <Route path="/" element={<Index />} />
          <Route path="/dispatch" element={<DispatchPage />} />
          <Route path="/marketplace" element={<MarketplacePage />} />
          <Route path="/inspections" element={<InspectionsPage />} />
          <Route path="/inspectors" element={<InspectorsPage />} />
          <Route path="/vehicles" element={<VehiclesPage />} />
          <Route path="/reports" element={<ReportsPage />} />
          <Route path="/repair-shop" element={<RepairShopPage />} />
          <Route path="/client-portal" element={<ClientPortalPage />} />
          <Route path="/settings" element={<SettingsPage />} />
          <Route path="*" element={<NotFound />} />
        </Routes>
      </BrowserRouter>
    </TooltipProvider>
  </QueryClientProvider>
);

export default App;
