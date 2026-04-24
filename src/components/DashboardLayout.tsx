import { SidebarProvider, SidebarTrigger } from "@/components/ui/sidebar";
import { AppSidebar } from "@/components/AppSidebar";
import { Bell, Search, LogOut, Settings as SettingsIcon, User } from "lucide-react";
import { useAuth } from "@/hooks/useAuth";
import { useUserRoles } from "@/hooks/useUserRoles";
import { useNavigate, Link, useLocation } from "react-router-dom";
import { MobileTabBar } from "@/components/MobileTabBar";
import { ActiveTripBanner } from "@/components/inspector/ActiveTripBanner";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { toast } from "sonner";

interface DashboardLayoutProps {
  children: React.ReactNode;
}

export function DashboardLayout({ children }: DashboardLayoutProps) {
  const { user, signOut } = useAuth();
  const { roles } = useUserRoles();
  const navigate = useNavigate();
  const { pathname } = useLocation();
  const isInspectorPage = pathname.startsWith("/app/inspector") || pathname.startsWith("/app/");

  const fullName = (user?.user_metadata as any)?.full_name as string | undefined;
  const displayName = fullName || user?.email?.split("@")[0] || "User";
  const initials = (fullName || user?.email || "U")
    .split(/[\s@.]+/).filter(Boolean).slice(0, 2).map((s) => s[0]?.toUpperCase()).join("") || "U";
  const primaryRole = roles[0] ? roles[0].replace("_", " ") : "Member";

  const handleLogout = async () => {
    await signOut();
    toast.success("Signed out");
    navigate("/auth", { replace: true });
  };

  return (
    <SidebarProvider>
      <div className="h-[100dvh] flex w-full overflow-hidden">
        <AppSidebar onLogout={handleLogout} />
        <div className="flex-1 flex flex-col min-w-0 h-[100dvh] relative">
          {/* Fixed top bar — sits above safe area, never scrolls with content */}
          <header
            className="fixed top-0 inset-x-0 md:left-[var(--sidebar-width,16rem)] z-50 border-b bg-card/95 backdrop-blur supports-[backdrop-filter]:bg-card/80"
            style={{ paddingTop: "env(safe-area-inset-top)" }}
          >
            <div className="h-14 flex items-center justify-between px-4">
              <div className="flex items-center gap-3">
                <SidebarTrigger className="text-muted-foreground hover:text-foreground transition-colors duration-150" />
                <div className="hidden sm:flex items-center gap-2 rounded-md bg-muted px-3 py-1.5">
                  <Search className="h-4 w-4 text-muted-foreground" />
                  <input
                    type="text"
                    placeholder="Search inspections, vehicles, inspectors..."
                    className="bg-transparent text-sm outline-none w-64 placeholder:text-muted-foreground"
                  />
                </div>
              </div>
              <div className="flex items-center gap-3">
                <button className="relative h-8 w-8 flex items-center justify-center rounded-md hover:bg-muted transition-colors duration-150">
                  <Bell className="h-4 w-4 text-muted-foreground" />
                  <span className="absolute top-1.5 right-1.5 h-2 w-2 rounded-full bg-destructive" />
                </button>
                <DropdownMenu>
                  <DropdownMenuTrigger asChild>
                    <button className="flex items-center gap-2 rounded-md hover:bg-muted px-1.5 py-1 transition-colors">
                      <div className="h-8 w-8 rounded-full bg-primary flex items-center justify-center">
                        <span className="text-xs font-semibold text-primary-foreground">{initials}</span>
                      </div>
                      <div className="hidden sm:block text-left">
                        <p className="text-sm font-medium leading-none">{displayName}</p>
                        <p className="text-xs text-muted-foreground capitalize">{primaryRole}</p>
                      </div>
                    </button>
                  </DropdownMenuTrigger>
                  <DropdownMenuContent align="end" className="w-56 bg-secondary">
                    <DropdownMenuLabel className="font-normal">
                      <div className="flex flex-col space-y-1">
                        <p className="text-sm font-medium leading-none">{displayName}</p>
                        <p className="text-xs leading-none text-muted-foreground truncate">{user?.email}</p>
                      </div>
                    </DropdownMenuLabel>
                    <DropdownMenuSeparator />
                    <DropdownMenuItem asChild>
                      <Link to="/settings"><User className="h-4 w-4 mr-2" />Profile & Settings</Link>
                    </DropdownMenuItem>
                    <DropdownMenuItem asChild>
                      <Link to="/settings"><SettingsIcon className="h-4 w-4 mr-2" />Settings</Link>
                    </DropdownMenuItem>
                    <DropdownMenuSeparator />
                    <DropdownMenuItem onClick={handleLogout} className="text-navy-foreground">
                      <LogOut className="h-4 w-4 mr-2" />Sign out
                    </DropdownMenuItem>
                  </DropdownMenuContent>
                </DropdownMenu>
              </div>
            </div>
          </header>
          {/* Scroll container — sits below the fixed header, above the fixed tab bar */}
          <main
            className="flex-1 overflow-y-auto p-4 md:p-6"
            style={{
              paddingTop: "calc(env(safe-area-inset-top) + 3.5rem + 1rem)",
              paddingBottom: isInspectorPage
                ? "calc(env(safe-area-inset-bottom) + 5rem)"
                : "calc(env(safe-area-inset-bottom) + 1rem)",
            }}
          >
            {isInspectorPage && (
              <div className="mb-3">
                <ActiveTripBanner />
              </div>
            )}
            {children}
          </main>
          <MobileTabBar />
        </div>
      </div>
    </SidebarProvider>
  );
}
