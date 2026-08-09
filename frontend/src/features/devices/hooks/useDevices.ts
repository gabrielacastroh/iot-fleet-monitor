import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import {
  createDevice,
  deleteDevice,
  listDevices,
  updateDevice,
} from "../services/deviceService";
import type { Device, DeviceCreate, DeviceUpdate } from "../types/device";

export function useDevices() {
  return useQuery({ queryKey: ["devices"], queryFn: listDevices });
}

/** Device already in the cached list, if any. Detail and edit screens use it
 *  to paint instantly instead of showing a skeleton for data the devices
 *  query already holds — without triggering a fetch of their own. */
export function useDevice(id: string | undefined): Device | undefined {
  const { data: devices } = useDevices();
  return id ? devices?.find((device) => device.id === id) : undefined;
}

export function useCreateDevice() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (payload: DeviceCreate) => createDevice(payload),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["devices"] }),
  });
}

export function useUpdateDevice() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ id, payload }: { id: string; payload: DeviceUpdate }) =>
      updateDevice(id, payload),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["devices"] }),
  });
}

export function useDeleteDevice() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => deleteDevice(id),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["devices"] }),
  });
}
