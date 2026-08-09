import { apiClient } from "@/lib/api/client";
import type { Device, DeviceCreate, DeviceUpdate } from "../types/device";

export function listDevices(): Promise<Device[]> {
  return apiClient.get<Device[]>("/devices").then((res) => res.data);
}

export function getDevice(id: string): Promise<Device> {
  return apiClient.get<Device>(`/devices/${id}`).then((res) => res.data);
}

export function createDevice(payload: DeviceCreate): Promise<Device> {
  return apiClient.post<Device>("/devices", payload).then((res) => res.data);
}

export function updateDevice(id: string, payload: DeviceUpdate): Promise<Device> {
  return apiClient.patch<Device>(`/devices/${id}`, payload).then((res) => res.data);
}

export function deleteDevice(id: string): Promise<void> {
  return apiClient.delete(`/devices/${id}`).then(() => undefined);
}
