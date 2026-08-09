# Puesta en marcha con Docker

Guía para levantar el proyecto completo y comprobar que funciona. 

**Resumen:** instalas Docker, clonas el repositorio, ejecutas
`docker compose up --build` y ya tienes base de datos, backend, frontend y
simulador funcionando. Flutter es lo único que corre fuera de Docker, porque
necesita un emulador o un dispositivo físico.

| Componente | Stack | Cómo se ejecuta |
| --- | --- | --- |
| Backend | FastAPI + SQLAlchemy async + PostgreSQL | Docker |
| Frontend web | React 19 + Vite + TypeScript | Docker |
| Base de datos | PostgreSQL 16 | Docker |
| Simulador IoT | Python + httpx | Docker |
| App móvil | Flutter | **Local** (necesita emulador o dispositivo) |


---

## 1. Requisitos

## Para ejecutar el proyecto con Docker

Solo necesitas tener Docker Desktop instalado     s.
Verificación:

```bash
docker --version
docker compose version
```
 

### Solo para la app Flutter (opcional)

Únicamente si quieres evaluar también el cliente móvil:

- **Flutter 3.44+ / Dart 3.12+** ([guía de instalación](https://docs.flutter.dev/get-started/install)).
- **Un destino donde correrla**, cualquiera de estos:
  - Simulador de iOS (macOS + Xcode),
  - Emulador de Android (Android Studio),
  - un teléfono físico conectado por USB,
  - o el escritorio/navegador (`-d macos`, `-d chrome`).
- **JDK 17** solo si vas a compilar para Android:
  `export JAVA_HOME=/opt/homebrew/opt/openjdk@17`

Verificación:

```bash
flutter doctor          # todo lo relevante en verde
flutter devices         # tiene que listar al menos un destino
```

---

## 2. Configuración inicial

**Ninguna.** Todas las variables de `docker-compose.yml` tienen un valor por
defecto pensado para evaluación local, así que el paso 4 funciona sobre un
clon limpio.

Solo si quieres cambiar algo (puertos, credenciales, escenario del
simulador), copia el archivo de ejemplo y edítalo:

```bash
cp .env.example .env
```

Variables disponibles:

| Variable | Default | Para qué sirve |
| --- | --- | --- |
| `POSTGRES_USER` / `POSTGRES_PASSWORD` / `POSTGRES_DB` | `fleet` | Credenciales de PostgreSQL dentro de la red de Docker. |
| `SECRET_KEY` | `dev-secret-change-me` | Clave con la que el backend firma los JWT. |
| `CORS_ORIGINS` | `["http://localhost:5173"]` | Lista JSON de orígenes que el navegador puede usar contra la API. |
| `SEED_ADMIN_EMAIL` / `SEED_ADMIN_PASSWORD` | `admin@fleet.io` / `admin12345` | Cuenta admin de demo. |
| `SEED_USER_EMAIL` / `SEED_USER_PASSWORD` | `user@fleet.io` / `user12345` | Cuenta de usuario común de demo. |
| `VITE_API_URL` | `http://localhost:8000` | API que consulta el frontend (la resuelve el navegador). |
| `VITE_WS_URL` | `ws://localhost:8000/ws/telemetry` | WebSocket de telemetría en vivo. |
| `SIMULATOR_SCENARIO` | `demo` | Composición de la flota: `default`, `demo` o `critical`. |
| `SIMULATOR_SEED` | `42` | Semilla: la misma semilla reproduce la misma corrida. |


### Las cuentas de demo

`POST /auth/register` siempre crea cuentas con rol `user`, y no hay API
pública para crear un admin. El backend ejecuta `app/seed.py` en cada arranque y deja estas
dos cuentas creadas:

| Email | Contraseña | Rol | Qué puede hacer |
| --- | --- | --- | --- |
| `admin@fleet.io` | `admin12345` | admin | Todo: alta/baja de dispositivos, feed de alertas, `device_code` completo. |
| `user@fleet.io` | `user12345` | user | Ver la flota y la telemetría. **No** ve alertas ni el `device_code` sin enmascarar. |

El simulador usa la cuenta admin, porque dar de alta dispositivos está
restringido a ese rol.

---

## 3. Levantar el stack

```bash
docker compose up --build
```

Un solo comando levanta cuatro servicios, en orden y esperando a que cada
dependencia esté sana:

| Servicio | Puerto en tu máquina | Qué hace |
| --- | --- | --- |
| `db` | *(sin publicar)* | PostgreSQL 16. Sin puerto expuesto a propósito, para no chocar con un Postgres local. |
| `backend` | **8000** | Corre migraciones, crea las cuentas de demo y arranca FastAPI. |
| `frontend` | **5173** | Dev server de Vite con el dashboard. |
| `simulator` | *(sin puerto)* | Registra 17 vehículos y les manda telemetría cada 30 s. |

Direcciones útiles:

- Dashboard: <http://localhost:5173>
- API: <http://localhost:8000>
- Documentación interactiva (Swagger): <http://localhost:8000/docs>
- Healthcheck: <http://localhost:8000/health>


Para dejar de generar telemetría sin bajar el resto del stack:

```bash
docker compose stop simulator
docker compose start simulator
```

---

## 5. Ejecutar la app Flutter


Con el stack de Docker ya corriendo:

```bash
cd mobile
flutter pub get
flutter run
```


### A qué backend apunta

`lib/core/config/app_config.dart` resuelve la URL del backend en tiempo de
compilación, con un default que depende de la plataforma. En la mayoría de
los casos **no hay nada que configurar**:

| Destino | URL por defecto | ¿Requiere configuración? |
| --- | --- | --- |
| Simulador iOS / macOS | `http://localhost:8000` | No. |
| Emulador de Android | `http://10.0.2.2:8000` | No. `10.0.2.2` es el alias documentado del emulador hacia tu máquina; dentro del emulador `localhost` es el emulador mismo. |
| Dispositivo físico | — | **Sí.** Un teléfono en la misma red Wi-Fi no es tu máquina. |
| `-d chrome` (Flutter web) | `http://localhost:8000` | Sí, hay que habilitar CORS. Ver más abajo. |

Para un dispositivo físico, pasa la IP de tu máquina en la red local:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.50:8000
```

No hace falta nada más del lado del backend: el contenedor publica el puerto
8000 en `0.0.0.0`, así que ya es alcanzable desde la red local.

`WS_BASE_URL` se deriva sola de `API_BASE_URL` (`http→ws`, `https→wss`); solo
se pasa aparte si el WebSocket vive en otro host.

Para Flutter web, agrega a `CORS_ORIGINS` el origen que imprime
`flutter run -d chrome` (usa un puerto distinto cada vez) y reinicia el
backend con `docker compose restart backend`:

```bash
# en tu .env, reemplazando 12345 por el puerto que muestre Flutter
CORS_ORIGINS=["http://localhost:5173","http://localhost:12345"]
```

Detalles adicionales (tests, builds, limitaciones conocidas) en
[`mobile/README.md`](mobile/README.md).

---

## 6. Cómo comprobar que todo funciona

1. **La API responde** — <http://localhost:8000/health> devuelve
   `{"status":"ok"}`.

2. **Inicia sesión** en <http://localhost:5173> con `admin@fleet.io` /
   `admin12345`.

3. **El dashboard se llena solo.** El simulador registra 17 vehículos en el
   primer segundo y manda una lectura por vehículo cada 30 s. Verás
   posiciones, velocidades y combustible moviéndose **sin refrescar la
   página**: es el WebSocket empujando, no polling.

4. **Los estados especiales aparecen.** De los 17 vehículos: tres normales
   (`SIM-001` a `SIM-003`), doce críticos (`SIM-004` a `SIM-015`), uno "Sin
   señal" (`SIM-016`, registrado pero nunca reporta) y uno "Inactivo"
   (`SIM-017`).

5. **Mira la telemetría saliendo** en la consola del simulador:

   ```bash
   docker compose logs -f simulator
   ```

6. **A los 3 o 4 minutos aparece la primera alerta, y después una cada ~2
   minutos.** Los doce vehículos críticos reportan el tanque entre 63 % y 85 %
   —lo que parece sano— mientras queman 60 % del tanque por hora. El backend
   mide ese ritmo y concluye que les queda menos de una hora de autonomía:

   > *"Autonomía por debajo de una hora: quedan 59 min con 59.4 % de
   > combustible"*

   Llegan solas al panel y a la campana de la barra superior. Los tanques
   arrancan escalonados a propósito: así hay tiempo de iniciar sesión antes de
   la primera, y las siguientes llegan de a una en vez de todas juntas.

7. **Abre `/alerts`** y confirma que son las mismas alertas, con los mismos
   ids. Resuelve una desde ahí: desaparece de las dos pantallas a la vez.

   Esa alerta **vuelve a aparecer** al poco tiempo. Es correcto: la regla se
   evalúa en cada lectura y el vehículo sigue teniendo menos de una hora de
   autonomía. Para cerrarla de verdad hay que parar el simulador o esperar a
   que el vehículo cargue combustible (lo hace solo al 44 %).

   Cada alerta se queda abierta unos **15 minutos** —lo que el vehículo tarda
   en bajar de la línea de alerta (~60 %) hasta el surtidor (44 %)—, así que hay
   tiempo de sobra para abrirla, explicarla y resolverla a mano. Después el
   vehículo sale del surtidor al 66 % y repite el ciclo, que dura ~23 minutos.
   Doce vehículos escalonados sobre ese ciclo son una alerta nueva cada dos
   minutos, con varias abiertas a la vez.

8. **Comprueba los permisos por rol.** Cierra sesión y entra con
   `user@fleet.io` / `user12345`: ve la flota y la telemetría, pero no el
   feed de alertas, y el `device_code` aparece enmascarado.

9. **Abre la app Flutter** (paso 5). Se conecta al mismo backend y muestra la
   misma flota, con su propia conexión WebSocket en vivo.

---

