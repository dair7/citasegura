# Estado del proyecto — CitaSegura

> Punto de retomada. Última actualización: **2026-10-08**, commit `6d383d1`.
> **Sprint 1 cerrado** el 6 de octubre: 7 de 7 historias, 34 puntos.
> **Sprint 2 en curso** (7 – 13 oct, 30 puntos): toca empezar por **CITA-18**.
> Entrega final: **31 de octubre**.

## Qué es el proyecto

**CitaSegura** — aplicación web segura de agendamiento de citas, desarrollada como
TCC de **Seguridad de Software** sobre el **caso DIAN**. El objetivo no es la
aplicación en sí, sino demostrar y poder defender oralmente cada control de
seguridad.

- **Equipo:** Dair, Lina y Javier.
- **Stack:** Next.js 16 (App Router) + TypeScript + Tailwind CSS 4 + shadcn/ui ·
  PostgreSQL 18 local con el driver `pg` (**sin ORM**) · sesiones propias.
- **Entorno:** local, Windows. Gestor de paquetes **pnpm**. El servidor de
  desarrollo queda en **`localhost:3001`** (el 3000 está ocupado) y arranca con
  **`--webpack`** porque una política de Windows bloquea el binario nativo de SWC.
- **Base de datos:** `citasegura`. La aplicación se conecta con el rol de
  privilegios mínimos **`citasegura_app`**, cuya contraseña vive solo en
  `.env.local` como `DATABASE_URL` (no versionado). La contraseña del
  superusuario `postgres` está en la variable de entorno **`DB_PASSWORD`**.
- **`psql` no está en el PATH:** usar `"C:\Program Files\PostgreSQL\18\bin\psql.exe"`.

## Cronograma

| Sprint | Tema | Fechas | Estado |
|---|---|---|---|
| 0 | Preparación | 28 – 29 sep | cerrado |
| 1 | Autenticación | 30 sep – 6 oct | cerrado, 34 pts |
| 2 | Citas y control de acceso | 7 – 13 oct | **en curso**, 30 pts |
| 3 | Verificación y entrega | 14 – 20 oct | planificado, 16 pts |

## Definición de terminado

Acordada en la retrospectiva del Sprint 1. Una historia está terminada cuando:

1. La funcionalidad se ejecuta en local y se comprobó su comportamiento **en la
   aplicación**, no solo en el código.
2. El código está confirmado y subido al repositorio.
3. La evidencia queda documentada **dentro del mismo sprint**.

## Qué está HECHO — Sprint 1, 7 de 7 historias (CITA-4 a CITA-10)

| Ticket | Qué quedó hecho |
|---|---|
| **CITA-4** | Proyecto Next.js con App Router, TypeScript, Tailwind 4, shadcn/ui y ESLint. |
| **CITA-5** | PostgreSQL local endurecido: esquema `users` con restricciones `CHECK`, rol `citasegura_app` de privilegios mínimos, y aislamiento del resto de bases del servidor. |
| **CITA-6** | UI de autenticación completa: `/registro` (rediseñada), `/login` e `/inicio` (pantalla protegida con botón de cerrar sesión). Esquema Zod compartido cliente/servidor con `z.strictObject` contra *mass assignment*. Flujo completo: registro → login → `/inicio` → cerrar sesión. |
| **CITA-7** | Endpoints de registro en API Routes: `POST /api/auth/register`, con revalidación en el servidor, `INSERT` parametrizado y respuesta anti-enumeración ante correo duplicado. |
| **CITA-8** | Hashing con bcrypt: `hashPassword` / `verifyPassword` con factor de coste 12, asíncronos, con la guarda de los 72 bytes útiles de bcrypt. |
| **CITA-9** | Sesiones propias: token de 256 bits con `crypto.randomBytes`, guardado **hasheado** (SHA-256) en la tabla `sessions`, cookie `httpOnly`/`SameSite=lax`, y logout que revoca en el servidor. |
| **CITA-10** | Bloqueo de cuenta: 5 fallos consecutivos bloquean 15 minutos, contador incrementado en una sola sentencia SQL atómica, y `UPDATE` acotado a dos columnas. |

**Todo lo implementado está commiteado**, y las evidencias para el informe están
en `db/EVIDENCIAS-FASE2.md` (21 evidencias con la salida real de cada comando).

```
6d383d1  feat(CITA-6): pantallas de login, inicio y rediseño de registro
2f32cce  docs: scripts de evidencias del Sprint 1 (CITA-7 a CITA-10)
08a635b  docs: migrar codigos de tarea SCRUM a CITA y documentar el proyecto
dd62cd7  Documentar las evidencias de seguridad de la fase 2 (SCRUM-2 a SCRUM-7)
e5dcc6a  SCRUM-7: bloqueo de cuenta tras 5 intentos fallidos
2cb0863  SCRUM-6: inicio de sesion con sesiones propias y cookie httpOnly
693be08  SCRUM-2 y SCRUM-3: base de datos endurecida y registro de usuario seguro
```

*Nota: los commits anteriores a `08a635b` conservan el código del tablero
anterior (SCRUM); la equivalencia con el tablero actual (CITA) está en la tabla
de arriba.*

## Alcance de las citas (decidido en la planificación del Sprint 2)

Una cita tiene: **dueño, fecha y hora, motivo, estado y fecha de creación**.
El usuario puede **crear** una cita, **listar las suyas**, **ver una** y
**cancelarla**. **No puede modificarla.**

| Método | Ruta | Acción |
|---|---|---|
| `POST` | `/api/citas` | crear |
| `GET` | `/api/citas` | listar las propias |
| `GET` | `/api/citas/[id]` | ver una |
| `PATCH` | `/api/citas/[id]` | cancelar |

El **administrador** (CITA-19) podrá consultar todas las citas y la lista de
usuarios registrados, pero **no** crear ni cancelar en nombre de otros ni
modificar cuentas.

## Qué SIGUE — Sprint 2, en orden de ejecución por dependencias

| Orden | Ticket | Tarea | Responsable | Pts |
|---|---|---|---|---|
| 1 | **CITA-18** | Esquema seguro de la tabla de citas | Dair | 5 |
| 2 | **CITA-12** | API de citas parametrizada | Lina | 5 |
| 3 | **CITA-13** | Control de acceso y anti-IDOR | Dair | 8 |
| 4 | **CITA-14** | Validación y sanitización en servidor | Javier | 5 |
| 5 | **CITA-11** | UI dashboard + agendar cita | Javier | 5 |
| 6 | **CITA-15** | Configuración segura de `.env` | Lina | 2 |

Notas para cada uno:

1. **CITA-18** — Nuevo script SQL idempotente para la tabla de citas, en la
   línea de `schema.sql` y `sessions.sql`: id UUID, FK al dueño, `CHECK` sobre
   el estado. Como el usuario solo puede *cancelar*, el único `UPDATE` que la
   aplicación necesita es sobre la columna de estado: se concede acotado a esa
   columna, igual que `failed_attempts`/`locked_until` en `users`.
   **Antes de crear la tabla, comprobar con `\ddp` en psql** que los privilegios
   por defecto del esquema `public` no incluyen `UPDATE`: una versión antigua de
   `roles.sql` lo concedía, y la versión actual no lo retira de una base ya
   montada.
2. **CITA-12** — Los cuatro endpoints de la tabla de arriba, siempre con
   `query()` parametrizada.
3. **CITA-13** — **Control de acceso por objeto (anti-IDOR).** Es el control
   estrella del trabajo: demuestra exactamente el fallo del caso DIAN. Cada
   consulta de una cita debe filtrar por el usuario de la sesión, no basta con
   que el id sea válido. La plantilla de protección es `src/app/inicio/page.tsx`
   (páginas) y `GET /api/auth/me` (API); no hay `proxy.ts`, así que cada ruta
   comprueba la sesión por su cuenta.
4. **CITA-14** — Esquemas Zod `z.strictObject` para las citas, reejecutados en
   el servidor.
5. **CITA-11** — Dashboard con la lista de citas y el formulario de agendar;
   sustituye el contenido provisional de `/inicio`.
6. **CITA-15** — Configuración segura de `.env`.

### Sprint 3 — Verificación y entrega (14 – 20 oct)

| Ticket | Tarea | Responsable | Pts |
|---|---|---|---|
| **CITA-19** | Vista de administrador (citas y usuarios) | Dair | 8 |
| **CITA-16** | Pruebas de seguridad (re-test) | Javier | 5 |
| **CITA-17** | Documentar matriz OWASP | Lina | 3 |

CITA-19 aprovecha la columna `role` y su `CHECK`, que ya existen en `users`.

*CITA-18 y CITA-19 se crearon en la retrospectiva del Sprint 1, al detectar que
eran entregables que faltaban en el backlog. Por eso su numeración es alta
aunque CITA-18 sea lo primero que toca hacer.*

## Archivos clave

### Base de datos (`db/`) — se ejecutan en este orden

| Archivo | Qué hace |
|---|---|
| `db/schema.sql` | Tabla `users`: id UUID aleatorio (anti-IDOR), y las restricciones `CHECK` que hacen imposible guardar una contraseña en texto plano, un correo en mayúsculas o un rol inventado. |
| `db/roles.sql` | Crea el rol `citasegura_app` sin `SUPERUSER`/`CREATEDB`/`CREATEROLE`, le da `SELECT/INSERT/DELETE` y **`UPDATE` solo en `failed_attempts` y `locked_until`**. Recibe la contraseña como variable de psql, nunca escrita en el archivo. |
| `db/sessions.sql` | Tabla `sessions`: el id es el **SHA-256 del token** (`CHECK` de 64 hexadecimales), FK a `users` con `ON DELETE CASCADE`, y `REVOKE UPDATE` para que una sesión sea inmutable. |
| `db/hardening-connect.sql` | `REVOKE CONNECT` en las demás bases del servidor local, para que una credencial filtrada de CitaSegura no alcance otros proyectos. |
| `db/EVIDENCIAS-FASE2.md` | Anexo del informe: 21 evidencias con comando y salida real, tabla de controles contra OWASP y limitaciones conocidas. |

### Lógica de seguridad (`src/lib/`)

| Archivo | Qué hace |
|---|---|
| `src/lib/db.ts` | Único punto de acceso a PostgreSQL: pool singleton y `query()` **parametrizada**. Falla si se importa desde el navegador. |
| `src/lib/validations/auth.ts` | `registerSchema` (12 caracteres, cuatro clases, tope de 72 bytes de bcrypt, `z.strictObject` contra *mass assignment*) y `loginSchema` (sin reglas de robustez, a propósito). |
| `src/lib/auth/password.ts` | `hashPassword` y `verifyPassword` con bcryptjs coste 12, asíncronas, con guarda de 72 bytes en ambos sentidos. |
| `src/lib/auth/session.ts` | `createSession` / `getSession` / `destroySession`. Genera el token, lo hashea, gestiona la cookie y valida la caducidad **en SQL contra `now()`**. |
| `src/lib/auth/lockout.ts` | La política de bloqueo (5 intentos, 15 minutos) y las dos operaciones atómicas de contador. Documenta la limitación de DoS por bloqueo. |

### Endpoints y páginas (`src/app/`)

| Ruta | Qué hace |
|---|---|
| `POST /api/auth/register` | Revalida con Zod, hashea **antes** de insertar y responde igual exista o no el correo (anti-enumeración, incluido el tiempo). |
| `POST /api/auth/login` | Verificación bcrypt **siempre** (hash señuelo si el correo no existe), comprobación de bloqueo **después** del hasheo, y una única respuesta de fallo. |
| `POST /api/auth/logout` | `DELETE` de la fila más borrado de cookie. Es POST y no GET a propósito. |
| `GET /api/auth/me` | Ruta protegida de prueba y **plantilla para proteger las rutas de API futuras**. |
| `/registro` | Formulario de alta: react-hook-form + `zodResolver` sobre el mismo esquema del servidor. Enlaza a `/login`. |
| `/login` | Formulario de acceso sobre `loginSchema`, un solo mensaje para todos los fallos; tras el éxito lleva a `/inicio`. |
| `/inicio` | **Server Component protegido**: resuelve la sesión con `getSession()` antes de renderizar y redirige a `/login` si no la hay. Plantilla de las páginas protegidas del Sprint 2. |
| `probe-auth.mts` | Script desechable que probó el esquema Zod con 13 casos. Conservado como evidencia y **excluido del type-check** en `tsconfig.json`. |

## Decisiones tomadas que hay que respetar

- **Sin ORM.** Consultas parametrizadas escritas a mano, para que el control
  anti-inyección SQL sea visible en el código durante la sustentación. No
  proponer Prisma ni Drizzle.
- **Sesiones propias**, sin Auth.js/NextAuth.
- **Backend propio**, no Supabase.
- **Privilegios mínimos siempre.** La aplicación nunca se conecta como
  superusuario; si algo necesita más permisos, se concede acotado (por columna si
  hace falta), no de forma amplia.
- **Las citas no se modifican**, solo se cancelan. El administrador solo
  consulta.
- **Primero la lógica y la seguridad; el diseño al final.**
- Cada control debe quedar **explicado y demostrable**, porque hay que defenderlo
  oralmente.

## Pendientes menores

1. **Portada desactualizada** — `src/app/page.tsx` sigue siendo la pantalla de
   arranque de CITA-4: lista como pendientes la conexión a PostgreSQL, las API
   Routes y la autenticación (todo hecho) y no enlaza a `/login` ni a
   `/registro`.
2. **Barrido de sesiones caducadas** — las filas expiradas ya no validan, pero se
   acumulan en la tabla.
3. **Aviso por correo** — ni el registro con correo duplicado ni el bloqueo de
   cuenta avisan a la persona afectada, porque decírselo en la respuesta HTTP
   sería un oráculo de enumeración. La solución estándar es el correo, canal que
   solo lee el dueño de la cuenta.
4. **Límite de peticiones por IP** — es la mitigación que falta para el DoS por
   bloqueo (hoy un atacante puede dejar a una víctima fuera 15 minutos con 5
   intentos basura) y el complemento natural del bloqueo por cuenta.

Los puntos 2 a 4 quedan documentados como trabajo futuro.

## Cómo arrancar

```bash
pnpm dev --webpack --port 3001   # --webpack: SWC nativo bloqueado por política de Windows
pnpm build                       # compila y pasa el type-check
pnpm lint
```

La base de datos ya está creada y poblada con una sola cuenta de pruebas
(`test@gmail.com`). Los scripts de `db/` son idempotentes y se pueden volver a
ejecutar sin pérdida de datos.
