import { afterEach, describe, expect, it, vi } from "vitest";
import type { Device } from "@/features/devices/types/device";
import type { TelemetryReading } from "@/features/telemetry/types/telemetry";
import {
  buildSeries,
  deriveAlerts,
  latestByDevice,
  rangeFromDays,
  timeAgo,
} from "./fleet";

function device(overrides: Partial<Device> = {}): Device {
  return {
    id: "d1",
    vehicle_name: "Camión 1",
    device_code: "DEV-0001-AAAA",
    plate: "ABC123",
    is_active: true,
    last_seen_at: "2026-01-01T10:00:00Z",
    created_at: "2026-01-01T00:00:00Z",
    ...overrides,
  };
}

function reading(overrides: Partial<TelemetryReading> = {}): TelemetryReading {
  return {
    id: "r1",
    device_id: "d1",
    latitude: 4.65,
    longitude: -74.05,
    speed: 60,
    fuel_level: 80,
    temperature: 70,
    recorded_at: "2026-01-01T10:00:00Z",
    ...overrides,
  };
}

describe("latestByDevice", () => {
  it("keeps the newest reading of each device", () => {
    const latest = latestByDevice([
      reading({ id: "old", device_id: "d1", recorded_at: "2026-01-01T09:00:00Z" }),
      reading({ id: "new", device_id: "d1", recorded_at: "2026-01-01T11:00:00Z" }),
      reading({ id: "other", device_id: "d2", recorded_at: "2026-01-01T08:00:00Z" }),
    ]);

    expect(latest.get("d1")?.id).toBe("new");
    expect(latest.get("d2")?.id).toBe("other");
  });

  it("returns an empty map for no readings", () => {
    expect(latestByDevice([]).size).toBe(0);
  });
});

describe("deriveAlerts", () => {
  it("flags fuel at or below the threshold, as danger under 10%", () => {
    const [warning] = deriveAlerts(
      [device()],
      new Map([["d1", reading({ fuel_level: 20 })]]),
    );
    expect(warning.level).toBe("warning");

    const [danger] = deriveAlerts(
      [device()],
      new Map([["d1", reading({ fuel_level: 5 })]]),
    );
    expect(danger.level).toBe("danger");
  });

  it("flags speeding strictly above the limit", () => {
    const atLimit = deriveAlerts([device()], new Map([["d1", reading({ speed: 110 })]]));
    expect(atLimit).toHaveLength(0);

    const over = deriveAlerts([device()], new Map([["d1", reading({ speed: 111 })]]));
    expect(over[0].title).toBe("Exceso de velocidad");
  });

  it("flags an active device that never reported", () => {
    const alerts = deriveAlerts([device({ last_seen_at: null })], new Map());
    expect(alerts).toHaveLength(1);
    expect(alerts[0].level).toBe("info");
  });

  it("ignores an inactive device that never reported", () => {
    const alerts = deriveAlerts(
      [device({ is_active: false, last_seen_at: null })],
      new Map(),
    );
    expect(alerts).toHaveLength(0);
  });

  it("sorts danger before warning before info", () => {
    const alerts = deriveAlerts(
      [
        device({ id: "d1", last_seen_at: null }),
        device({ id: "d2" }),
        device({ id: "d3" }),
      ],
      new Map([
        ["d2", reading({ device_id: "d2", fuel_level: 15 })],
        ["d3", reading({ device_id: "d3", speed: 150 })],
      ]),
    );

    expect(alerts.map((alert) => alert.level)).toEqual(["danger", "warning", "info"]);
  });

  it("returns nothing for a healthy fleet", () => {
    expect(deriveAlerts([device()], new Map([["d1", reading()]]))).toHaveLength(0);
  });
});

describe("buildSeries", () => {
  it("orders chronologically and keeps only the most recent points", () => {
    const series = buildSeries(
      [
        reading({ speed: 30, recorded_at: "2026-01-01T12:00:00Z" }),
        reading({ speed: 10, recorded_at: "2026-01-01T10:00:00Z" }),
        reading({ speed: 20, recorded_at: "2026-01-01T11:00:00Z" }),
      ],
      2,
    );

    expect(series.map((point) => point.speed)).toEqual([20, 30]);
  });

  it("rounds the plotted metrics", () => {
    const [point] = buildSeries([
      reading({ speed: 60.4, fuel_level: 79.6, temperature: 70.5 }),
    ]);

    expect(point).toMatchObject({ speed: 60, fuel: 80, temperature: 71 });
  });

  it("returns nothing for no readings", () => {
    expect(buildSeries([])).toEqual([]);
  });
});

describe("rangeFromDays", () => {
  it("spans the requested number of days back from now", () => {
    const { startDate, endDate } = rangeFromDays(7);
    const spanMs = new Date(endDate).getTime() - new Date(startDate).getTime();

    expect(spanMs).toBe(7 * 86_400_000);
  });

  it("snaps the end up to a whole minute so the query key is stable", () => {
    const { endDate } = rangeFromDays(1);

    expect(new Date(endDate).getSeconds()).toBe(0);
    expect(new Date(endDate).getMilliseconds()).toBe(0);
    expect(new Date(endDate).getTime()).toBeGreaterThanOrEqual(Date.now());
  });
});

describe("timeAgo", () => {
  afterEach(() => {
    vi.useRealTimers();
  });

  function agoFrom(msAgo: number): string {
    vi.useFakeTimers();
    vi.setSystemTime(new Date("2026-01-01T12:00:00Z"));
    return timeAgo(new Date(Date.now() - msAgo).toISOString());
  }

  it("reads a missing timestamp as no data", () => {
    expect(timeAgo(null)).toBe("Sin datos");
  });

  it("scales from seconds to days", () => {
    expect(agoFrom(10_000)).toBe("Justo ahora");
    expect(agoFrom(5 * 60_000)).toBe("Hace 5 min");
    expect(agoFrom(3 * 3_600_000)).toBe("Hace 3 h");
    expect(agoFrom(2 * 86_400_000)).toBe("Hace 2 d");
  });
});
