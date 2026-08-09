/** Concrete navigation targets, kept in one place so a literal never drifts
 *  from the routes actually declared in `router.tsx`. Values are unchanged
 *  from what was scattered across the app — this only names them once. */
export const ROUTES = {
  login: "/login",
  register: "/register",
  home: "/",
  devices: "/devices",
  newDevice: "/devices/new",
  alerts: "/alerts",
  map: "/map",
  deviceDetail: (id: string) => `/devices/${id}`,
  deviceEdit: (id: string) => `/devices/${id}/edit`,
} as const;
