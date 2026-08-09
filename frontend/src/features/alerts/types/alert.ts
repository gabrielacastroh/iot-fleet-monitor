/** The backend raises alerts from one rule only: the predictive fuel autonomy
 *  check. Kept as a union so a second rule is a compile error here first. */
export type AlertType = "low_fuel";

export interface Alert {
  id: string;
  device_id: string;
  alert_type: AlertType;
  message: string;
  is_resolved: boolean;
  created_at: string;
}
