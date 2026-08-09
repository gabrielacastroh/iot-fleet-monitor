import { useMemo } from "react";
import { PageHeader } from "@/components/layout/PageHeader";
import { LazyFleetMap as FleetMap } from "@/features/dashboard/components/LazyFleetMap";
import { useDevices } from "@/features/devices/hooks/useDevices";
import { useLatestTelemetry } from "@/features/telemetry/hooks/useTelemetryQuery";
import { latestByDevice } from "@/lib/fleet";

/** Same map as the dashboard's card, just given the whole viewport instead of
 *  sharing a row with the alerts panel — the dashboard link's "ver más
 *  grande" destination. */
export function MapPage() {
  const { data: devices = [], isPending: devicesLoading } = useDevices();
  const { data: latestReadings, isPending: latestLoading } = useLatestTelemetry();
  const latest = useMemo(() => latestByDevice(latestReadings ?? []), [latestReadings]);

  return (
    <>
      <PageHeader title="Mapa de la flota" description="Última ubicación reportada por cada equipo." />
      <FleetMap
        devices={devices}
        latest={latest}
        loading={devicesLoading || latestLoading}
        heightClassName="h-[calc(100svh-14rem)] min-h-[28rem]"
      />
    </>
  );
}
