import { useEffect, useState } from "react";
import axios from "axios";
import { getDevice } from "../services/deviceService";
import type { Device } from "../types/device";
import { useDevice } from "./useDevices";

/**
 * Cache-first: the device already in the cached devices list paints instantly
 * (header, form fields...) while the request behind it only confirms or
 * corrects those values. `cancelled` guards against a stale response landing
 * after the id changes or the screen unmounts.
 */
export function useDeviceDetail(deviceId: string | undefined): {
  device: Device | null;
  fetchedDevice: Device | null;
  error: string | null;
} {
  const cachedDevice = useDevice(deviceId);
  const [fetchedDevice, setFetchedDevice] = useState<Device | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!deviceId) return;
    let cancelled = false;

    getDevice(deviceId)
      .then((data) => {
        if (!cancelled) setFetchedDevice(data);
      })
      .catch((cause: unknown) => {
        if (cancelled) return;
        setError(
          axios.isAxiosError(cause) && cause.response?.status === 404
            ? "Ese dispositivo no existe o fue eliminado."
            : "No pudimos cargar el dispositivo. Inténtalo de nuevo.",
        );
      });

    return () => {
      cancelled = true;
    };
  }, [deviceId]);

  return {
    device: fetchedDevice ?? cachedDevice ?? null,
    fetchedDevice,
    error,
  };
}
