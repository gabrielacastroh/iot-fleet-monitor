import { useId, useState } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { DEFAULT_RANGE_DAYS, rangeFromDays } from "@/lib/fleet";
import type { DateRange } from "@/lib/fleet";

const PRESETS = [
  { label: "24 h", days: 1 },
  { label: "7 días", days: 7 },
  { label: "30 días", days: 30 },
] as const;

/** `sv-SE` formats dates as YYYY-MM-DD in *local* time, which is exactly what
 *  `<input type="date">` wants — `toISOString()` would shift the day for
 *  anyone west of UTC. */
function toDateInput(iso: string): string {
  return new Date(iso).toLocaleDateString("sv-SE");
}

export function DateRangePicker({
  value,
  onChange,
}: {
  value: DateRange;
  onChange: (range: DateRange) => void;
}) {
  // Number of days, or "custom" — the picker starts on a preset, never custom.
  const [preset, setPreset] = useState<number | "custom">(DEFAULT_RANGE_DAYS);
  // Generated, not hardcoded: a second picker on the same screen would
  // otherwise duplicate the ids and point both labels at the first input.
  const fromId = useId();
  const toId = useId();
  const [from, setFrom] = useState(() => toDateInput(value.startDate));
  const [to, setTo] = useState(() => toDateInput(value.endDate));

  // Both are YYYY-MM-DD, so a plain string compare is a date compare.
  const invalid = Boolean(from && to && from > to);

  function applyCustom(nextFrom: string, nextTo: string) {
    setFrom(nextFrom);
    setTo(nextTo);
    // The backend accepts start_date/end_date without cross-validating them,
    // so an inverted range would just come back empty and look like missing
    // data. Guard here instead of firing the query.
    if (!nextFrom || !nextTo || nextFrom > nextTo) return;
    onChange({
      startDate: new Date(`${nextFrom}T00:00:00`).toISOString(),
      endDate: new Date(`${nextTo}T23:59:59.999`).toISOString(),
    });
  }

  return (
    <div className="flex flex-col gap-3 rounded-2xl border bg-card p-4 shadow-[var(--shadow-soft)] sm:flex-row sm:items-end sm:justify-between">
      <div className="space-y-2">
        <p className="eyebrow">Rango</p>
        <div className="flex flex-wrap gap-2">
          {PRESETS.map(({ label, days }) => (
            <Button
              key={days}
              type="button"
              size="sm"
              variant={preset === days ? "default" : "outline"}
              aria-pressed={preset === days}
              onClick={() => {
                const next = rangeFromDays(days);
                setPreset(days);
                // Keep the custom inputs seeded with what the user is looking
                // at, so switching to "Personalizado" starts from here.
                setFrom(toDateInput(next.startDate));
                setTo(toDateInput(next.endDate));
                onChange(next);
              }}
            >
              {label}
            </Button>
          ))}
          <Button
            type="button"
            size="sm"
            variant={preset === "custom" ? "default" : "outline"}
            aria-pressed={preset === "custom"}
            onClick={() => {
              setPreset("custom");
              applyCustom(from, to);
            }}
          >
            Personalizado
          </Button>
        </div>
      </div>

      {preset === "custom" && (
        <div className="space-y-2">
          <div className="flex flex-wrap items-end gap-3">
            <div className="space-y-1.5">
              <Label htmlFor={fromId}>Desde</Label>
              <Input
                id={fromId}
                type="date"
                value={from}
                aria-invalid={invalid}
                onChange={(event) => applyCustom(event.target.value, to)}
                className="h-9 w-auto"
              />
            </div>
            <div className="space-y-1.5">
              <Label htmlFor={toId}>Hasta</Label>
              <Input
                id={toId}
                type="date"
                value={to}
                aria-invalid={invalid}
                onChange={(event) => applyCustom(from, event.target.value)}
                className="h-9 w-auto"
              />
            </div>
          </div>
          {invalid && (
            <p role="alert" className="text-sm text-destructive">
              La fecha inicial no puede ser posterior a la final.
            </p>
          )}
        </div>
      )}
    </div>
  );
}
