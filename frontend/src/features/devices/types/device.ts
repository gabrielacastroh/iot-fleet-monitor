export interface Device {
  id: string;
  vehicle_name: string;
  device_code: string;
  plate: string;
  is_active: boolean;
  last_seen_at: string | null;
  created_at: string;
}

export interface DeviceCreate {
  vehicle_name: string;
  device_code: string;
  plate: string;
  is_active: boolean;
}

/** PATCH semantics: omitted fields are left untouched by the backend. */
export type DeviceUpdate = Partial<DeviceCreate>;
