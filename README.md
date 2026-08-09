# IoT Fleet Monitor

Monitoreo de una flota de vehículos: dispositivos IoT reportan telemetría
(posición, velocidad, combustible, temperatura), el backend evalúa una regla
de autonomía y levanta alertas, y todo se ve en vivo en un dashboard web y en
una app móvil.

### Inicio rápido

Para probar el proyecto, la forma más sencilla es utilizar Docker. 
```bash
docker compose up --build
```

Esto levantará los servicios necesarios para ejecutar la aplicación.

Para ver la configuración completa, las cuentas de prueba y los pasos para ejecutar la aplicación móvil, consulta [`SETUP.md`](./SETUP.md).


Esta página es para ejecutar cada componente **a mano**, sin Docker: útil para
correr los tests o depurar una parte por separado. Incluye además la
referencia completa del simulador de telemetría.

| Componente | Stack | Puerto |
| --- | --- | --- |
| Backend | FastAPI + SQLAlchemy async | 8000 |
| Frontend web | React 19 + Vite + TypeScript | 5173 |
| App móvil | Flutter (Riverpod, GoRouter, Dio) | — |
| Simulador IoT | Python + httpx | — |

Fuera de Docker el backend usa SQLite (`backend/fleet.db`) en vez de
PostgreSQL. Es la única diferencia de fondo entre los dos modos.

Índice:

- [Backend](#backend)
- [Frontend](#frontend)
- [App móvil](#app-móvil)
- [Referencia del simulador](#referencia-del-simulador)
- [Corridas reproducibles](#corridas-reproducibles)
- [Forzar una alerta de combustible](#forzar-una-alerta-de-combustible)
- [Parar y reiniciar](#parar-y-reiniciar)
- [Limitaciones conocidas](#limitaciones-conocidas)

---

## Backend

Requiere Python 3.10 o superior (las imágenes de Docker usan 3.12 y 3.13).

```bash
cd backend
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
alembic upgrade head                   # crea el esquema
python -m app.seed                     # crea las cuentas de demo
uvicorn app.main:app --reload          # http://localhost:8000
pytest                                 # 121 tests
```

No hace falta ningún archivo de configuración: los valores por defecto de
`app/core/config.py` ya sirven para desarrollo local. Apuntar `DATABASE_URL` a
PostgreSQL es lo único necesario para cambiar la base de datos, y es
exactamente lo que hace `docker-compose.yml`.

`python -m app.seed` crea las dos cuentas de demo, o las que indiquen las
variables `SEED_ADMIN_*` / `SEED_USER_*`:

| Email | Contraseña | Rol |
| --- | --- | --- |
| `admin@fleet.io` | `admin12345` | admin — alertas y alta de dispositivos |
| `user@fleet.io` | `user12345` | user — solo flota y telemetría |

Es idempotente: volver a ejecutarlo después de reiniciar el esquema es toda la
recuperación necesaria.

## Frontend

Requiere Node 22 (es la versión que usa la imagen de Docker; Vite 8 no soporta
versiones anteriores a Node 20.19).

```bash
cd frontend
npm install
cp .env.example .env
npm run dev                            # http://localhost:5173
npm test                               # 15 tests
npm run lint                           # oxlint
npm run build                          # tsc -b && vite build
```

`.env.example` ya apunta al backend local (`http://localhost:8000`), así que no
hay nada que editar si ejecutaste el backend con el comando de arriba.

## App móvil

Flutter siempre se ejecuta en local, con o sin Docker, porque necesita un
emulador o un dispositivo conectado.

```bash
cd mobile
flutter pub get
flutter run                            # toma el dispositivo que esté conectado
flutter test                           # unit + widget tests
```

Por defecto apunta a `http://localhost:8000` (o `http://10.0.2.2:8000` en el
emulador de Android, que es el alias documentado hacia la máquina anfitriona).
Para un dispositivo físico hay que pasar la IP de tu máquina:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.50:8000
```

Si ejecutas el backend a mano, arráncalo escuchando en todas las interfaces
—`uvicorn app.main:app --host 0.0.0.0 --reload`— porque el default de uvicorn
(`127.0.0.1`) no es alcanzable desde un teléfono. Con Docker esto ya viene
resuelto.

La matriz completa de `--dart-define`, los builds y las limitaciones conocidas
del cliente móvil están en [`mobile/README.md`](mobile/README.md).

---

## Referencia del simulador

Una pequeña flota de vehículos que reporta telemetría al backend por la misma
API REST que usaría un dispositivo real. No tiene ningún acceso privilegiado:
inicia sesión, registra sus dispositivos y publica lecturas.

```bash
cd simulator
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements-dev.txt
pytest                                 # 100 tests
```

### Hace falta una cuenta admin

Registrar dispositivos es solo para admin (`POST /devices`), y `GET /devices`
enmascara el `device_code` para el resto — que es justamente el campo por el
que el simulador decide si un dispositivo ya existe. Con una cuenta no admin no
puede encontrar su propia flota ni crearla.

`python -m app.seed` (que `docker-compose.yml` ejecuta solo, ver
[Backend](#backend)) crea ese admin, así que no hay que promover nada a mano.

Las credenciales nunca van en la línea de comandos de una terminal compartida:

```bash
export SIMULATOR_EMAIL=admin@fleet.io
export SIMULATOR_PASSWORD=admin12345
```

También funcionan `--email` / `--password` y un archivo `--config`. El orden de
precedencia es: valores por defecto, archivo `--config`, variables de entorno y,
por encima de todo, los flags.

### Ejecutarlo

```bash
cd simulator
python -m simulator --scenario demo --seed 42
```

### Parámetros que importan

| Flag | Por defecto | Qué hace |
| --- | --- | --- |
| `--scenario` | `default` | Composición de la flota: `default`, `demo`, `critical` |
| `--seed` | ninguna | Hace la corrida reproducible, lectura por lectura |
| `--devices` | `5` | Tamaño de la flota — **solo** con `--scenario default` |
| `--interval` | `30` | Segundos entre lecturas de cada vehículo |
| `--base-url` | `http://localhost:8000` | Backend al que reportar |
| `--duration` | ninguna | Parar después de N segundos; sin esto corre hasta Ctrl+C |
| `--fuel-rate` | `9.0` | Porcentaje de tanque quemado por hora a velocidad de crucero |
| `--device-prefix` | `SIM` | Prefijo del código de dispositivo y de la patente |
| `--no-refuel` | desactivado | Deja el vehículo vacío en vez de recargarlo |
| `--config` | ninguno | Archivo JSON con cualquiera de estos valores, más `profiles` |

No bajes `--interval` de ~30s. El backend promedia el consumo sobre las últimas
veinte lecturas del vehículo; a pocos segundos por lectura esa ventana cubre
apenas un minuto de manejo, y entonces el ritmo que mide cruza el umbral de una
hora por puro ruido del sensor — lo que produce una cadena de alertas
duplicadas, no una demo más reactiva.

### Escenarios

`default` — `--devices` vehículos comunes, con el tanque entre 60% y 100%. No
alerta nada: es la foto de "la flota está sana".

`demo` — diecisiete vehículos que cubren todos los estados que pinta el
dashboard:

| Dispositivo | Perfil | Comportamiento |
| --- | --- | --- |
| `SIM-001` … `SIM-003` | `normal` | 60–100% de combustible, 9%/h — nunca alertan |
| `SIM-004` … `SIM-015` | `critical` | 63–85% de combustible pero 60%/h — escalonados: uno alerta cada ~2 min, y cada alerta dura ~15 min |
| `SIM-016` | `no-signal` | Registrado, nunca reporta → "Sin señal" |
| `SIM-017` | `inactive` | Registrado con `is_active: false` → "Inactivo" |

`critical` — un vehículo normal y los doce críticos. Para cuando lo que
interesa es la regla de alertas y no la flota.

### Flotas a medida

Un archivo JSON pasado por `--config` puede describir la flota perfil por
perfil. Los perfiles explícitos tienen prioridad sobre `--scenario`.

```json
{
  "seed": 42,
  "interval_seconds": 30,
  "profiles": [
    { "label": "normal", "count": 4 },
    { "label": "thirsty", "count": 1, "fuel_min": 30, "fuel_max": 35,
      "consumption_per_hour": 50, "idle_probability": 0.0,
      "refuel_at": 30, "refuel_to": 56 },
    { "label": "silent", "count": 1, "silent_after_ticks": 0 },
    { "label": "parked", "count": 1, "is_active": false, "silent_after_ticks": 0 }
  ]
}
```

```bash
python -m simulator --config fleet.json
```

Las claves desconocidas se rechazan al arrancar en vez de ignorarse: un error de
tipeo que construye la flota por defecto en silencio es exactamente lo que no
quieres descubrir a mitad de una demo.

## Corridas reproducibles

```bash
python -m simulator --scenario demo --seed 42
```

La misma semilla con los mismos flags produce la misma flota y las mismas
lecturas: cada vehículo saca sus números de un generador propio derivado de la
semilla, así que la concurrencia no altera el resultado. Sin `--seed`, cada
corrida es distinta.

## Forzar una alerta de combustible

La regla vive en el backend y el simulador no puede saltársela: el vehículo
tiene que tener realmente menos de una hora de autonomía, medida contra las
marcas de tiempo que asigna el servidor. Dos formas rápidas de llegar ahí:

```bash
# Los vehículos críticos ya calibrados: primera alerta a los ~3 min, después
# una cada ~2 min
python -m simulator --scenario critical --seed 42

# O empujar a toda la flota: 100% del tanque por hora deja a todos cortos
python -m simulator --fuel-rate 100
```

La autonomía es `fuel_level / consumption_rate`, así que la alerta salta cuando
el porcentaje del tanque cae por debajo del ritmo de consumo por hora. Por eso
un vehículo al 40% quemando 60%/h alerta, y otro al 40% quemando 9%/h no. Ese
es todo el punto de que la regla sea predictiva y no un simple umbral de
combustible.

### Cada cuánto se repite

Tres decisiones del perfil `critical`, todas medidas contra la regla real del
backend:

- **No vacía el tanque.** Sale del surtidor al 66 % —justo por encima de la
  línea de alerta, que a 60 %/h está en ~60 % del tanque— y no vuelve a cargar
  hasta el 44 %. Pasa unos 15 minutos por debajo de la línea, que es lo que
  dura su alerta abierta, y una vuelta entera son ~23 minutos, contra la hora y
  media que cuesta drenar un tanque completo. Los dos extremos son `refuel_at`
  y `refuel_to`, configurables por perfil desde un archivo `--config`.
- **Quema parejo** (`consumption_jitter: 0.03` contra el ±15 % del resto de la
  flota). La autonomía cae 1,7 % por minuto, así que un vehículo cruzando el
  umbral pasa varios minutos a un punto o dos de la línea; con el ruido normal
  la alerta se abre y se cierra sola varias veces en cada cruce.
- **Arrancan escalonados.** Doce vehículos repartidos sobre una vuelta de la
  franja: el primero alerta a los ~3 minutos —tiempo de iniciar sesión— y los
  demás cada ~2 minutos, en vez de todos a la vez.

La franja no se puede apretar mucho más: por debajo de ~12 puntos de ancho, la
pausa de carga arrastra el consumo que mide el backend en su ventana de veinte
lecturas y la línea de alerta se sale de la franja.

## Parar y reiniciar

`Ctrl+C` detiene la flota limpiamente, o usa `--duration 300` para que pare
sola.

Al reiniciar se reutilizan los dispositivos ya registrados bajo los mismos
códigos: no se duplican, y se reconcilia `is_active` para que un escenario con
semilla se vea igual en su segunda corrida. El *estado* del vehículo no
sobrevive al reinicio: tanques y posiciones se sortean de nuevo desde el perfil,
así que un vehículo reiniciado parece saltar en el mapa y recargarse solo. Con
`--seed` salta siempre al mismo lugar.
