import { useId, useState } from "react";
import type { FormEvent, ReactNode } from "react";
import { Link } from "react-router-dom";
import { motion } from "framer-motion";
import {
  AlertCircle,
  Car,
  Check,
  Hash,
  Info,
  Loader2,
  ScanLine,
  Truck,
} from "lucide-react";
import { DeviceStatusBadge } from "./DeviceStatusBadge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { cn } from "@/lib/utils";
import { ROUTES } from "@/app/routes";
import type { DeviceCreate } from "../types/device";

interface DeviceFormProps {
  initialValues?: DeviceCreate;
  submitLabel: string;
  isSubmitting: boolean;
  error: string | null;
  /** Field the backend rejected, so the input can carry the error too. */
  errorField?: "device_code" | "plate" | null;
  onSubmit: (values: DeviceCreate) => void;
}

const EMPTY_VALUES: DeviceCreate = {
  vehicle_name: "",
  device_code: "",
  plate: "",
  is_active: true,
};

export function DeviceForm({
  initialValues = EMPTY_VALUES,
  submitLabel,
  isSubmitting,
  error,
  errorField = null,
  onSubmit,
}: DeviceFormProps) {
  const [values, setValues] = useState<DeviceCreate>(initialValues);
  const [touched, setTouched] = useState<Record<string, boolean>>({});
  const vehicleNameId = useId();
  const deviceCodeId = useId();
  const plateId = useId();
  const isActiveId = useId();

  function setField<K extends keyof DeviceCreate>(key: K, value: DeviceCreate[K]) {
    setValues((current) => ({ ...current, [key]: value }));
  }

  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    onSubmit(values);
  }

  // Validation shows up on blur, not on every keystroke: flagging a field the
  // user is still typing into is noise, not help.
  const isFilled = (key: keyof DeviceCreate) => String(values[key]).trim().length > 0;
  const showValid = (key: keyof DeviceCreate) => touched[key] && isFilled(key);
  const showInvalid = (key: keyof DeviceCreate) => touched[key] && !isFilled(key);

  return (
    <div className="grid gap-6 lg:grid-cols-[minmax(0,1fr)_22rem]">
      <form onSubmit={handleSubmit} noValidate className="space-y-6">
        <FormSection
          step={1}
          title="Identificación"
          description="Cómo reconocerás este vehículo dentro de la plataforma."
        >
          <Field
            id={vehicleNameId}
            label="Nombre del vehículo"
            hint="Nombre descriptivo para identificar el vehículo."
            icon={Car}
            required
            valid={showValid("vehicle_name")}
            invalid={showInvalid("vehicle_name")}
            invalidMessage="Escribe un nombre para identificar el vehículo."
          >
            <Input
              id={vehicleNameId}
              // h-11 = the size="lg" buttons this form submits with.
              className="h-11 pl-11"
              placeholder="Camión de reparto Zona Norte"
              value={values.vehicle_name}
              onChange={(event) => setField("vehicle_name", event.target.value)}
              onBlur={() => setTouched((t) => ({ ...t, vehicle_name: true }))}
              aria-invalid={showInvalid("vehicle_name")}
              maxLength={255}
              required
              autoFocus
            />
          </Field>
        </FormSection>

        <FormSection
          step={2}
          title="Datos del equipo"
          description="Identificadores únicos en toda la flota. Se guardan en mayúsculas."
        >
          <div className="grid gap-5 sm:grid-cols-2">
            <Field
              id={deviceCodeId}
              label="Código del dispositivo"
              hint="Identificador único del equipo IoT."
              icon={Hash}
              required
              valid={showValid("device_code") && errorField !== "device_code"}
              invalid={showInvalid("device_code") || errorField === "device_code"}
              invalidMessage={
                errorField === "device_code"
                  ? "Este código ya está en uso."
                  : "Escribe el código del equipo."
              }
            >
              <Input
                id={deviceCodeId}
                className="h-11 pl-11 uppercase"
                placeholder="DEV-001"
                value={values.device_code}
                onChange={(event) => setField("device_code", event.target.value)}
                onBlur={() => setTouched((t) => ({ ...t, device_code: true }))}
                aria-invalid={
                  showInvalid("device_code") || errorField === "device_code"
                }
                maxLength={255}
                required
              />
            </Field>

            <Field
              id={plateId}
              label="Placa"
              hint="Placa del vehículo, máximo 20 caracteres."
              icon={ScanLine}
              required
              valid={showValid("plate") && errorField !== "plate"}
              invalid={showInvalid("plate") || errorField === "plate"}
              invalidMessage={
                errorField === "plate"
                  ? "Esta placa ya está en uso."
                  : "Escribe la placa del vehículo."
              }
            >
              <Input
                id={plateId}
                className="h-11 pl-11 uppercase"
                placeholder="ABC123"
                value={values.plate}
                onChange={(event) => setField("plate", event.target.value)}
                onBlur={() => setTouched((t) => ({ ...t, plate: true }))}
                aria-invalid={showInvalid("plate") || errorField === "plate"}
                maxLength={20}
                required
              />
            </Field>
          </div>
        </FormSection>

        <FormSection
          step={3}
          title="Monitoreo"
          description="Define si el equipo entra en el monitoreo activo de la flota."
        >
          <label
            htmlFor={isActiveId}
            className={cn(
              "flex cursor-pointer items-start justify-between gap-4 rounded-xl border p-4 transition-colors",
              values.is_active ? "border-primary/30 bg-primary-soft/60" : "bg-card",
            )}
          >
            <span>
              <Label htmlFor={isActiveId} className="cursor-pointer text-sm font-medium">
                Dispositivo activo
              </Label>
              <span className="mt-1 block text-xs text-muted-foreground">
                Un dispositivo inactivo permanece registrado pero deja de considerarse
                en el monitoreo.
              </span>
            </span>
            <input
              id={isActiveId}
              type="checkbox"
              role="switch"
              checked={values.is_active}
              onChange={(event) => setField("is_active", event.target.checked)}
              className="mt-0.5 size-5 shrink-0 accent-primary"
            />
          </label>
        </FormSection>

        {error && (
          <motion.p
            role="alert"
            initial={{ opacity: 0, y: -6 }}
            animate={{ opacity: 1, y: 0 }}
            className="flex items-start gap-2 rounded-xl border border-destructive/25 bg-destructive-soft px-4 py-3 text-sm text-destructive"
          >
            <AlertCircle className="mt-0.5 size-4 shrink-0" aria-hidden />
            {error}
          </motion.p>
        )}

        <div className="flex flex-wrap items-center justify-end gap-2">
          <Button type="button" variant="ghost" size="lg" asChild>
            <Link to={ROUTES.devices}>Cancelar</Link>
          </Button>
          <Button type="submit" size="lg" disabled={isSubmitting}>
            {isSubmitting && <Loader2 className="size-4 animate-spin" aria-hidden />}
            {isSubmitting ? "Guardando…" : submitLabel}
          </Button>
        </div>
      </form>

      <DevicePreview values={values} />
    </div>
  );
}

function FormSection({
  step,
  title,
  description,
  children,
}: {
  step: number;
  title: string;
  description: string;
  children: ReactNode;
}) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 10 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.3, delay: step * 0.06, ease: [0.22, 1, 0.36, 1] }}
    >
      <Card>
        <CardHeader className="flex-row items-start gap-3">
          {/* The steps are a real sequence — identify, then describe the
              hardware, then decide whether it is monitored. */}
          <span className="mt-0.5 flex size-7 shrink-0 items-center justify-center rounded-lg bg-secondary text-xs font-medium text-muted-foreground">
            {step}
          </span>
          <div className="space-y-1">
            <CardTitle>{title}</CardTitle>
            <p className="text-sm text-muted-foreground">{description}</p>
          </div>
        </CardHeader>
        <CardContent>{children}</CardContent>
      </Card>
    </motion.div>
  );
}

function Field({
  id,
  label,
  hint,
  icon: Icon,
  required,
  valid,
  invalid,
  invalidMessage,
  children,
}: {
  id: string;
  label: string;
  hint: string;
  icon: typeof Car;
  required?: boolean;
  valid?: boolean;
  invalid?: boolean;
  invalidMessage: string;
  children: ReactNode;
}) {
  return (
    <div className="space-y-2">
      <Label htmlFor={id}>
        {label} {required && <span className="text-destructive">*</span>}
      </Label>

      <div className="group relative">
        <Icon
          className={cn(
            "pointer-events-none absolute top-1/2 left-4 size-4 -translate-y-1/2 transition-colors",
            invalid
              ? "text-destructive"
              : "text-muted-foreground group-focus-within:text-primary",
          )}
          aria-hidden
        />
        {children}
        {valid && (
          <motion.span
            initial={{ scale: 0.6, opacity: 0 }}
            animate={{ scale: 1, opacity: 1 }}
            className="absolute top-1/2 right-4 -translate-y-1/2 text-success"
          >
            <Check className="size-4" aria-hidden />
          </motion.span>
        )}
      </div>

      <p
        className={cn("text-xs", invalid ? "text-destructive" : "text-muted-foreground")}
      >
        {invalid ? invalidMessage : hint}
      </p>
    </div>
  );
}

function DevicePreview({ values }: { values: DeviceCreate }) {
  const rows = [
    { label: "Código", value: values.device_code.toUpperCase() },
    { label: "Placa", value: values.plate.toUpperCase() },
  ];

  return (
    <Card className="h-fit lg:sticky lg:top-24">
      <CardHeader className="flex-row items-center justify-between">
        <CardTitle>Vista previa</CardTitle>
        <DeviceStatusBadge isActive={values.is_active} />
      </CardHeader>

      <CardContent className="space-y-5">
        <div className="flex items-center gap-3 rounded-xl border bg-secondary/40 p-4">
          <span className="flex size-11 shrink-0 items-center justify-center rounded-xl bg-card text-primary shadow-[var(--shadow-soft)]">
            <Truck className="size-5" aria-hidden />
          </span>
          <div className="min-w-0">
            <p className="truncate font-medium">
              {values.vehicle_name || (
                <span className="text-muted-foreground">Nombre del vehículo</span>
              )}
            </p>
            <p className="truncate font-mono text-xs text-muted-foreground">
              {values.device_code.toUpperCase() || "DEV-000"} ·{" "}
              {values.plate.toUpperCase() || "SIN PLACA"}
            </p>
          </div>
        </div>

        <dl className="space-y-3">
          {rows.map(({ label, value }) => (
            <div key={label} className="flex items-center justify-between gap-4 text-sm">
              <dt className="text-muted-foreground">{label}</dt>
              <dd className="min-w-0 truncate font-mono text-xs font-medium">
                {value || <span className="text-muted-foreground">—</span>}
              </dd>
            </div>
          ))}
          <div className="flex items-center justify-between gap-4 text-sm">
            <dt className="text-muted-foreground">Monitoreo</dt>
            <dd className="font-medium">{values.is_active ? "Activo" : "Pausado"}</dd>
          </div>
        </dl>

        <p className="flex items-start gap-2 border-t pt-4 text-xs leading-relaxed text-muted-foreground">
          <Info className="mt-0.5 size-3.5 shrink-0" aria-hidden />
          El código y la placa se guardan en mayúsculas y deben ser únicos en toda la
          flota.
        </p>
      </CardContent>
    </Card>
  );
}
