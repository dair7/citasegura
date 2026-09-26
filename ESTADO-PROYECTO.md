# Estado del proyecto — CitaSegura

> Punto de retomada. Última actualización: **2026-09-25**, commit `dd62cd7`.
> Sprint 1 (SCRUM-1 a SCRUM-7) completo y commiteado. Entrega: **31 de octubre**.

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

## Qué está HECHO — Sprint 1 completo (SCRUM-1 a SCRUM-7)

| Ticket | Qué quedó hecho |
|---|---|
| **SCRUM-1** | Proyecto Next.js con App Router, TypeScript, Tailwind 4, shadcn/ui y ESLint. |
| **SCRUM-2** | PostgreSQL local endurecido: esquema `users` con restricciones `CHECK`, rol `citasegura_app` de privilegios mínimos, y aislamiento del resto de bases del servidor. |
| **SCRUM-3** | Registro seguro: validación Zod compartida cliente/servidor, hasheo bcrypt coste 12, `INSERT` parametrizado y respuesta anti-enumeración ante correo duplicado. |
| **SCRUM-6** | Sesiones propias: token de 256 bits con `crypto.randomBytes`, guardado **hasheado** (SHA-256) en la tabla `sessions`, cookie `httpOnly`/`SameSite=lax`, y logout que revoca en el servidor. |
| **SCRUM-7** | Bloqueo de cuenta: 5 fallos consecutivos bloquean 15 minutos, contador incrementado en una sola sentencia SQL atómica, y `UPDATE` acotado a dos columnas. |

> La numeración salta de SCRUM-3 a SCRUM-6: los tickets 4 y 5 no se abordaron en
> esta fase. Confirmar en el tablero si quedan pendientes o si corresponden a
> otra cosa.

**Todo está commiteado**, y las evidencias para el informe están en
`db/EVIDENCIAS-FASE2.md` (21 evidencias con la salida real de cada comando).

```
dd62cd7  Documentar las evidencias de seguridad de la fase 2 (SCRUM-2 a SCRUM-7)
e5dcc6a  SCRUM-7: bloqueo de cuenta tras 5 intentos fallidos
2cb0863  SCRUM-6: inicio de sesion con sesiones propias y cookie httpOnly
693be08  SCRUM-2 y SCRUM-3: base de datos endurecida y registro de usuario seguro
```

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

1. **SCRUM-8** — UI del dashboard y formulario de agendar cita.
2. **SCRUM-9** — API para crear y gestionar citas, con consultas parametrizadas.
3. **SCRUM-10** — **Control de acceso por objeto (anti-IDOR).** Es el control
   estrella del trabajo: demuestra exactamente el fallo del caso DIAN. Cada
   consulta de una cita debe verificar que pertenece al usuario de la sesión, no
   basta con que el id sea válido.
4. **SCRUM-11** — Validación estricta de entradas en el servidor.
5. **SCRUM-12** — Configuración segura de `.env`.
6. **Panel de administración** — ver todos los usuarios y citas, con control de
   acceso por rol (la columna `role` y su `CHECK` ya existen).
7. **Sprint de diseño (al final, antes del 31 de octubre)** — la interfaz se dejó
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
