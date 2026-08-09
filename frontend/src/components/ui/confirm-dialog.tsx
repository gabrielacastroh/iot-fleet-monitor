import { Loader2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";

interface ConfirmDialogProps {
  open: boolean;
  title: string;
  description: string;
  confirmLabel?: string;
  cancelLabel?: string;
  isPending?: boolean;
  onConfirm: () => void;
  onCancel: () => void;
}

/** Destructive confirmation. Built on the Dialog primitive so focus trapping,
 *  Escape and scroll locking behave like every other overlay in the app. */
export function ConfirmDialog({
  open,
  title,
  description,
  confirmLabel = "Eliminar",
  cancelLabel = "Cancelar",
  isPending = false,
  onConfirm,
  onCancel,
}: ConfirmDialogProps) {
  return (
    <Dialog
      open={open}
      onOpenChange={(next) => {
        // Closing mid-request would leave the user without feedback on an
        // action that is already in flight.
        if (!next && !isPending) onCancel();
      }}
    >
      <DialogContent showClose={!isPending}>
        <DialogHeader>
          <DialogTitle>{title}</DialogTitle>
          <DialogDescription>{description}</DialogDescription>
        </DialogHeader>

        <DialogFooter className="mt-6">
          <Button variant="ghost" onClick={onCancel} disabled={isPending}>
            {cancelLabel}
          </Button>
          <Button variant="destructive" onClick={onConfirm} disabled={isPending}>
            {isPending && <Loader2 className="size-4 animate-spin" aria-hidden />}
            {isPending ? "Eliminando…" : confirmLabel}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
