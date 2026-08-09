import { useId, useState } from "react";
import type { FormEvent } from "react";
import { Link, useNavigate } from "react-router-dom";
import { motion } from "framer-motion";
import axios from "axios";
import { AlertCircle, Eye, EyeOff, Loader2, Lock, Mail } from "lucide-react";
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
import { useLogin } from "@/features/auth/hooks/useAuth";
import { ROUTES } from "@/app/routes";

export function LoginPage() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const loginMutation = useLogin();
  const navigate = useNavigate();
  const emailId = useId();
  const passwordId = useId();

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError(null);
    try {
      await loginMutation.mutateAsync({ username: email, password });
      navigate(ROUTES.home, { replace: true });
    } catch (cause) {
      // A rejected credential and an unreachable backend are different
      // problems — telling the user "wrong password" when the server is down
      // sends them chasing the wrong fix.
      setError(
        axios.isAxiosError(cause) && cause.response?.status === 401
          ? "Credenciales inválidas. Verifica tus datos e inténtalo de nuevo."
          : "No pudimos conectar con el servidor. Inténtalo de nuevo en unos segundos.",
      );
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
                <CardTitle className="text-3xl">Iniciar sesión</CardTitle>
                <CardDescription className="text-base">
                  Ingresa tus credenciales para acceder al sistema.
                </CardDescription>
              </div>
            </CardHeader>

            <CardContent className="px-12">
              <form onSubmit={handleSubmit} noValidate className="space-y-7">
                <div className="space-y-2">
                  <Label htmlFor={emailId}>Email</Label>
                  <div className="relative">
                    <Mail
                      className="pointer-events-none absolute top-1/2 left-3.5 size-4 -translate-y-1/2 text-muted-foreground"
                      aria-hidden
                    />
                    {/* ponytail: type="text" on purpose — the backend still
                        authenticates a username ("admin"), so type="email"
                        would block the demo credentials at the browser level. */}
                    <Input
                      id={emailId}
                      type="text"
                      inputMode="email"
                      autoComplete="username"
                      placeholder="ejemplo@empresa.com"
                      // 52px, off the app's 40/44px control scale on purpose:
                      // the sign-in screen is styled to its own approved mockup
                      // and its fields and submit button share this height.
                      className="h-[3.25rem] pl-10 text-base"
                      value={email}
                      onChange={(event) => setEmail(event.target.value)}
                      required
                      autoFocus
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
                      autoComplete="current-password"
                      placeholder="••••••••"
                      className="h-[3.25rem] px-10 text-base"
                      value={password}
                      onChange={(event) => setPassword(event.target.value)}
                      required
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
                    disabled={loginMutation.isPending}
                  >
                    {loginMutation.isPending && (
                      <Loader2 className="size-4 animate-spin" aria-hidden />
                    )}
                    {loginMutation.isPending ? "Ingresando…" : "Iniciar sesión"}
                  </Button>
                </motion.div>

                <p className="text-center text-sm text-muted-foreground">
                  ¿No tienes cuenta?{" "}
                  <Link
                    to={ROUTES.register}
                    className="font-medium text-slate-900 underline-offset-4 hover:underline"
                  >
                    Crear usuario
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
