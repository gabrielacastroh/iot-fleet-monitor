import { useId, useState } from "react";
import type { FormEvent } from "react";
import { Link, useNavigate } from "react-router-dom";
import { motion } from "framer-motion";
import axios from "axios";
import { AlertCircle, Eye, EyeOff, Loader2, Lock, Mail, User } from "lucide-react";
import { BrandLogo } from "@/components/login/BrandLogo";
import { LoginHero } from "@/components/login/LoginHero";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { useRegister } from "@/features/auth/hooks/useAuth";
import { ROUTES } from "@/app/routes";

const MIN_PASSWORD_LENGTH = 8;

export function RegisterPage() {
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const registerMutation = useRegister();
  const navigate = useNavigate();
  const nameId = useId();
  const emailId = useId();
  const passwordId = useId();

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError(null);
    try {
      // The account is useless until it can be used — the mutation signs the
      // new user in right away instead of bouncing them back to the login form.
      await registerMutation.mutateAsync({ name, email, password });
      navigate(ROUTES.home, { replace: true });
    } catch (cause) {
      if (axios.isAxiosError(cause) && cause.response?.status === 409) {
        setError("Ese email ya está registrado. Inicia sesión o usa otro.");
      } else if (axios.isAxiosError(cause) && cause.response?.status === 422) {
        setError("Revisa los datos: la contraseña debe tener al menos 8 caracteres.");
      } else {
        setError("No pudimos conectar con el servidor. Inténtalo de nuevo en unos segundos.");
      }
    }
  }

  return (
    <main className="flex min-h-svh bg-slate-50">
      <LoginHero />

      <div className="flex flex-1 items-center justify-center px-6 py-12 sm:px-10">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5, ease: "easeOut" }}
          className="w-full max-w-2xl"
        >
          <Card className="py-12 shadow-2xl shadow-slate-900/[0.07]">
            <CardHeader className="items-start gap-9 px-12">
              <BrandLogo />
              <div className="space-y-2.5">
                <CardTitle className="text-3xl">Crear cuenta</CardTitle>
                <CardDescription className="text-base">
                  Registra un nuevo usuario para acceder al sistema.
                </CardDescription>
              </div>
            </CardHeader>

            <CardContent className="px-12">
              <form onSubmit={handleSubmit} noValidate className="space-y-7">
                <div className="space-y-2">
                  <Label htmlFor={nameId}>Nombre</Label>
                  <div className="relative">
                    <User
                      className="pointer-events-none absolute top-1/2 left-3.5 size-4 -translate-y-1/2 text-muted-foreground"
                      aria-hidden
                    />
                    <Input
                      id={nameId}
                      type="text"
                      autoComplete="name"
                      placeholder="Tu nombre"
                      // 52px, off the app's 40/44px control scale on purpose:
                      // the auth screens are styled to their own approved
                      // mockup and their fields and buttons share this height.
                      className="h-[3.25rem] pl-10 text-base"
                      value={name}
                      onChange={(event) => setName(event.target.value)}
                      required
                      autoFocus
                    />
                  </div>
                </div>

                <div className="space-y-2">
                  <Label htmlFor={emailId}>Email</Label>
                  <div className="relative">
                    <Mail
                      className="pointer-events-none absolute top-1/2 left-3.5 size-4 -translate-y-1/2 text-muted-foreground"
                      aria-hidden
                    />
                    <Input
                      id={emailId}
                      type="email"
                      autoComplete="username"
                      placeholder="ejemplo@empresa.com"
                      className="h-[3.25rem] pl-10 text-base"
                      value={email}
                      onChange={(event) => setEmail(event.target.value)}
                      required
                    />
                  </div>
                </div>

                <div className="space-y-2">
                  <Label htmlFor={passwordId}>Contraseña</Label>
                  <div className="relative">
                    <Lock
                      className="pointer-events-none absolute top-1/2 left-3.5 size-4 -translate-y-1/2 text-muted-foreground"
                      aria-hidden
                    />
                    <Input
                      id={passwordId}
                      type={showPassword ? "text" : "password"}
                      autoComplete="new-password"
                      placeholder="••••••••"
                      className="h-[3.25rem] px-10 text-base"
                      value={password}
                      onChange={(event) => setPassword(event.target.value)}
                      minLength={MIN_PASSWORD_LENGTH}
                      required
                      aria-describedby={`${passwordId}-hint`}
                    />
                    <button
                      type="button"
                      onClick={() => setShowPassword((visible) => !visible)}
                      aria-label={
                        showPassword ? "Ocultar contraseña" : "Mostrar contraseña"
                      }
                      aria-pressed={showPassword}
                      className="absolute top-1/2 right-2.5 -translate-y-1/2 rounded-md p-1.5 text-muted-foreground transition-colors hover:text-slate-900 focus-visible:ring-[3px] focus-visible:ring-ring/40 focus-visible:outline-none"
                    >
                      {showPassword ? (
                        <Eye className="size-4" aria-hidden />
                      ) : (
                        <EyeOff className="size-4" aria-hidden />
                      )}
                    </button>
                  </div>
                  <p
                    id={`${passwordId}-hint`}
                    className="text-xs text-muted-foreground"
                  >
                    Mínimo {MIN_PASSWORD_LENGTH} caracteres.
                  </p>
                </div>

                {error && (
                  <motion.p
                    role="alert"
                    initial={{ opacity: 0, y: -6 }}
                    animate={{ opacity: 1, y: 0 }}
                    className="flex items-start gap-2 rounded-xl border border-destructive/20 bg-destructive/5 p-3 text-sm text-destructive"
                  >
                    <AlertCircle className="mt-0.5 size-4 shrink-0" aria-hidden />
                    {error}
                  </motion.p>
                )}

                <motion.div
                  whileHover={{ scale: 1.01 }}
                  whileTap={{ scale: 0.98 }}
                  transition={{ type: "spring", stiffness: 400, damping: 25 }}
                >
                  <Button
                    type="submit"
                    variant="default"
                    size="lg"
                    className="h-[3.25rem] w-full text-base"
                    disabled={registerMutation.isPending}
                  >
                    {registerMutation.isPending && (
                      <Loader2 className="size-4 animate-spin" aria-hidden />
                    )}
                    {registerMutation.isPending ? "Creando cuenta…" : "Crear cuenta"}
                  </Button>
                </motion.div>

                <p className="text-center text-sm text-muted-foreground">
                  ¿Ya tienes cuenta?{" "}
                  <Link
                    to={ROUTES.login}
                    className="font-medium text-slate-900 underline-offset-4 hover:underline"
                  >
                    Inicia sesión
                  </Link>
                </p>
              </form>
            </CardContent>
          </Card>

          <p className="mt-8 text-center text-xs text-muted-foreground">
            FleetIoT © {new Date().getFullYear()} · Plataforma de Monitoreo v1.0
          </p>
        </motion.div>
      </div>
    </main>
  );
}
