# DESIGN.md

Documento de diseño de **IoT Fleet Monitor**: qué hace el sistema, cómo está organizado y por qué se tomaron las decisiones que se tomaron.

---

## 1. Visión general

El sistema monitorea una flota de vehículos equipados con dispositivos IoT.

Cada dispositivo reporta periódicamente su **ubicación, velocidad, nivel de combustible y temperatura**. El sistema guarda esas lecturas, calcula cuánta autonomía le queda a cada vehículo y, cuando esa autonomía cae por debajo de un umbral crítico, genera una alerta.

Todo eso se consulta desde dos clientes: un **dashboard web** y una **app móvil**. Ambos muestran el estado de la flota en tiempo real, un mapa con la posición de los vehículos, gráficos históricos y solo para administradores el panel de alertas.

Hay tres roles en juego:

| Actor | Qué hace |
|---|---|
| **Dispositivo / simulador** | Envía lecturas de telemetría al backend |
| **Usuario (`user`)** | Consulta el estado de la flota; no ve alertas ni el código completo de los dispositivos |
| **Administrador (`admin`)** | Todo lo anterior, más gestión de vehículos y acceso a las alertas predictivas |

---

## 2. Cómo está organizado

El repositorio tiene cuatro piezas independientes que se comunican por HTTP y WebSocket:

```
simulator/  ──POST /telemetry──►  backend/  ──REST + WebSocket──►  frontend/  (dashboard web)
                                     │
                                     └──REST + WebSocket──────────►  mobile/    (app Flutter)
```

### `backend/` — FastAPI + SQLAlchemy async

Sistema que habla con la base de datos. Recibe la telemetría, la valida, la almacena, calcula la predicción de autonomía y decide si hay que abrir o cerrar una alerta. También emite eventos en tiempo real a los clientes conectados.

Está dividido en capas con responsabilidades separadas:

- **`api/routes/`** — routers finos. Solo reciben la petición, verifican permisos y delegan.
- **`services/`** — la lógica de negocio real (registrar telemetría, calcular autonomía, sincronizar alertas).
- **`repositories/`** — acceso a datos. Los servicios no escriben consultas SQL directamente.
- **`models/`** — tablas SQLAlchemy. 
- **`schemas/`** — modelos Pydantic para entrada y salida.
- **`auth/`** — emisión y verificación de JWT, y las dependencias `get_current_user` / `require_admin`.
- **`websocket/`** — el gestor de conexiones y el publicador de eventos.

### `frontend/` — React 19 + Vite + TypeScript

El dashboard web. Muestra las estadisticas de la flota, el mapa (MapLibre GL), los gráficos históricos (Recharts) y el detalle de cada vehículo. Está organizado **por feature** (`features/alerts`, `features/devices`, `features/telemetry`…) para que todo lo relacionado a una funcionalidad viva junto.

### `mobile/` — Flutter

Aplicaciòn móvil de **solo consulta**: dashboard, mapa, listado de vehículos, alertas y perfil. No genera telemetría. Su diferencial es el **caché offline cifrado**, que le permite mostrar los últimos datos conocidos cuando no hay red.

### `simulator/` — Simuador de telemetría

Genera telemetría realista para probar el sistema sin hardware físico. Simula el movimiento del vehículo, el consumo progresivo de combustible y la variación de temperatura, y hace `POST /telemetry` cada 30 segundos por defecto. Incluye un escenario específico que fuerza la caída de combustible hasta disparar una alerta, para poder verificar el flujo completo.

---

## 3. Flujo principal

Un ejemplo concreto, siguiendo una sola lectura desde que se envía hasta que aparece en pantalla:

**1. El dispositivo envía la lectura.**
El simulador (o cualquier dispositivo real) hace `POST /telemetry` con un JWT válido:

```json
{
  "device_id": 3,
  "latitude": -34.6037,
  "longitude": -58.3816,
  "speed": 62.5,
  "fuel_level": 8.2,
  "temperature": 91.4
}
```

**2. El backend valida y guarda.**
Se verifica los rangos (latitud entre -90 y 90, combustible entre 0 y 100, velocidad no negativa). Si el `device_id` no existe, responde 404. Si todo está bien, guarda la lectura y actualiza el `last_seen_at` del vehículo.

**3. Calcula la autonomía restante.**
Toma las últimas 20 lecturas del dispositivo, mide cuánto combustible se consumió y en cuánto tiempo, y de ahí obtiene un consumo por hora. Con el nivel actual estima cuántas horas quedan.

En el ejemplo: si consume ~9 % por hora y le queda 8.2 %, la autonomía es de aproximadamente **55 minutos**.

**4. Decide si hay alerta.**
El umbral crítico es **1 hora**. Como quedan 55 minutos, se abre una alerta de tipo `LOW_FUEL` para ese vehículo. Si ya había una alerta abierta, no se crea otra: se reutiliza.

**5. Notifica en tiempo real.**
El backend emite un evento `telemetry_updated` por WebSocket a **todos** los clientes conectados, y un evento `alert_created` **solo a los administradores**.

**6. Los clientes actualizan la vista.**
El dashboard web recibe el evento y escribe directamente en la caché de React Query, así que el mapa, los gráficos y las estadisticas se actualizan sin recargar ni hacer polling. Si el usuario conectado es administrador, además le aparece la alerta en la campana de notificaciones y en el panel. La app móvil hace lo equivalente y muestra una notificación local.

Cuando el vehículo carga combustible y la autonomía vuelve a estar por encima del umbral, la alerta se resuelve automáticamente y se emite `alert_resolved`.

---

## 4. Decisiones importantes

### Backend y clientes separados

El backend concentra toda la lógica del sistema y no depende de quién lo consulte. La web, la aplicación móvil y el simulador son clientes de esa misma base común.

La ventaja es que las reglas del negocio —cómo se calcula la autonomía, cuándo se genera una alerta, quién puede ver qué— existen en un solo lugar. Si mañana cambia un criterio, se cambia una vez y todos los clientes lo reflejan al instante, sin riesgo de que la web y el móvil terminen mostrando cosas distintas.

### Información en tiempo real

Los datos de los vehículos cambian constantemente, y en un sistema de monitoreo la información desactualizada tiene poco valor: de nada sirve enterarse de que un vehículo se está quedando sin combustible diez minutos tarde. Por eso el sistema envía los cambios a los clientes en el momento en que ocurren, en lugar de esperar a que el usuario actualice la pantalla o consulte manualmente.

Como una conexión permanente puede cortarse —una red móvil inestable, un wifi que se cae, el teléfono que se bloquea—, tanto la web como la aplicación móvil detectan la pérdida e intentan reconectarse solas, espaciando los intentos para no saturar al servidor mientras se recupera. El usuario no tiene que recargar nada: cuando vuelve la conexión, la información se pone al día automáticamente.

### Alertas centralizadas

Las alertas se calculan siempre en el backend, nunca en la web ni en el móvil. Aunque los clientes ya reciben los datos de combustible y podrían deducir por su cuenta qué vehículos están en riesgo.

Las alertas son información restringida a administradores: si un cliente pudiera derivarlas por su cuenta, un usuario sin permisos podría reconstruir en su pantalla exactamente aquello que no debería ver.

### Permisos según el usuario

El sistema distingue entre usuarios comunes y administradores. Los primeros consultan el estado de la flota; los segundos, además, gestionan los vehículos y acceden a las alertas.

Esa distinción se aplica en dos niveles. El servidor es la barrera real: rechaza cualquier pedido de información restringida sin importar de dónde venga. Las aplicaciones, por su parte, directamente no muestran las secciones a las que la persona no tiene acceso: quien no es administrador no ve el menú de alertas, ni el contador, ni las notificaciones. La decisión de fondo es que no conviene mostrar puertas cerradas — una funcionalidad visible pero inaccesible genera confusión y sugiere que existe algo que se está ocultando.

### Protección de información sensible

El código identificador de cada dispositivo se muestra parcialmente oculto a los usuarios que no son administradores:

```
DEV-1234-XC54   →   DEV-****-XC54
```

La idea es equilibrar dos necesidades. Un operador tiene que poder reconocer de qué vehículo se está hablando, y para eso alcanza con ver una parte del código. Pero el identificador completo es lo que permitiría enviar datos en nombre de ese dispositivo, así que se reserva a quien tiene permisos de administración.

### Funcionamiento sin conexión

La aplicación móvil está pensada para usarse en movimiento, donde la conexión no siempre es buena. Por eso guarda localmente la última información que recibió y puede mostrarla aunque no haya red, indicando siempre hace cuánto se obtuvo, para que nadie confunda un dato guardado con uno actual. La información demasiado vieja se descarta directamente: la ubicación de un vehículo de ayer es más engañosa que útil.

Lo que la aplicación no hace es acumular cambios para enviarlos después. La app sirve para consultar el estado de la flota, no para modificarlo.

---

## 5. Manejo de datos y alertas

### Modelo de datos

Cuatro tablas:

- **`devices`** — el vehículo y su dispositivo: nombre, código (único), patente, si está activo y cuándo se lo vio por última vez.
- **`telemetry_readings`** — cada lectura recibida, con su marca de tiempo. Índice compuesto por `(device_id, recorded_at)`, porque prácticamente toda consulta es "las últimas N lecturas de este vehículo".
- **`alerts`** — alertas por vehículo, con tipo, mensaje y si están resueltas.
- **`users`** — usuarios con contraseña hasheada y rol (`admin` o `user`).

Las lecturas se guardan **todas**, sin agregación ni descarte. Sobre esa serie histórica se construyen los gráficos de velocidad y combustible.

### Cómo se calcula la autonomía

La lógica vive aislada en un módulo sin dependencias de base de datos ni de HTTP: recibe una lista de lecturas y devuelve una predicción. Eso lo hace trivial de testear con casos concretos, sin levantar un servidor.

El algoritmo es deliberadamente simple:

1. Requiere al menos **2 lecturas**. Con una sola no hay forma de saber a qué ritmo se consume.
2. Suma solo las **bajadas** de combustible entre lecturas consecutivas. Las subidas se ignoran, porque representan una carga de combustible, no un consumo negativo.
3. Divide ese consumo total por las horas transcurridas → consumo por hora.
4. `horas_restantes = combustible_actual / consumo_por_hora`.
5. Si `horas_restantes < 1`, corresponde alertar.

Se eligió un promedio sobre las últimas 20 lecturas en lugar de un modelo más sofisticado porque el objetivo es detectar una tendencia clara de agotamiento, no predecir con precisión de laboratorio. Un promedio sobre una ventana móvil absorbe el ruido de lecturas individuales y es explicable ante un operador, que es lo que importa cuando la alerta lo va a hacer actuar.

### Ciclo de vida de la alerta

Las alertas no se duplican ni se resuelven a mano en el caso normal:

- Si corresponde alertar y **ya existe** una alerta abierta para ese vehículo → no se hace nada. Sin esto, cada lectura recibida generaría una alerta nueva.
- Si corresponde alertar y **no hay** ninguna abierta → se crea y se notifica a los administradores.
- Si ya **no** corresponde alertar y hay una abierta → se resuelve automáticamente y se notifica.

Un administrador puede además resolver una alerta manualmente desde el dashboard.

---

## 6. Consideraciones de seguridad

**Autenticación.** JWT firmado con HMAC-SHA256, implementado a mano (sin librería de JWT), con expiración de 90 minutos. La verificación compara firmas en **tiempo constante** para no filtrar información por diferencias de tiempo de respuesta. El algoritmo de firma está fijado en el servidor y nunca se lee de la cabecera del token, lo cual descarta el ataque clásico de confusión de algoritmo (donde un atacante declara `alg: none` y el servidor le cree).

**Contraseñas.** Hasheadas con bcrypt. El hash nunca sale en ninguna respuesta de la API.

**Autorización.** Todos los endpoints exigen usuario autenticado. Las operaciones de gestión de vehículos y la totalidad de `/alerts` exigen además rol administrador. El registro público siempre crea usuarios con rol `user`: no hay forma de crear un administrador desde la API.

**Validación de entrada.** Toda petición pasa por Pydantic antes de tocar la lógica de negocio: rangos geográficos, porcentajes acotados, longitud mínima de contraseña, y coherencia de rangos de fechas en los filtros de consulta.

**CORS.** Restringido a orígenes explícitos por configuración, con `http://localhost:5173` como valor por defecto de desarrollo.

**Secretos.** La clave de firma y las credenciales se leen de variables de entorno. El simulador acepta credenciales por variable de entorno con precedencia sobre los argumentos de línea de comandos, para que no queden registradas en el historial del shell.

**Almacenamiento en el cliente móvil.** El token se guarda en el almacenamiento seguro del sistema operativo (Keychain en iOS, EncryptedSharedPreferences en Android). El caché local está cifrado con una clave AES generada en el dispositivo y guardada en ese mismo almacén seguro. Si el almacenamiento seguro falla, la app **no** cae a un almacenamiento sin cifrar: prefiere no cachear.

---

## 7. Pruebas


**Backend (~117 tests).** Cubren el cálculo de autonomía con casos límite (una sola lectura, recarga de combustible en medio de la serie, combustible en cero), el ciclo de vida completo de las alertas (creación, no duplicación, resolución automática), el enmascaramiento de códigos según rol, autenticación y permisos, y el stack de WebSocket completo, incluyendo que los eventos de alerta lleguen **solo** a administradores. Los tests corren contra una base SQLite en memoria, lo que permite ejecutar el conjunto entero en segundos sin infraestructura externa.

**Móvil (~76 archivos de test + 1 de integración).** Cubren los repositorios y el comportamiento del caché offline, el manejo del token, el gating de rutas por rol, los cuatro estados de carga de las pantallas y accesibilidad. El test de integración recorre el flujo completo de triage de una alerta.

**Simulador.** Tests de la física simulada, incluyendo un escenario que verifica que la caída de combustible efectivamente termina disparando la condición de alerta.

**Frontend (15 tests).** Cubren la lógica pura de agregación de la flota, que es donde se calculan los KPIs del dashboard. Es la cobertura más delgada del proyecto y está reconocida como tal en la sección siguiente.

Lo que se busca garantizar con esto es que **las reglas de negocio y las reglas de acceso no se rompan en silencio**. Un error de maquetación se ve al abrir la pantalla; que una alerta se emita al usuario equivocado o que la autonomía se calcule mal con una serie de datos rara, no.

---

## 8. Decisiones y limitaciones actuales

Simplificaciones asumidas conscientemente por el alcance de la prueba técnica:

**No hay autenticación a nivel de dispositivo.** `POST /telemetry` acepta a cualquier usuario autenticado, para cualquier vehículo. En producción cada dispositivo debería tener su propia credencial (API key o certificado) y solo poder reportar sobre sí mismo. Se dejó así porque el sistema de identidad de dispositivos es un problema en sí mismo y excede el alcance del ejercicio.

**No hay asignación usuario → vehículo.** Todos los usuarios ven toda la flota; la única diferencia entre roles es el acceso a alertas y el enmascaramiento de códigos. No se modeló *ownership* porque el enunciado no plantea ese requisito, y añadirlo habría implicado decisiones de producto no especificadas.

**El WebSocket es de un solo proceso.** Las conexiones activas se mantienen en memoria del backend. Con más de una instancia corriendo, un cliente conectado a la instancia A no recibiría eventos originados en la B. Escalar horizontalmente requeriría un bus externo (por ejemplo, Redis pub/sub). No se implementó porque no aporta nada a una demostración de instancia única.

**No hay refresh token.** El JWT expira a los 90 minutos y hay que volver a iniciar sesión. Un flujo de refresh es infraestructura de sesión conocida que no cambia el diseño del sistema.

**Sin rate limiting.** Ni el login ni la ingestión de telemetría tienen límite de peticiones. En producción ambos lo necesitarían.

**Paginación limitada.** Los listados aceptan un `limit` pero no ofrecen paginación por cursor. Es suficiente para el tamaño de flota del ejercicio.

**Las notificaciones móviles son locales.** Se disparan cuando la app está corriendo y el WebSocket conectado. No hay push real (Firebase/APNs) porque requeriría infraestructura de servidor y credenciales de plataforma fuera del alcance.

**Cobertura desigual en el frontend web.** Solo está testeada la lógica pura de agregación; no hay tests de componentes ni de hooks. Fue una priorización explícita: con tiempo acotado, se cubrió primero la lógica de negocio del backend y del móvil, donde un fallo silencioso tiene consecuencias reales.

**Elección de stack.** Python/FastAPI en el backend por la velocidad de desarrollo de APIs async con validación declarativa. Flutter en móvil en lugar de React Native, por preferencia y experiencia previa: la decisión no afecta al diseño del sistema, ya que el contrato con el backend es idéntico. SQLite en desarrollo y Postgres en Docker: el acceso es 100 % SQLAlchemy async, así que cambiar de motor es cambiar una variable de entorno.
