import {
  LayoutDashboard,
  Send,
  Store,
  ClipboardCheck,
  Users,
  Car,
  FileText,
  Wrench,
  UserCircle,
  Settings,
  ChevronLeft,
  CalendarDays,
  Route,
  Receipt,
  Briefcase,
} from "lucide-react";
import { NavLink } from "@/components/NavLink";
import {
  Sidebar,
  SidebarContent,
  SidebarGroup,
  SidebarGroupContent,
  SidebarGroupLabel,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
  SidebarFooter,
  useSidebar,
} from "@/components/ui/sidebar";
import { useUserRoles } from "@/hooks/useUserRoles";

const inspectorNav = [
  { title: "Dashboard", url: "/app/inspector/dashboard", icon: LayoutDashboard },
  { title: "Schedule", url: "/app/inspector/schedule", icon: CalendarDays },
  { title: "Jobs", url: "/app/inspector/jobs", icon: Briefcase },
  { title: "Trips", url: "/app/inspector/trips", icon: Route },
  { title: "Tax / Earnings", url: "/app/inspector/tax", icon: Receipt },
];

const opsNav = [
  { title: "Command Center", url: "/", icon: LayoutDashboard },
  { title: "Dispatch", url: "/dispatch", icon: Send },
  { title: "Marketplace", url: "/marketplace", icon: Store },
  { title: "Inspections", url: "/inspections", icon: ClipboardCheck },
];

const manageNav = [
  { title: "Inspectors", url: "/inspectors", icon: Users },
  { title: "Vehicles", url: "/vehicles", icon: Car },
  { title: "Reports", url: "/reports", icon: FileText },
  { title: "Repair Shop", url: "/repair-shop", icon: Wrench },
];

const bottomNav = [
  { title: "Client Portal", url: "/client-portal", icon: UserCircle },
  { title: "Settings", url: "/settings", icon: Settings },
];

export function AppSidebar() {
  const { state, toggleSidebar } = useSidebar();
  const collapsed = state === "collapsed";
  const { hasRole, isAdmin, loading } = useUserRoles();

  const showInspector = !loading && (hasRole("inspector") || isAdmin);
  const showOps = !loading && isAdmin;
  const showManage = !loading && isAdmin;

  const renderItems = (items: typeof inspectorNav) => (
    <SidebarMenu>
      {items.map((item) => (
        <SidebarMenuItem key={item.title}>
          <SidebarMenuButton asChild>
            <NavLink
              to={item.url}
              end={item.url === "/"}
              className="flex items-center gap-3 rounded-md px-3 py-2 text-sm text-sidebar-foreground/80 hover:bg-sidebar-accent hover:text-sidebar-foreground transition-colors duration-150"
              activeClassName="bg-sidebar-accent text-sidebar-primary-foreground font-medium"
            >
              <item.icon className="h-4 w-4 shrink-0" />
              {!collapsed && <span>{item.title}</span>}
            </NavLink>
          </SidebarMenuButton>
        </SidebarMenuItem>
      ))}
    </SidebarMenu>
  );

  return (
    <Sidebar collapsible="icon" className="border-r-0">
      <div className="flex h-14 items-center gap-2 px-4 border-b border-sidebar-border">
        <div className="flex h-8 w-8 items-center justify-center rounded-md bg-primary">
          <Car className="h-4 w-4 text-primary-foreground" />
        </div>
        {!collapsed && (
          <div className="flex flex-1 items-center justify-between">
            <span className="text-sm font-semibold text-sidebar-foreground">
              Drive Smooth
            </span>
            <button
              onClick={toggleSidebar}
              className="h-6 w-6 flex items-center justify-center rounded text-sidebar-muted hover:text-sidebar-foreground transition-colors duration-150"
            >
              <ChevronLeft className="h-4 w-4" />
            </button>
          </div>
        )}
      </div>

      <SidebarContent className="px-2 pt-2">
        {showInspector && (
          <SidebarGroup>
            <SidebarGroupLabel className="text-[10px] uppercase tracking-wider text-sidebar-muted font-semibold mb-1">
              Inspector
            </SidebarGroupLabel>
            <SidebarGroupContent>{renderItems(inspectorNav)}</SidebarGroupContent>
          </SidebarGroup>
        )}

        {showOps && (
          <SidebarGroup>
            <SidebarGroupLabel className="text-[10px] uppercase tracking-wider text-sidebar-muted font-semibold mb-1">
              Operations
            </SidebarGroupLabel>
            <SidebarGroupContent>{renderItems(opsNav)}</SidebarGroupContent>
          </SidebarGroup>
        )}

        {showManage && (
          <SidebarGroup>
            <SidebarGroupLabel className="text-[10px] uppercase tracking-wider text-sidebar-muted font-semibold mb-1">
              Manage
            </SidebarGroupLabel>
            <SidebarGroupContent>{renderItems(manageNav)}</SidebarGroupContent>
          </SidebarGroup>
        )}
      </SidebarContent>

      <SidebarFooter className="px-2 pb-3 border-t border-sidebar-border">
        <SidebarMenu>
          {bottomNav.map((item) => (
            <SidebarMenuItem key={item.title}>
              <SidebarMenuButton asChild>
                <NavLink
                  to={item.url}
                  className="flex items-center gap-3 rounded-md px-3 py-2 text-sm text-sidebar-foreground/80 hover:bg-sidebar-accent hover:text-sidebar-foreground transition-colors duration-150"
                  activeClassName="bg-sidebar-accent text-sidebar-primary-foreground font-medium"
                >
                  <item.icon className="h-4 w-4 shrink-0" />
                  {!collapsed && <span>{item.title}</span>}
                </NavLink>
              </SidebarMenuButton>
            </SidebarMenuItem>
          ))}
        </SidebarMenu>
      </SidebarFooter>
    </Sidebar>
  );
}
