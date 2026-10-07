# Estado del proyecto — CitaSegura

> Punto de retomada. Última actualización: **2026-10-06**, commit `2f32cce`.
> Sprint 1: **6 de 7 tickets hechos**. Falta cerrar **CITA-6** (UI de registro
> y login), que en Jira sigue en **Por hacer**. Entrega: **31 de octubre**.

## Qué es el proyecto

**CitaSegura** — aplicación web segura de agendamiento de citas, desarrollada como
TCC de **Seguridad de Software** sobre el **caso DIAN**. El objetivo no es la
aplicación en sí, sino demostrar y poder defender oralmente cada control de
seguridad.

- **Stack:** Next.js 16 (App Router) + TypeScript + Tailwind CSS 4 + shadcn/ui ·
  PostgreSQL 18 local con el driver `pg` (**sin ORM**) · sesiones propias.
- **Entorno:** local, Windows. Gestor de paquetes **pnpm**. El servidor de
  desarrollo queda en **`localhost:3001`** (el 3000 está ocupado).
- **Base de datos:** `citasegura`. La aplicación se conecta con el rol de
  privilegios mínimos **`citasegura_app`**, cuya contraseña vive solo en
  `.env.local` como `DATABASE_URL` (no versionado). La contraseña del
  superusuario `postgres` está en la variable de entorno **`DB_PASSWORD`**.
- **`psql` no está en el PATH:** usar `"C:\Program Files\PostgreSQL\18\bin\psql.exe"`.

## Qué está HECHO — Sprint 1, 6 de 7 tickets (CITA-4, CITA-5, CITA-7 a CITA-10)

| Ticket | Qué quedó hecho |
|---|---|
| **CITA-4** | Proyecto Next.js con App Router, TypeScript, Tailwind 4, shadcn/ui y ESLint. |
| **CITA-5** | PostgreSQL local endurecido: esquema `users` con restricciones `CHECK`, rol `citasegura_app` de privilegios mínimos, y aislamiento del resto de bases del servidor. |
| **CITA-7** | Endpoints de registro en API Routes: `POST /api/auth/register`, con revalidación en el servidor, `INSERT` parametrizado y respuesta anti-enumeración ante correo duplicado. |
| **CITA-8** | Hashing con bcrypt: `hashPassword` / `verifyPassword` con factor de coste 12, asíncronos, con la guarda de los 72 bytes útiles de bcrypt. |
| **CITA-9** | Sesiones propias: token de 256 bits con `crypto.randomBytes`, guardado **hasheado** (SHA-256) en la tabla `sessions`, cookie `httpOnly`/`SameSite=lax`, y logout que revoca en el servidor. |
| **CITA-10** | Bloqueo de cuenta: 5 fallos consecutivos bloquean 15 minutos, contador incrementado en una sola sentencia SQL atómica, y `UPDATE` acotado a dos columnas. |

> **CITA-6 NO está en esta tabla a propósito: está incompleta.** Lo que sí
> quedó hecho de ella es el esquema Zod compartido cliente/servidor
> (`z.strictObject` contra *mass assignment*) y la página `/registro`, pero
> eso es solo la mitad del ticket. El detalle está en la sección siguiente.
>
> CITA-7 y CITA-8 se entregaron en el mismo commit que la parte hecha de
> CITA-6 (`693be08`), porque comparten una sola funcionalidad: el esquema de
> validación, el endpoint que lo revalida y el hasheo que usa ese endpoint.

**Todo lo implementado está commiteado** (el árbol de trabajo está limpio), y
las evidencias para el informe están en `db/EVIDENCIAS-FASE2.md` (21 evidencias
con la salida real de cada comando).

```
dd62cd7  Documentar las evidencias de seguridad de la fase 2 (SCRUM-2 a SCRUM-7)
e5dcc6a  SCRUM-7: bloqueo de cuenta tras 5 intentos fallidos
2cb0863  SCRUM-6: inicio de sesion con sesiones propias y cookie httpOnly
693be08  SCRUM-2 y SCRUM-3: base de datos endurecida y registro de usuario seguro
```

*Nota: los mensajes de commit conservan el código del tablero anterior
(SCRUM); la equivalencia con el tablero actual (CITA) está en la tabla de
arriba.*

## Qué falta para cerrar CITA-6 — UI de registro y login

CITA-6 cubre **las dos pantallas de autenticación y el flujo completo entre
ellas**, no solo el registro. Hoy existe `/registro` y nada más: el backend de
login está terminado y probado (`POST /api/auth/login`, con sesiones, cookie
`httpOnly` y bloqueo por intentos fallidos), y el `loginSchema` ya está escrito
en `src/lib/validations/auth.ts`, pero **ninguna pantalla los usa**. El inicio
de sesión solo se puede ejercitar con `curl` o Postman.

Los cuatro puntos que faltan:

1. **Página de login.** No existe `src/app/login/page.tsx` ni ninguna variante.
   Debe ser el espejo de `/registro`: react-hook-form + `zodResolver` sobre el
   `loginSchema` que ya está escrito, y `POST` a `/api/auth/login`. Un solo
   mensaje de error para todos los fallos — el endpoint ya responde así a
   propósito, para no filtrar si la cuenta existe ni si está bloqueada, y la
   UI no puede deshacer ese control mostrando mensajes distintos.
2. **Redirección tras el registro.** Hoy `/registro` se queda quieta: limpia
   el formulario y muestra «Ya puedes iniciar sesion», una invitación a una
   página que todavía no existe. Debe llevar al login una vez exista.
3. **Redirección tras el inicio de sesión.** El endpoint ya deja la cookie de
   sesión puesta al responder, pero no hay ninguna pantalla que lleve a la
   persona a su área privada después.
4. **Página protegida de destino.** No hay ninguna: ni dashboard, ni perfil, ni
   `middleware.ts`. `GET /api/auth/me` es la plantilla de ruta protegida, pero
   no la consume ninguna página. Sin este destino, el login no lleva a ninguna
   parte y la sesión no se puede demostrar en la interfaz.

Nota de alcance: el **dashboard completo** (lista de citas y formulario de
agendar) es **CITA-11**, del Sprint 2. Para cerrar CITA-6 basta una página
protegida mínima que confirme la sesión y permita cerrarla.

Pendiente menor del mismo frente: **no hay navegación**. Ni la portada enlaza a
`/registro`, ni `/registro` enlaza al login; solo se llega escribiendo la URL a
mano. Y `src/app/page.tsx` sigue siendo la pantalla de arranque de CITA-4, que
lista como pendientes cosas que ya están hechas.

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
| `GET /api/auth/me` | Ruta protegida de prueba y **plantilla para proteger las rutas futuras**. |
| `/registro` (`src/app/registro/page.tsx`) | Único formulario existente: react-hook-form + `zodResolver` sobre el mismo esquema del servidor. |
| `probe-auth.mts` | Script desechable que probó el esquema Zod con 13 casos. Conservado como evidencia y **excluido del type-check** en `tsconfig.json`. |

## Qué SIGUE — próximos pasos en orden

1. **CITA-6** — cerrar la UI de autenticación: página de login, las dos
   redirecciones y la página protegida de destino (ver la sección de arriba).
   Es lo único que queda del Sprint 1 y bloquea la demostración del flujo.
2. **CITA-11** — UI del dashboard y formulario de agendar cita.
3. **CITA-12** — API para crear y gestionar citas, con consultas parametrizadas.
4. **CITA-13** — **Control de acceso por objeto (anti-IDOR).** Es el control
   estrella del trabajo: demuestra exactamente el fallo del caso DIAN. Cada
   consulta de una cita debe verificar que pertenece al usuario de la sesión, no
   basta con que el id sea válido.
5. **CITA-14** — Validación estricta de entradas en el servidor.
6. **CITA-15** — Configuración segura de `.env`.
7. **Panel de administración** — ver todos los usuarios y citas, con control de
   acceso por rol (la columna `role` y su `CHECK` ya existen).
8. **Sprint de diseño (al final, antes del 31 de octubre)** — la interfaz se dejó
   deliberadamente sin pulir: ahora se ve a medias, con fuente serif y sin
   centrar. No es un error pendiente de arreglar, es una decisión de orden de
   trabajo.

## Decisiones tomadas que hay que respetar

- **Sin ORM.** Consultas parametrizadas escritas a mano, para que el control
  anti-inyección SQL sea visible en el código durante la sustentación. No
  proponer Prisma ni Drizzle.
- **Sesiones propias**, sin Auth.js/NextAuth.
- **Backend propio**, no Supabase.
- **Privilegios mínimos siempre.** La aplicación nunca se conecta como
  superusuario; si algo necesita más permisos, se concede acotado (por columna si
  hace falta), no de forma amplia.
- **Primero la lógica y la seguridad; el diseño al final.**
- Cada control debe quedar **explicado y demostrable**, porque hay que defenderlo
  oralmente.

## Pendientes menores, documentados como trabajo futuro

1. **Barrido de sesiones caducadas** — las filas expiradas ya no validan, pero se
   acumulan en la tabla.
2. **Aviso por correo** — ni el registro con correo duplicado ni el bloqueo de
   cuenta avisan a la persona afectada, porque decírselo en la respuesta HTTP
   sería un oráculo de enumeración. La solución estándar es el correo, canal que
   solo lee el dueño de la cuenta.
3. **Límite de peticiones por IP** — es la mitigación que falta para el DoS por
   bloqueo (hoy un atacante puede dejar a una víctima fuera 15 minutos con 5
   intentos basura) y el complemento natural del bloqueo por cuenta.

## Cómo arrancar

```bash
pnpm dev          # queda en http://localhost:3001
pnpm build        # compila y pasa el type-check
pnpm lint
```

La base de datos ya está creada y poblada con una sola cuenta de pruebas
(`test@gmail.com`). Los scripts de `db/` son idempotentes y se pueden volver a
ejecutar sin pérdida de datos.
