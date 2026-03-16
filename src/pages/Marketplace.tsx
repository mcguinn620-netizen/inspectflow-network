import { DashboardLayout } from "@/components/DashboardLayout";
import { Store, Star, FileCheck } from "lucide-react";

const templates = [
  { name: "Pre-Purchase Full Inspection", items: 142, rating: 4.8, uses: 1247, company: "AutoCheck Pro", category: "Pre-Purchase" },
  { name: "Lease Return Inspection", items: 86, rating: 4.7, uses: 983, company: "InspectFirst", category: "Lease" },
  { name: "Fleet Audit Standard", items: 64, rating: 4.9, uses: 2104, company: "FleetGuard", category: "Fleet" },
  { name: "Dealer Trade Checklist", items: 48, rating: 4.5, uses: 567, company: "AutoCheck Pro", category: "Dealer" },
  { name: "Lender Condition Report", items: 92, rating: 4.6, uses: 1532, company: "InspectFirst", category: "Lender" },
  { name: "Rental Return Quick", items: 34, rating: 4.4, uses: 3201, company: "FleetGuard", category: "Rental" },
];

const MarketplacePage = () => {
  return (
    <DashboardLayout>
      <div className="space-y-6">
        <div>
          <h1 className="text-2xl font-semibold tracking-tight">Inspection Marketplace</h1>
          <p className="text-sm text-muted-foreground mt-1">Browse and deploy inspection templates</p>
        </div>
        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
          {templates.map((t, i) => (
            <div key={i} className="rounded-lg border bg-card p-4 hover:border-primary/30 transition-colors duration-150 cursor-pointer group">
              <div className="flex items-start justify-between mb-3">
                <div className="h-9 w-9 rounded-md bg-primary/10 flex items-center justify-center">
                  <Store className="h-4 w-4 text-primary" />
                </div>
                <span className="text-[10px] font-medium uppercase tracking-wider text-muted-foreground bg-muted px-2 py-0.5 rounded-full">
                  {t.category}
                </span>
              </div>
              <h3 className="text-sm font-semibold mb-1 group-hover:text-primary transition-colors duration-150">{t.name}</h3>
              <p className="text-xs text-muted-foreground mb-3">by {t.company}</p>
              <div className="flex items-center gap-4 pt-3 border-t">
                <div className="flex items-center gap-1">
                  <FileCheck className="h-3 w-3 text-muted-foreground" />
                  <span className="text-xs text-muted-foreground">{t.items} items</span>
                </div>
                <div className="flex items-center gap-1">
                  <Star className="h-3 w-3 text-warning" />
                  <span className="text-xs text-muted-foreground">{t.rating}</span>
                </div>
                <span className="text-xs text-muted-foreground ml-auto">{t.uses.toLocaleString()} uses</span>
              </div>
            </div>
          ))}
        </div>
      </div>
    </DashboardLayout>
  );
};

export default MarketplacePage;
