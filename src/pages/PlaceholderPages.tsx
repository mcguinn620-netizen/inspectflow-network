import { DashboardLayout } from "@/components/DashboardLayout";

const PlaceholderPage = ({ title, description }: { title: string; description: string }) => (
  <DashboardLayout>
    <div className="space-y-4">
      <div>
        <h1 className="text-2xl font-semibold tracking-tight">{title}</h1>
        <p className="text-sm text-muted-foreground mt-1">{description}</p>
      </div>
      <div className="rounded-lg border border-dashed bg-muted/30 p-12 text-center">
        <p className="text-sm text-muted-foreground">This module is coming soon</p>
      </div>
    </div>
  </DashboardLayout>
);

export const DispatchPage = () => <PlaceholderPage title="Dispatch" description="Intelligent inspection routing and assignment" />;

export const ReportsPage = () => <PlaceholderPage title="Reports" description="Automated report generation and analytics" />;
export const RepairShopPage = () => <PlaceholderPage title="Repair Shop" description="Work orders and technician management" />;
export const ClientPortalPage = () => <PlaceholderPage title="Client Portal" description="Customer-facing inspection access" />;
export const SettingsPage = () => <PlaceholderPage title="Settings" description="Platform configuration and company management" />;
