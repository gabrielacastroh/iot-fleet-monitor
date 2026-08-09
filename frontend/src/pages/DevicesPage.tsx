import { useEffect, useMemo, useState } from "react";
import { Link, useSearchParams } from "react-router-dom";
import { motion } from "framer-motion";
import { toast } from "sonner";
import { ArrowDownUp, LayoutGrid, List, Plus, Search, Truck } from "lucide-react";
import { PageHeader } from "@/components/layout/PageHeader";
import { DevicesTable } from "@/features/devices/components/DevicesTable";
import { VehicleCard } from "@/features/devices/components/VehicleCard";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { ConfirmDialog } from "@/components/ui/confirm-dialog";
import {
  DropdownMenu,
  DropdownMenuCheckboxItem,
  DropdownMenuContent,
  DropdownMenuLabel,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { Input } from "@/components/ui/input";
import { Pagination } from "@/components/ui/pagination";
import { Skeleton } from "@/components/ui/skeleton";
import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Tooltip, TooltipContent, TooltipTrigger } from "@/components/ui/tooltip";
import { useCurrentUser } from "@/features/auth/hooks/useAuth";
import { useDashboardData } from "@/features/dashboard/hooks/useDashboardData";
import { useDeleteDevice } from "@/features/devices/hooks/useDevices";
import type { Device } from "@/features/devices/types/device";
import { isAdmin as getIsAdmin } from "@/lib/utils";
import { ROUTES } from "@/app/routes";

type StatusFilter = "all" | "active" | "inactive" | "noSignal" | "alert";
type SortKey = "recent" | "name" | "lastSeen";
type ViewMode = "table" | "grid";

const SORT_LABELS: Record<SortKey, string> = {
  recent: "Más recientes",
  name: "Nombre (A-Z)",
  lastSeen: "Última señal",
};

const STATUS_TABS: { value: StatusFilter; label: string; adminOnly?: boolean }[] = [
  { value: "all", label: "Todos" },
  { value: "active", label: "Activos" },
  { value: "inactive", label: "Inactivos" },
  { value: "noSignal", label: "Sin señal" },
  // Filtering by alert is filtering by something a non-admin is never shown,
  // and the feed backing it is empty for them anyway.
  { value: "alert", label: "Con alerta", adminOnly: true },
];

/** Fixed at ten: enough to fill the board on a normal screen, few enough that
 *  the list barely scrolls, so moving through a fleet means turning pages
 *  rather than scrolling. Not a user setting — everything past the tenth
 *  device is reached through the pager. */
const PAGE_SIZE = 10;

function matchesStatus(
  device: Device,
  status: StatusFilter,
  alertedIds: Set<string>,
): boolean {
  switch (status) {
    case "active":
      return device.is_active;
    case "inactive":
      return !device.is_active;
    case "noSignal":
      // The same third state DeviceStatusBadge paints: registered and running,
      // but it has never reported.
      return device.is_active && device.last_seen_at === null;
    case "alert":
      return alertedIds.has(device.id);
    default:
      return true;
  }
}

export function DevicesPage() {
  const { data: user, isLoading: userLoading } = useCurrentUser();
  const isAdmin = getIsAdmin(user);
  const {
    devices,
    devicesLoading: loading,
    devicesError: error,
    latest,
    telemetryLoading,
    alerts,
  } = useDashboardData();
  const deleteDeviceMutation = useDeleteDevice();

  // The top bar's search lands here with ?q=, so a lookup started anywhere in
  // the app finishes on this screen.
  const [searchParams] = useSearchParams();
  const [query, setQuery] = useState(searchParams.get("q") ?? "");
  const [status, setStatus] = useState<StatusFilter>("all");
  const [sort, setSort] = useState<SortKey>("recent");
  const [view, setView] = useState<ViewMode>("table");
  const [page, setPage] = useState(1);
  const [deviceToDelete, setDeviceToDelete] = useState<Device | null>(null);

  useEffect(() => {
    setQuery(searchParams.get("q") ?? "");
  }, [searchParams]);

  // A narrower result set makes the page the user is standing on disappear.
  useEffect(() => {
    setPage(1);
  }, [query, status, sort]);

  // "Con alerta" filters on the same backend feed the dashboard panel and the
  // alerts screen read, so the three can never disagree about which vehicles
  // are flagged. Empty for a non-admin, whose tab is not rendered either.
  const alertedIds = useMemo(
    () => new Set(alerts.map((alert) => alert.deviceId)),
    [alerts],
  );

  const visibleDevices = useMemo(() => {
    const term = query.trim().toLowerCase();

    const filtered = devices.filter((device) => {
      const matchesTerm =
        !term ||
        [device.vehicle_name, device.device_code, device.plate].some((field) =>
          field.toLowerCase().includes(term),
        );

      return matchesTerm && matchesStatus(device, status, alertedIds);
    });

    return [...filtered].sort((a, b) => {
      if (sort === "name") return a.vehicle_name.localeCompare(b.vehicle_name);
      if (sort === "lastSeen") {
        // Devices that never reported sort last: "no data" is not "oldest".
        if (!a.last_seen_at) return 1;
        if (!b.last_seen_at) return -1;
        return b.last_seen_at.localeCompare(a.last_seen_at);
      }
      return b.created_at.localeCompare(a.created_at);
    });
  }, [devices, query, status, sort, alertedIds]);

  // Client-side paging: GET /devices has no page params, it returns the whole
  // fleet. What has to stay bounded is what React renders, so only the current
  // slice is handed to the table or the grid — 10 rows out of 500, not 500.
  const pageCount = Math.max(1, Math.ceil(visibleDevices.length / PAGE_SIZE));
  // Clamp instead of resetting: deleting the last device of the last page
  // should land the user on the new last page, not throw them to page 1.
  const currentPage = Math.min(page, pageCount);
  const pagedDevices = useMemo(
    () => visibleDevices.slice((currentPage - 1) * PAGE_SIZE, currentPage * PAGE_SIZE),
    [visibleDevices, currentPage],
  );

  const rangeStart = visibleDevices.length === 0 ? 0 : (currentPage - 1) * PAGE_SIZE + 1;
  const rangeEnd = Math.min(currentPage * PAGE_SIZE, visibleDevices.length);
  const hasFilters = query.trim().length > 0 || status !== "all";

  async function handleDelete(device: Device) {
    try {
      await deleteDeviceMutation.mutateAsync(device.id);
      setDeviceToDelete(null);
      toast.success("Dispositivo eliminado", {
        description: `${device.vehicle_name} ya no forma parte de la flota.`,
      });
    } catch {
      setDeviceToDelete(null);
      toast.error("No pudimos eliminar el dispositivo", {
        description: "Revisa tu conexión e inténtalo de nuevo.",
      });
    }
  }

  return (
    <>
      {/* Full-height board from md up: header, toolbar and pager stay put and
          only the list scrolls, so a 500-device fleet never turns the page
          into an endless scroll. The height subtracts the top bar and `main`'s
          own `pt-8 pb-16` (6rem), which is what the page is nested in. Below
          md the viewport is too short to split into fixed rows, so it falls
          back to normal page flow. */}
      {/* The height leaves 2rem above (main's `pt-8`) and 1rem below; the
          negative margin reclaims the rest of main's `pb-16`, which is dead
          space under a board that already ends at the fold. All of it is
          relative to the viewport, so it follows whatever screen it lands on. */}
      <div className="flex flex-col gap-3 md:-mb-12 md:h-[calc(100svh-var(--topbar-height)-3rem)]">
        <PageHeader
          className="mb-0 shrink-0"
          title="Dispositivos"
          description="Inventario de equipos IoT instalados en la flota."
          actions={
          // Reserve the space while the role is unknown: a button that appears
          // a beat later shoves the header around.
          userLoading ? (
            <Skeleton className="h-10 w-44 rounded-xl" />
          ) : (
            isAdmin && (
              <Button asChild>
                <Link to={ROUTES.newDevice}>
                  <Plus className="size-4" aria-hidden />
                  Nuevo dispositivo
                </Link>
              </Button>
            )
          )
          }
        />

        <div className="flex shrink-0 flex-wrap items-center gap-3">
          <div className="relative min-w-56 flex-1">
            <Search
              className="pointer-events-none absolute top-1/2 left-3.5 size-4 -translate-y-1/2 text-muted-foreground"
              aria-hidden
            />
            <Input
              type="search"
              className="pl-10"
              placeholder="Buscar dispositivo, vehículo o placa…"
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              aria-label="Buscar dispositivos"
            />
          </div>

          <Tabs value={status} onValueChange={(value) => setStatus(value as StatusFilter)}>
            <TabsList>
              {STATUS_TABS.filter((tab) => !tab.adminOnly || isAdmin).map((tab) => (
                <TabsTrigger key={tab.value} value={tab.value}>
                  {tab.label}
                </TabsTrigger>
              ))}
            </TabsList>
          </Tabs>

          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button variant="outline">
                <ArrowDownUp className="size-4" aria-hidden />
                {SORT_LABELS[sort]}
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent>
              <DropdownMenuLabel>Ordenar por</DropdownMenuLabel>
              {(Object.keys(SORT_LABELS) as SortKey[]).map((key) => (
                <DropdownMenuCheckboxItem
                  key={key}
                  checked={sort === key}
                  onCheckedChange={() => setSort(key)}
                >
                  {SORT_LABELS[key]}
                </DropdownMenuCheckboxItem>
              ))}
            </DropdownMenuContent>
          </DropdownMenu>

          <div
            // p-0.5 around a size-9 button lands the group on the same 40px
            // height as the input, the tabs and the buttons beside it.
            className="flex items-center gap-1 rounded-xl border bg-card p-0.5 shadow-[var(--shadow-soft)]"
            role="group"
            aria-label="Modo de vista"
          >
            {(
              [
                { mode: "table" as const, icon: List, label: "Vista de tabla" },
                { mode: "grid" as const, icon: LayoutGrid, label: "Vista de tarjetas" },
              ]
            ).map(({ mode, icon: Icon, label }) => (
              <Tooltip key={mode}>
                <TooltipTrigger asChild>
                  <Button
                    variant="ghost"
                    size="icon-sm"
                    aria-pressed={view === mode}
                    onClick={() => setView(mode)}
                    className={
                      view === mode ? "bg-secondary text-foreground" : undefined
                    }
                  >
                    <Icon aria-hidden />
                    <span className="sr-only">{label}</span>
                  </Button>
                </TooltipTrigger>
                <TooltipContent>{label}</TooltipContent>
              </Tooltip>
            ))}
          </div>
        </div>

        {error && (
          <Card className="shrink-0 border-destructive/25 bg-destructive-soft">
            <CardContent>
              <p role="alert" className="text-sm text-destructive">
                {error}
              </p>
            </CardContent>
          </Card>
        )}

        <p className="eyebrow shrink-0" aria-live="polite">
          {visibleDevices.length === 0
            ? "Sin resultados"
            : `Mostrando ${rangeStart}-${rangeEnd} de ${visibleDevices.length} ${
                visibleDevices.length === 1 ? "dispositivo" : "dispositivos"
              }`}
          {visibleDevices.length !== devices.length &&
            devices.length > 0 &&
            ` · ${devices.length} en total`}
        </p>

        {/* The one scrolling region. `min-h-0` is what lets a flex child
            shrink below its content — without it the list would push the
            pager off the bottom instead of scrolling inside. */}
        <div className="min-h-0 flex-1 md:overflow-y-auto">
          {loading ? (
            <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
              {Array.from({ length: 6 }).map((_, index) => (
                <Skeleton key={index} className="h-52 rounded-2xl" />
              ))}
            </div>
          ) : visibleDevices.length === 0 ? (
            <EmptyState
              hasFilters={hasFilters}
              isAdmin={isAdmin}
              onClear={() => {
                setQuery("");
                setStatus("all");
              }}
            />
          ) : view === "grid" ? (
            <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
              {pagedDevices.map((device, index) => (
                <VehicleCard
                  key={device.id}
                  device={device}
                  reading={latest.get(device.id)}
                  telemetryLoading={telemetryLoading}
                  isAdmin={isAdmin}
                  onDelete={setDeviceToDelete}
                  index={index}
                />
              ))}
            </div>
          ) : (
            // h-full so the table card owns the whole scroll region instead of
            // ending after ten rows with the rest of the fold left empty.
            <motion.div
              className="h-full"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
            >
              <DevicesTable
                devices={pagedDevices}
                latest={latest}
                telemetryLoading={telemetryLoading}
                isAdmin={isAdmin}
                onDelete={setDeviceToDelete}
              />
            </motion.div>
          )}
        </div>

        {/* Outside the scroll area: the pager is the control that moves it, so
            it stays reachable no matter how far down the list you are. */}
        {!loading && visibleDevices.length > 0 && (
          <div className="shrink-0">
            <Pagination
              page={currentPage}
              pageCount={pageCount}
              onPageChange={setPage}
            />
          </div>
        )}
      </div>

      <ConfirmDialog
        open={deviceToDelete !== null}
        title="Eliminar dispositivo"
        description={`Se eliminará "${deviceToDelete?.vehicle_name ?? ""}" junto con su telemetría y sus alertas. Esta acción no se puede deshacer.`}
        isPending={deleteDeviceMutation.isPending}
        onConfirm={() => {
          if (deviceToDelete) void handleDelete(deviceToDelete);
        }}
        onCancel={() => setDeviceToDelete(null)}
      />
    </>
  );
}

function EmptyState({
  hasFilters,
  isAdmin,
  onClear,
}: {
  hasFilters: boolean;
  isAdmin: boolean;
  onClear: () => void;
}) {
  return (
    <Card>
      <CardContent className="flex flex-col items-center gap-2 py-16 text-center">
        <span className="flex size-12 items-center justify-center rounded-2xl bg-secondary text-muted-foreground">
          <Truck className="size-5" aria-hidden />
        </span>
        <p className="text-sm font-medium">
          {hasFilters ? "Sin resultados" : "Todavía no hay dispositivos"}
        </p>
        <p className="max-w-sm text-sm text-muted-foreground">
          {hasFilters
            ? "Ningún vehículo coincide con la búsqueda o el filtro aplicado."
            : "Registra el primer equipo IoT para empezar a monitorear la flota."}
        </p>
        {hasFilters ? (
          <Button variant="outline" className="mt-2" onClick={onClear}>
            Limpiar filtros
          </Button>
        ) : (
          isAdmin && (
            <Button asChild className="mt-2">
              <Link to={ROUTES.newDevice}>
                <Plus className="size-4" aria-hidden />
                Nuevo dispositivo
              </Link>
            </Button>
          )
        )}
      </CardContent>
    </Card>
  );
}
