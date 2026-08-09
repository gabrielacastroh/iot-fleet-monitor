import { useNavigate } from "react-router-dom";
import { Eye, MoreHorizontal, Pencil, Trash2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { ROUTES } from "@/app/routes";
import type { Device } from "../types/device";

/** Row/card actions. Reading is open to any authenticated user; editing and
 *  deleting are admin-only — the backend's require_admin is the real gate,
 *  this only avoids offering a door that will not open. Deletion is offered
 *  only where the screen can actually handle it (confirmation + refresh), so
 *  `onDelete` is optional. */
export function DeviceActions({
  device,
  isAdmin,
  onDelete,
}: {
  device: Device;
  isAdmin: boolean;
  onDelete?: (device: Device) => void;
}) {
  const navigate = useNavigate();

  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        {/* size-8 rather than the default size-9: inside a dense table this
            button is the tallest thing in the row, so it — not the text — sets
            how many rows fit on screen. */}
        <Button variant="ghost" size="icon-sm" className="size-8">
          <MoreHorizontal aria-hidden />
          <span className="sr-only">Acciones para {device.vehicle_name}</span>
        </Button>
      </DropdownMenuTrigger>

      <DropdownMenuContent>
        <DropdownMenuItem onSelect={() => navigate(ROUTES.deviceDetail(device.id))}>
          <Eye aria-hidden />
          Ver detalle
        </DropdownMenuItem>
        {isAdmin && (
          <>
            <DropdownMenuItem onSelect={() => navigate(ROUTES.deviceEdit(device.id))}>
              <Pencil aria-hidden />
              Editar
            </DropdownMenuItem>
            {onDelete && (
              <>
                <DropdownMenuSeparator />
                <DropdownMenuItem variant="danger" onSelect={() => onDelete(device)}>
                  <Trash2 aria-hidden />
                  Eliminar
                </DropdownMenuItem>
              </>
            )}
          </>
        )}
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
