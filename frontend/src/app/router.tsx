import type { JSX } from "react";
import { BrowserRouter, Navigate, Route, Routes } from "react-router-dom";
import { AppLayout } from "@/components/layout/AppLayout";
import { LoginPage } from "@/pages/LoginPage";
import { RegisterPage } from "@/pages/RegisterPage";
import { DevicesPage } from "@/pages/DevicesPage";
import { DeviceFormPage } from "@/pages/DeviceFormPage";
import { DeviceDetailPage } from "@/pages/DeviceDetailPage";
import { DashboardPage } from "@/pages/DashboardPage";
import { AlertsPage } from "@/pages/AlertsPage";
import { MapPage } from "@/pages/MapPage";
import { TelemetrySocketProvider } from "@/features/telemetry/components/TelemetrySocketProvider";
import { Skeleton } from "@/components/ui/skeleton";
import { useCurrentUser } from "@/features/auth/hooks/useAuth";
import { useAuthStore } from "@/store/authStore";
import { isAdmin } from "@/lib/utils";
import { ROUTES } from "./routes";

function ProtectedRoute({ children }: { children: JSX.Element }) {
  const token = useAuthStore((state) => state.token);
  return token ? children : <Navigate to={ROUTES.login} replace />;
}

/** Role gate on top of the token gate. The role arrives from `/auth/me`, one
 *  request later than the first render — redirecting while it is still unknown
 *  would throw a legitimate admin back to the dashboard on every reload, so the
 *  pending state renders a placeholder and decides nothing.
 *
 *  `isPending` rather than `isLoading`: while the cache restores, and while a
 *  request sits paused because the device is offline, nothing is in flight, so
 *  `isLoading` reads false with the role still unknown — enough to bounce an
 *  admin out of a screen they are entitled to. */
function AdminRoute({ children }: { children: JSX.Element }) {
  const { data: user, isPending } = useCurrentUser();

  if (isPending) {
    return (
      <div className="space-y-4">
        <Skeleton className="h-20 rounded-2xl" />
        <Skeleton className="h-64 rounded-2xl" />
      </div>
    );
  }

  return isAdmin(user) ? children : <Navigate to={ROUTES.home} replace />;
}

export function AppRouter() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path={ROUTES.login} element={<LoginPage />} />
        <Route path={ROUTES.register} element={<RegisterPage />} />

        {/* Layout route: AppLayout mounts once and stays mounted across every
            authenticated view, so the rail, the top bar, the socket and the
            fleet data are never torn down by navigation. */}
        <Route
          element={
            <ProtectedRoute>
              <TelemetrySocketProvider>
                <AppLayout />
              </TelemetrySocketProvider>
            </ProtectedRoute>
          }
        >
          <Route path={ROUTES.home} element={<DashboardPage />} />
          <Route path={ROUTES.map} element={<MapPage />} />
          <Route path={ROUTES.devices} element={<DevicesPage />} />
          <Route path={ROUTES.newDevice} element={<DeviceFormPage />} />
          <Route path="/devices/:deviceId" element={<DeviceDetailPage />} />
          <Route path="/devices/:deviceId/edit" element={<DeviceFormPage />} />
          <Route
            path={ROUTES.alerts}
            element={
              <AdminRoute>
                <AlertsPage />
              </AdminRoute>
            }
          />
        </Route>
      </Routes>
    </BrowserRouter>
  );
}
