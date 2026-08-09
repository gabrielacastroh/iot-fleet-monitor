import { useState, useSyncExternalStore } from "react";
import { NavLink, Outlet, useLocation, useNavigate } from "react-router-dom";
import { AnimatePresence, motion } from "framer-motion";
import { onlineManager } from "@tanstack/react-query";
import {
  BellRing,
  ChevronsUpDown,
  CloudOff,
  Cpu,
  LayoutDashboard,
  LogOut,
  Map,
  Menu,
  PanelLeftClose,
  PanelLeftOpen,
  Radio,
  Search,
  Settings,
} from "lucide-react";
import type { LucideIcon } from "lucide-react";
import { Avatar, AvatarFallback } from "@/components/ui/avatar";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { Sheet, SheetContent, SheetTitle, SheetTrigger } from "@/components/ui/sheet";
import { Skeleton } from "@/components/ui/skeleton";
import { Tooltip, TooltipContent, TooltipTrigger } from "@/components/ui/tooltip";
import { NotificationsMenu } from "@/components/layout/NotificationsMenu";
import { useFleetAlerts } from "@/features/alerts/hooks/useFleetAlerts";
import { useCurrentUser } from "@/features/auth/hooks/useAuth";
import type { FleetAlert } from "@/lib/fleet";
import { useAuthStore } from "@/store/authStore";
import type { User } from "@/features/auth/types/auth";
import { cn, isAdmin as getIsAdmin } from "@/lib/utils";
import { ROUTES } from "@/app/routes";

interface NavItem {
  to: string;
  label: string;
  icon: LucideIcon;
  end?: boolean;
  /** Hidden for non-admins, whose requests the backend answers with 403. */
  adminOnly?: boolean;
}

// Only routes that actually exist. A nav item pointing at an unbuilt screen is
// a dead end the user pays for twice: once clicking, once losing trust.
// ponytail: labels only. Three self-explanatory destinations don't need a
// subtitle each — the second line doubled every row's height and bought no
// information, which is what made the rail read as heavy.
const NAV_ITEMS: NavItem[] = [
  { to: ROUTES.home, label: "Dashboard", icon: LayoutDashboard, end: true },
  { to: ROUTES.map, label: "Mapa", icon: Map },
  { to: ROUTES.devices, label: "Dispositivos", icon: Cpu },
  { to: ROUTES.alerts, label: "Alertas", icon: BellRing, adminOnly: true },
];

/**
 * Persistent application frame. Mounted once by the router as a layout route,
 * so the rail and the top bar survive navigation — only the <Outlet /> content
 * swaps. The frame itself owns no fleet data: every screen requests what it
 * renders, so landing on one view never pays for another's queries.
 */
export function AppLayout() {
  const location = useLocation();
  // Desktop-only: the mobile Sheet is its own collapse mechanism already.
  const [collapsed, setCollapsed] = useState(false);
  const {
    data: userData,
    isLoading: userLoading,
    isFetching: userFetching,
  } = useCurrentUser();
  const user = userData ?? null;
  const isAdmin = getIsAdmin(user);

  // The bell reads the same feed the dashboard panel and the alerts screen do,
  // so the count in the top bar can never disagree with the screen it opens.
  // TanStack Query dedupes the underlying requests, so subscribing here costs
  // no extra fetch.
  const { alerts: notifications, isFetching: alertsFetching } = useFleetAlerts();

  const isFetching = userFetching || alertsFetching;

  return (
    <div className="flex min-h-svh bg-background">
      <a
        href="#main"
        className="sr-only focus:not-sr-only focus:absolute focus:top-4 focus:left-4 focus:z-50 focus:rounded-xl focus:bg-card focus:px-4 focus:py-2.5 focus:text-sm focus:shadow-[var(--shadow-overlay)]"
      >
        Saltar al contenido
      </a>

      <aside
        className={cn(
          "fixed inset-y-0 left-0 hidden flex-col bg-sidebar transition-[width] duration-200 lg:flex",
          // 4.5rem = a 40px nav row plus its 16px gutters: the narrowest rail
          // that still centers an icon button without clipping its hover box.
          collapsed ? "w-[4.5rem]" : "w-sidebar",
        )}
      >
        <SidebarBody
          scope="desktop"
          user={user}
          userLoading={userLoading}
          isAdmin={isAdmin}
          collapsed={collapsed}
          onToggleCollapse={() => setCollapsed((value) => !value)}
        />
      </aside>

      <div
        className={cn(
          "flex min-w-0 flex-1 flex-col transition-[padding] duration-200",
          collapsed ? "lg:pl-[4.5rem]" : "lg:pl-sidebar",
        )}
      >
        <TopBar
          notifications={notifications}
          alertsHref={ROUTES.alerts}
          user={user}
          userLoading={userLoading}
          isAdmin={isAdmin}
          isFetching={isFetching}
        />

        <main id="main" className="flex-1 px-5 pt-8 pb-16 sm:px-8 lg:px-10">
          <div className="mx-auto w-full max-w-[88rem]">
            {/* Only the routed content animates. Keying on pathname here means
                a view change cross-fades the page, not the whole frame. */}
            <AnimatePresence mode="wait" initial={false}>
              <motion.div
                key={location.pathname}
                initial={{ opacity: 0, y: 8 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: -4 }}
                transition={{ duration: 0.2, ease: [0.22, 1, 0.36, 1] }}
              >
                <Outlet />
              </motion.div>
            </AnimatePresence>
          </div>
        </main>
      </div>
    </div>
  );
}

function SidebarBody({
  scope,
  user,
  userLoading,
  isAdmin,
  onNavigate,
  collapsed = false,
  onToggleCollapse,
}: {
  // The desktop <aside> and the mobile <Sheet> each mount their own
  // SidebarBody. A layoutId shared between two live instances makes Framer
  // Motion animate the indicator from whichever one last held it — including
  // the off-canvas mobile copy — instead of the previous nav item, so the bar
  // flies in from an unrelated position. Namespacing the id per instance
  // keeps each sidebar's indicator animating only against itself.
  scope: "desktop" | "mobile";
  user: User | null;
  userLoading: boolean;
  isAdmin: boolean;
  onNavigate?: () => void;
  /** Only the desktop instance collapses — the mobile Sheet already has its
   *  own open/close mechanism, so it never receives these. */
  collapsed?: boolean;
  onToggleCollapse?: () => void;
}) {
  const navItems = NAV_ITEMS.filter((item) => !item.adminOnly || isAdmin);

  const collapseToggle = onToggleCollapse ? (
    <Button
      variant="ghost"
      size="icon-sm"
      onClick={onToggleCollapse}
      className="text-sidebar-muted hover:bg-white/[0.04] hover:text-sidebar-foreground"
    >
      {collapsed ? (
        <PanelLeftOpen aria-hidden />
      ) : (
        <PanelLeftClose aria-hidden />
      )}
      <span className="sr-only">
        {collapsed ? "Expandir menú" : "Colapsar menú"}
      </span>
    </Button>
  ) : null;

  return (
    <div className="flex h-full flex-col text-sidebar-foreground">
      {/* Same height as the top bar, so the brand and the header sit on one
          line across the fold. */}
      <div
        className={cn(
          "flex h-topbar items-center gap-3 px-3",
          collapsed && "justify-center",
        )}
      >
        <span className="flex size-9 shrink-0 items-center justify-center rounded-lg bg-primary text-primary-foreground">
          <Radio className="size-4" aria-hidden />
        </span>
        {!collapsed && (
          <>
            <span className="truncate text-[0.9375rem] font-semibold tracking-tight">
              FleetIoT
            </span>
            <span className="ml-auto">{collapseToggle}</span>
          </>
        )}
      </div>

      {/* Collapsed at 4.5rem there is no room for mark + button on one row. */}
      {collapsed && collapseToggle && (
        <div className="flex justify-center pb-2">{collapseToggle}</div>
      )}

      <nav aria-label="Navegación principal" className="flex-1 px-3 pt-2">
        <ul className="space-y-1">
          {navItems.map(({ to, label, icon: Icon, end }) => {
            const link = (
              <NavLink
                to={to}
                end={end}
                onClick={onNavigate}
                className={({ isActive }) =>
                  cn(
                    "group relative flex h-10 items-center gap-3 rounded-lg px-3 text-sm font-medium transition-colors duration-150",
                    "focus-visible:ring-2 focus-visible:ring-white/40 focus-visible:outline-none",
                    collapsed && "justify-center px-0",
                    isActive
                      ? "bg-primary/10 text-sidebar-foreground"
                      : "text-sidebar-muted hover:bg-white/[0.04] hover:text-sidebar-foreground",
                  )
                }
              >
                {({ isActive }) => (
                  <>
                    {/* The active marker slides between items instead of
                        popping, so the rail reads as one moving indicator. */}
                    {isActive && (
                      <motion.span
                        layoutId={`nav-indicator-${scope}`}
                        className="absolute top-1/2 -left-3 h-5 w-1 -translate-y-1/2 rounded-r-full bg-primary"
                        transition={{ type: "spring", bounce: 0, duration: 0.3 }}
                      />
                    )}
                    {/* No chip behind the icon: the row's own tint, the accent
                        icon and the rail marker already say "active" three
                        times over. */}
                    <Icon
                      className={cn(
                        "size-4 shrink-0 transition-colors",
                        isActive
                          ? "text-primary"
                          : "text-sidebar-muted group-hover:text-sidebar-foreground",
                      )}
                      aria-hidden
                    />
                    {!collapsed && <span className="truncate">{label}</span>}
                  </>
                )}
              </NavLink>
            );

            return (
              <li key={to}>
                {collapsed ? (
                  <Tooltip>
                    <TooltipTrigger asChild>{link}</TooltipTrigger>
                    <TooltipContent side="right">{label}</TooltipContent>
                  </Tooltip>
                ) : (
                  link
                )}
              </li>
            );
          })}
        </ul>
      </nav>

      <SidebarProfile
        user={user}
        userLoading={userLoading}
        isAdmin={isAdmin}
        collapsed={collapsed}
      />
    </div>
  );
}

function SidebarProfile({
  user,
  userLoading,
  isAdmin,
  collapsed = false,
}: {
  user: User | null;
  userLoading: boolean;
  isAdmin: boolean;
  collapsed?: boolean;
}) {
  const logout = useAuthStore((state) => state.logout);
  const initials = (user?.name ?? "").slice(0, 2).toUpperCase();

  // Same box, same height: a skeleton keeps the rail still while /auth/me
  // resolves, instead of writing "Cargando…" and then swapping it for a name.
  if (userLoading) {
    return (
      <div className="border-t border-sidebar-border p-3">
        <div
          className={cn(
            "flex items-center gap-3 px-3 py-2",
            collapsed && "justify-center px-0",
          )}
        >
          <Skeleton className="size-8 shrink-0 rounded-lg bg-white/10" />
          {!collapsed && (
            <div className="flex-1 space-y-1.5">
              <Skeleton className="h-3 w-24 bg-white/10" />
              <Skeleton className="h-2.5 w-32 bg-white/[0.07]" />
            </div>
          )}
        </div>
      </div>
    );
  }

  // ponytail: no card around the row — a border and a hover tint separate the
  // account from the nav without adding another raised block to the rail.
  const trigger = (
    <button
      type="button"
      className={cn(
        "flex w-full items-center gap-3 rounded-lg px-3 py-2 text-left transition-colors hover:bg-white/[0.04] focus-visible:ring-2 focus-visible:ring-white/40 focus-visible:outline-none",
        collapsed && "justify-center px-0",
      )}
    >
      <Avatar className="size-8 shrink-0 rounded-lg">
        <AvatarFallback className="rounded-lg bg-white/[0.06] text-xs font-medium text-sidebar-foreground">
          {initials}
        </AvatarFallback>
      </Avatar>
      {!collapsed && (
        <>
          <span className="min-w-0 flex-1 leading-tight">
            <span className="block truncate text-sm font-medium">
              {user?.name ?? "Sesión"}
            </span>
            <span className="block truncate text-xs text-sidebar-muted">
              {user?.email ?? ""}
            </span>
          </span>
          <ChevronsUpDown className="size-4 shrink-0 text-sidebar-muted" aria-hidden />
        </>
      )}
    </button>
  );

  return (
    <div className="border-t border-sidebar-border p-3">
      <DropdownMenu>
        <DropdownMenuTrigger asChild>{trigger}</DropdownMenuTrigger>

        <DropdownMenuContent align="start" side={collapsed ? "right" : "top"} className="w-60">
          <DropdownMenuLabel className="flex items-center justify-between gap-2">
            <span className="truncate">{user?.email ?? "Sesión activa"}</span>
            {isAdmin && <Badge variant="brand">Admin</Badge>}
          </DropdownMenuLabel>
          <DropdownMenuSeparator />
          <DropdownMenuItem disabled>
            <Settings aria-hidden />
            Preferencias
          </DropdownMenuItem>
          <DropdownMenuItem variant="danger" onSelect={logout}>
            <LogOut aria-hidden />
            Cerrar sesión
          </DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>
    </div>
  );
}

// TanStack Query's own network signal — the same one that pauses its fetches.
// Reading `navigator.onLine` separately would let the badge claim the app is
// online while the query cache has already stopped asking for anything.
// Kept unexported so this module keeps exporting only components.
const subscribeOnline = (onChange: () => void) =>
  onlineManager.subscribe(() => onChange());

function useIsOnline() {
  return useSyncExternalStore(
    subscribeOnline,
    () => onlineManager.isOnline(),
    () => true,
  );
}

function TopBar({
  notifications,
  alertsHref,
  user,
  userLoading,
  isAdmin,
  isFetching,
}: {
  notifications: FleetAlert[];
  alertsHref: string;
  user: User | null;
  userLoading: boolean;
  isAdmin: boolean;
  isFetching: boolean;
}) {
  const [open, setOpen] = useState(false);
  const navigate = useNavigate();
  const isOnline = useIsOnline();
  const initials = (user?.name ?? "").slice(0, 2).toUpperCase();

  return (
    <div className="sticky top-0 z-30 flex h-topbar items-center gap-3 border-b px-5 surface-glass sm:px-8 lg:px-10">
      {/* One place that says "something is loading" for every background
          request, so individual panels don't each need a spinner. */}
      <AnimatePresence>
        {isFetching && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="absolute inset-x-0 bottom-0 h-0.5 overflow-hidden"
            role="status"
            aria-label="Cargando datos"
          >
            <span className="progress-sweep block h-full w-2/5 bg-primary" />
          </motion.div>
        )}
      </AnimatePresence>

      <Sheet open={open} onOpenChange={setOpen}>
        <SheetTrigger asChild>
          <Button variant="ghost" size="icon-sm" className="lg:hidden">
            <Menu aria-hidden />
            <span className="sr-only">Abrir navegación</span>
          </Button>
        </SheetTrigger>
        <SheetContent side="left" className="bg-sidebar p-0">
          <SheetTitle className="sr-only">Navegación</SheetTitle>
          <SidebarBody
            scope="mobile"
            user={user}
            userLoading={userLoading}
            isAdmin={isAdmin}
            onNavigate={() => setOpen(false)}
          />
        </SheetContent>
      </Sheet>

      {/* Search jumps straight to the device list, which is where every
          lookup ends anyway. Fixed width, not flex-1: it is one control among
          several, not the subject of the header. */}
      <form
        className="relative hidden w-full max-w-xs sm:block"
        onSubmit={(event) => {
          event.preventDefault();
          const value = new FormData(event.currentTarget).get("q");
          navigate(
            `${ROUTES.devices}${value ? `?q=${encodeURIComponent(String(value))}` : ""}`,
          );
        }}
      >
        <Search
          className="pointer-events-none absolute top-1/2 left-3 size-4 -translate-y-1/2 text-muted-foreground"
          aria-hidden
        />
        <input
          name="q"
          type="search"
          placeholder="Buscar dispositivos…"
          aria-label="Buscar en la flota"
          className="h-9 w-full rounded-lg border bg-card/60 pr-3 pl-9 text-sm transition-[border-color,box-shadow] outline-none placeholder:text-muted-foreground/70 hover:border-foreground/15 focus-visible:border-primary focus-visible:ring-2 focus-visible:ring-ring/40"
        />
      </form>

      <div className="ml-auto flex items-center gap-2">
        {/* The live region is mounted at all times: one that appears already
            filled is announced by nothing. Losing the network is a state, not
            an interruption — polite, no modal, no blocked screen. */}
        <div role="status" aria-live="polite">
          {!isOnline && (
            <Badge variant="warning" className="mr-1 gap-1.5">
              <CloudOff aria-hidden />
              Sin conexión
              {/* Narrow screens keep only the two words; the sentence a screen
                  reader announces does not depend on the viewport. */}
              <span className="hidden sm:inline" aria-hidden>
                · datos guardados
              </span>
              <span className="sr-only">, estás viendo los últimos datos guardados</span>
            </Badge>
          )}
        </div>

        {/* No tooltip: it used to stand in for content the bell could not show,
            and the menu now shows the alerts themselves. */}
        {/* Alerts are admin-only, so a non-admin gets no bell at all — an empty
            one still announces a feature they are not part of. */}
        {isAdmin && (
          <NotificationsMenu alerts={notifications} viewAllHref={alertsHref} />
        )}

        {userLoading ? (
          <Skeleton className="size-8 rounded-full" />
        ) : (
          <Avatar className="size-8 border">
            <AvatarFallback className="bg-primary-soft text-primary">
              {initials}
            </AvatarFallback>
          </Avatar>
        )}
      </div>
    </div>
  );
}
