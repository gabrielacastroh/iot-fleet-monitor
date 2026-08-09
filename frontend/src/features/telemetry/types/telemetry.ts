export interface TelemetryReading {
  id: string;
  device_id: string;
  latitude: number;
  longitude: number;
  speed: number;
  fuel_level: number;
  temperature: number;
  recorded_at: string;
}
