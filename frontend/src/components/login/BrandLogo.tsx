import { Radio } from "lucide-react";
import { cn } from "@/lib/utils";

interface BrandLogoProps {
  className?: string;
}

export function BrandLogo({ className }: BrandLogoProps) {
  return (
    <div className={cn("flex items-center gap-3", className)}>
      <span className="flex size-11 items-center justify-center rounded-xl bg-primary text-primary-foreground shadow-lg shadow-primary/25">
        <Radio className="size-6" aria-hidden />
      </span>
      <span className="flex flex-col leading-tight">
        <span className="text-xl font-bold tracking-tight text-slate-900">
          FleetIoT
        </span>
        <span className="text-xs text-muted-foreground">
          Plataforma de Monitoreo
        </span>
      </span>
    </div>
  );
}
