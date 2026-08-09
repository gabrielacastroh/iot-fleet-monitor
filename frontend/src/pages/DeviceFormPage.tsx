import { useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { toast } from "sonner";
import axios from "axios";
import { AlertCircle } from "lucide-react";
import { PageHeader } from "@/components/layout/PageHeader";
import { DeviceForm } from "@/features/devices/components/DeviceForm";
import { Card, CardContent } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import {
  useCreateDevice,
  useDevice,
  useUpdateDevice,
} from "@/features/devices/hooks/useDevices";
import { useDeviceDetail } from "@/features/devices/hooks/useDeviceDetail";
import type { DeviceCreate } from "@/features/devices/types/device";
import { ROUTES } from "@/app/routes";

type ConflictField = "device_code" | "plate";

export function DeviceFormPage() {
  const { deviceId } = useParams<{ deviceId: string }>();
  const isEditing = Boolean(deviceId);
  const navigate = useNavigate();

  const [error, setError] = useState<string | null>(null);
  const [errorField, setErrorField] = useState<ConflictField | null>(null);

  const createDeviceMutation = useCreateDevice();
  const updateDeviceMutation = useUpdateDevice();
  const isSubmitting = createDeviceMutation.isPending || updateDeviceMutation.isPending;

  // Cache-first: the device already in the fleet list fills the form on the
  // first frame; the request behind it only confirms or corrects those values.
  const cached = useDevice(deviceId);
  const { fetchedDevice, error: loadError } = useDeviceDetail(deviceId);
  const initialValues: DeviceCreate | null = !isEditing
    ? { vehicle_name: "", device_code: "", plate: "", is_active: true }
    : ((fetchedDevice
        ? {
            vehicle_name: fetchedDevice.vehicle_name,
            device_code: fetchedDevice.device_code,
            plate: fetchedDevice.plate,
            is_active: fetchedDevice.is_active,
          }
        : null) ??
      (cached
        ? {
            vehicle_name: cached.vehicle_name,
            device_code: cached.device_code,
            plate: cached.plate,
            is_active: cached.is_active,
          }
        : null));

  async function handleSubmit(values: DeviceCreate) {
    setError(null);
    setErrorField(null);
    try {
      if (deviceId) {
        await updateDeviceMutation.mutateAsync({ id: deviceId, payload: values });
        toast.success("Cambios guardados", {
          description: `${values.vehicle_name} se actualizó correctamente.`,
        });
      } else {
        await createDeviceMutation.mutateAsync(values);
        toast.success("Dispositivo registrado", {
          description: `${values.vehicle_name} ya forma parte de la flota.`,
        });
      }
      navigate(ROUTES.devices, { replace: true });
    } catch (cause) {
      const field = axios.isAxiosError(cause)
        ? conflictField((cause.response?.data as { detail?: unknown } | undefined)?.detail)
        : null;
      setErrorField(field);
      setError(describeError(cause, values, field));
    }
  }

  return (
    <>
      <PageHeader
        backTo={ROUTES.devices}
        backLabel="Dispositivos"
        title={isEditing ? "Editar dispositivo" : "Registrar dispositivo"}
        description={
          isEditing
            ? "Actualiza los datos del equipo IoT registrado."
            : "Agrega un nuevo equipo IoT y define cómo entra al monitoreo."
        }
      />

      {loadError ? (
        <Card className="border-destructive/25 bg-destructive-soft">
          <CardContent>
            <p role="alert" className="flex items-start gap-2 text-sm text-destructive">
              <AlertCircle className="mt-0.5 size-4 shrink-0" aria-hidden />
              {loadError}
            </p>
          </CardContent>
        </Card>
      ) : initialValues === null ? (
        <div className="grid gap-6 lg:grid-cols-[minmax(0,1fr)_22rem]">
          <div className="space-y-6">
            <Skeleton className="h-44 rounded-2xl" />
            <Skeleton className="h-56 rounded-2xl" />
          </div>
          <Skeleton className="h-72 rounded-2xl" />
        </div>
      ) : (
        <DeviceForm
          // The form owns its fields once mounted, so it is remounted only when
          // the server actually disagrees with the cached values — identical
          // data keeps the same key and never interrupts typing.
          key={JSON.stringify(initialValues)}
          initialValues={initialValues}
          submitLabel={isEditing ? "Guardar cambios" : "Registrar dispositivo"}
          isSubmitting={isSubmitting}
          error={error}
          errorField={errorField}
          onSubmit={(values) => void handleSubmit(values)}
        />
      )}
    </>
  );
}

/** The backend answers 409 with `{ field, message }` so the user can be told
 *  exactly which value collided instead of "code or plate". */
function conflictField(detail: unknown): ConflictField | null {
  if (typeof detail !== "object" || detail === null) return null;
  const field = (detail as { field?: unknown }).field;
  return field === "device_code" || field === "plate" ? field : null;
}

function describeError(
  cause: unknown,
  values: DeviceCreate,
  field: ConflictField | null,
): string {
  if (!axios.isAxiosError(cause)) {
    return "No pudimos conectar con el servidor. Inténtalo de nuevo en unos segundos.";
  }
  switch (cause.response?.status) {
    case 409:
      if (field === "plate") {
        return `La placa ${values.plate.trim().toUpperCase()} ya está registrada en otro dispositivo. Usa una placa distinta.`;
      }
      if (field === "device_code") {
        return `El código ${values.device_code.trim().toUpperCase()} ya está registrado en otro dispositivo. Usa un código distinto.`;
      }
      return "La placa o el código ya están registrados en otro dispositivo.";
    case 403:
      return "Necesitas permisos de administrador para esta acción.";
    case 404:
      return "Ese dispositivo ya no existe.";
    case 422:
      return "Revisa los datos: hay campos vacíos o demasiado largos.";
    default:
      return "No pudimos guardar el dispositivo. Inténtalo de nuevo.";
  }
}
