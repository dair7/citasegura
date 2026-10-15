# Estado del proyecto — CitaSegura

> Punto de retomada. Última actualización: **2026-10-14** (montaje en un equipo nuevo), sobre el commit `4080bea`.
> **Sprint 1 cerrado** el 6 de octubre: 7 de 7 historias, 34 puntos.
> **Sprint 2 en curso** (7 – 13 oct, 30 puntos): **CITA-18 cerrada**; **CITA-12**
> implementada y subida, con la evidencia aún sin documentar. Lo siguiente en el
> orden de dependencias es **CITA-13**.
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
  `.env.local` como `DATABASE_URL` (no versionado). Desde el **14 de octubre**
  el proyecto corre en un **equipo nuevo** (el anterior se dañó): la base se
  montó desde cero y `citasegura_app` tiene una **contraseña nueva**, porque la
  anterior salió en capturas de pantalla. La contraseña del superusuario
  `postgres` está en la variable de entorno de usuario **`PGPASSWORD`**, que
  `psql` lee sola; nunca se escribe en archivos. En el equipo anterior se
  llamaba `DB_PASSWORD`: `evidencia-cita12.sh` acepta las dos, y
  `evidencia-cita18.sh` todavía solo lee `DB_PASSWORD`.
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
en `db/EVIDENCIAS-FASE2.md`, bloques 1 a 4 (22 evidencias con la salida real de
cada comando).

## Avance del Sprint 2

| Ticket | Estado | Qué quedó hecho |
|---|---|---|
| **CITA-18** | **Cerrada** el 8 oct (`f2e485a`) | `db/appointments.sql`: tabla `appointments` con id UUID, FK al dueño con `ON DELETE CASCADE`, `CHECK` de estado (`programada`/`cancelada`), de fecha (`scheduled_at >= created_at`) y de motivo (no vacío, máximo 500 caracteres), e índice `(user_id, scheduled_at)`. Privilegios por columna: `INSERT (user_id, scheduled_at, reason)`, `UPDATE (status)`, sin `DELETE` ni `TRUNCATE`. En `roles.sql`: `REVOKE DELETE ON users` y privilegios por defecto reiniciados a `SELECT, INSERT`. Evidencias 5.1 a 5.5. |
| **CITA-12** | Implementada, verificada en la aplicación con `curl` y subida el 13 oct (`194e4ac`). **La evidencia no está documentada** en `EVIDENCIAS-FASE2.md` (punto 3 de la definición de terminado) | `POST /api/citas`, `GET /api/citas` y `POST /api/citas/[id]/cancelar`. Sesión exigida antes que nada (401), dueño tomado siempre de la sesión, listado filtrado por dueño en SQL, esquema Zod `crearCitaSchema` compartido, y el mismo 404 para una cita inexistente, ajena o con id mal formado. |

### Cabos sueltos de CITA-18, cerrados el 13 de octubre

El 8 de octubre quedaron dos cosas a medias porque falló la conexión como
`postgres`. Se cerraron el 13 de octubre, cuando esa conexión volvió a
funcionar:

1. **Salida de `\ddp` posterior al cambio.** Capturada en
   `db/scripts-evidencias/salida-cita18-ddp.txt` e incorporada a la evidencia
   5.3: la regla de las tablas pasó de `citasegura_app=arwd` (valor anotado a
   mano antes del cambio, sin salida registrada) a `citasegura_app=ar`.
2. **Cita de prueba `3360b46d-1187-4a9a-972f-481c1fbefd7b`.** Borrada como
   `postgres`, solo la cita: su dueño es `test@gmail.com`, la cuenta de pruebas
   principal, que se conserva. Constancia con la salida real en el apartado de
   limpieza del bloque 5 de `EVIDENCIAS-FASE2.md`.

### Historial de commits

```
194e4ac  feat(CITA-12): API de citas con validacion y filtrado por dueño
f2e485a  docs(CITA-18): evidencia del esquema seguro de citas en EVIDENCIAS-FASE2
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
El usuario puede **crear** una cita, **listar las suyas** y **cancelarla**.
**No puede modificarla.**

| Método | Ruta | Acción |
|---|---|---|
| `POST` | `/api/citas` | crear |
| `GET` | `/api/citas` | listar las propias |
| `POST` | `/api/citas/[id]/cancelar` | cancelar |

Dos decisiones tomadas al implementar CITA-12, que cambian lo planificado:

- **No hay `GET /api/citas/[id]`.** La lista ya devuelve todo lo que la interfaz
  necesita, y cada endpoint de más es superficie de ataque de más. El control
  anti-IDOR se demuestra igual con cancelar.
- **Cancelar es `POST .../cancelar`, no `PATCH /api/citas/[id]`.** Una acción con
  nombre propio y sin cuerpo no puede usarse para cambiar otra cosa. Un `PATCH`
  recibiría un cuerpo diciendo qué modificar, y eso reabre el *mass assignment*
  que se cerró en CITA-7. (El argumento no es `SameSite`: `lax` protege igual a
  un `PATCH` que a un `POST` entre sitios.)

El **administrador** (CITA-19) podrá consultar todas las citas y la lista de
usuarios registrados, pero **no** crear ni cancelar en nombre de otros ni
modificar cuentas.

## Qué SIGUE — Sprint 2, en orden de ejecución por dependencias

| Orden | Ticket | Tarea | Responsable | Pts | Estado |
|---|---|---|---|---|---|
| 1 | **CITA-18** | Esquema seguro de la tabla de citas | Dair | 5 | cerrada |
| 2 | **CITA-12** | API de citas parametrizada | Lina | 5 | implementada y subida; evidencia pendiente |
| 3 | **CITA-13** | Control de acceso y anti-IDOR | Dair | 8 | pendiente |
| 4 | **CITA-14** | Validación y sanitización en servidor | Javier | 5 | pendiente |
| 5 | **CITA-11** | UI dashboard + agendar cita | Javier | 5 | pendiente |
| 6 | **CITA-15** | Configuración segura de `.env` | Lina | 2 | pendiente |

Notas para lo que queda:

3. **CITA-13** — **Control de acceso por objeto (anti-IDOR).** Es el control
   estrella del trabajo: demuestra exactamente el fallo del caso DIAN. El filtro
   por dueño ya está en el código de CITA-12: las tres consultas usan el usuario
   de la sesión (`WHERE ... user_id = $2`), y cancelar responde el mismo 404 a
   una cita inexistente, ajena o con id mal formado. Al planificar CITA-12 se
   dejaron fuera, para CITA-13 y CITA-14, los cambios de permisos de la base y
   los scripts de evidencia. No hay `proxy.ts`: cada ruta comprueba la sesión
   por su cuenta.
   **Pendiente en esta tarjeta: acotar el `INSERT` sobre `users`.** Hoy
   `citasegura_app` tiene `INSERT` de tabla completa, así que puede escribir
   también `role`, `id`, `failed_attempts`, `locked_until` y `created_at`. Lo
   único que impide crear una cuenta `admin` por inyección SQL es el esquema Zod
   del registro: es una sola barrera, y en el código. La solución es la misma
   que en `appointments`: `INSERT (name, email, password_hash)` por columna en
   `roles.sql`, para que `role` lo ponga siempre la base con su `DEFAULT 'user'`.
4. **CITA-14** — El esquema `crearCitaSchema` (`z.strictObject`, reejecutado en
   el servidor) ya existe en `src/lib/validations/citas.ts` desde CITA-12.
   Pregunta abierta: cuando llega una clave no declarada, la respuesta trae
   `"errors":{}`, porque Zod la pone en `formErrors` y no en `fieldErrors` (el
   registro se comporta igual). Decidir si se informa o se deja así.
5. **CITA-11** — Dashboard con la lista de citas y el formulario de agendar;
   sustituye el contenido provisional de `/inicio`. Contrato de la API: el
   cuerpo de `POST /api/citas` es `{ scheduledAt, reason }`, y `scheduledAt`
   exige ISO 8601 **con zona horaria**. Un `<input type="datetime-local">` no la
   incluye, así que el formulario debe añadirla antes de enviar. Cancelar una
   cita ya cancelada responde 409.
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
aunque CITA-18 fuera lo primero del Sprint 2.*

## Archivos clave

### Base de datos (`db/`) — se ejecutan en este orden

| Archivo | Qué hace |
|---|---|
| `db/schema.sql` | Tabla `users`: id UUID aleatorio (anti-IDOR), y las restricciones `CHECK` que hacen imposible guardar una contraseña en texto plano, un correo en mayúsculas o un rol inventado. |
| `db/roles.sql` | Crea el rol `citasegura_app` sin `SUPERUSER`/`CREATEDB`/`CREATEROLE`. Sobre `users` le da **solo `SELECT` e `INSERT`**, y **`UPDATE` solo en `failed_attempts` y `locked_until`**; el `DELETE` se retiró con un `REVOKE` explícito en CITA-18. Reinicia los privilegios por defecto a `SELECT, INSERT` y nombra cada tabla, nunca `ON ALL TABLES`. Recibe la contraseña como variable de psql, nunca escrita en el archivo. |
| `db/sessions.sql` | Tabla `sessions`: el id es el **SHA-256 del token** (`CHECK` de 64 hexadecimales), FK a `users` con `ON DELETE CASCADE`, y `REVOKE UPDATE` para que una sesión sea inmutable. |
| `db/appointments.sql` | Tabla `appointments` (CITA-18): `CHECK` de estado, fecha y motivo, FK al dueño, y privilegios **por columna**: `INSERT (user_id, scheduled_at, reason)` y `UPDATE (status)`, sin `DELETE`. Fija sus permisos con `REVOKE ALL` y `GRANT` explícitos, sin depender de los privilegios por defecto. |
| `db/hardening-connect.sql` | `REVOKE CONNECT` de `PUBLIC` en **todas** las demás bases del servidor, leídas de `pg_database` al ejecutar (no nombradas a mano), para que una credencial filtrada de CitaSegura no alcance otros proyectos. |
| `db/EVIDENCIAS-FASE2.md` | Anexo del informe: 27 evidencias con comando y salida real (bloques 1 a 4 de Sprint 1, bloque 5 de CITA-18), tabla de controles contra OWASP y limitaciones conocidas. |
| `db/scripts-evidencias/` | Scripts que generaron las evidencias (`evidencia-cita7.sh` a `evidencia-cita10.sh`, `evidencia-cita18.sh`) y las salidas de CITA-18 (`salida-cita18.txt` y `salida-cita18-ddp.txt`). |

### Lógica de seguridad (`src/lib/`)

| Archivo | Qué hace |
|---|---|
| `src/lib/db.ts` | Único punto de acceso a PostgreSQL: pool singleton y `query()` **parametrizada**. Falla si se importa desde el navegador. |
| `src/lib/validations/auth.ts` | `registerSchema` (12 caracteres, cuatro clases, tope de 72 bytes de bcrypt, `z.strictObject` contra *mass assignment*) y `loginSchema` (sin reglas de robustez, a propósito). |
| `src/lib/validations/citas.ts` | `crearCitaSchema` (`z.strictObject` con `scheduledAt` ISO con zona obligatoria y futura, y `reason` recortado de 1 a 500 caracteres), `MOTIVO_MAX_CARACTERES` enlazado al `CHECK` de la tabla y `citaIdSchema` (UUID). |
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
| `POST /api/citas` | Sesión antes que nada (401), JSON obligatorio, `crearCitaSchema`; el dueño sale de la sesión. Un `CHECK` violado responde 400, no 500. |
| `GET /api/citas` | Lista las citas del usuario de la sesión, **filtradas por dueño en SQL** y ordenadas por fecha; no devuelve `user_id`. |
| `POST /api/citas/[id]/cancelar` | Sin cuerpo. Un único `UPDATE` atómico con `id`, dueño y `status = 'programada'`; 200 si cancela, 409 si la cita propia ya estaba cancelada, y **el mismo 404** para inexistente, ajena o id mal formado. |
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
- **Acciones con nombre propio y sin cuerpo** (`POST .../cancelar`) en lugar de
  un `PATCH` genérico, y ningún endpoint que no haga falta (no hay
  `GET /api/citas/[id]`). Ver «Alcance de las citas».
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
5. **Transiciones de estado de las citas sin control en la base** — el `CHECK`
   y el `UPDATE (status)` limitan qué valores admite el estado, pero no en qué
   orden cambia. Hoy solo el código impide `cancelada → programada`: el endpoint
   de cancelar escribe siempre `'cancelada'` y exige `status = 'programada'`. Se
   resolvería con un trigger `BEFORE UPDATE`.
6. **Aislamiento entre bases no permanente** — una base creada después de
   ejecutar `hardening-connect.sql` nace con `CONNECT` para `PUBLIC`, y
   `citasegura_app` puede entrar hasta que se vuelve a ejecutar el script.
   `ALTER DEFAULT PRIVILEGES` no admite bases y los disparadores de eventos
   no se disparan con `CREATE DATABASE` (las dos cosas se comprobaron el 14 de
   octubre). La solución real es una regla `reject` en `pg_hba.conf`. Detalle
   en la limitación 6 de `db/EVIDENCIAS-FASE2.md`.

Los puntos 2 a 6 quedan documentados como trabajo futuro.

## Cómo arrancar

```bash
pnpm dev --webpack --port 3001   # --webpack: SWC nativo bloqueado por política de Windows
pnpm build                       # compila y pasa el type-check
pnpm lint
```

### Montar la base desde cero

Es lo que se hizo el 14 de octubre en el equipo nuevo. Requisitos: PostgreSQL
18 con el servicio `postgresql-x64-18` corriendo, y `PGPASSWORD` con la
contraseña de `postgres`. `psql` no está en el PATH; en Git Bash:

```bash
PSQL="/c/Program Files/PostgreSQL/18/bin/psql.exe"
ADMIN=(-U postgres -h 127.0.0.1 -p 5432 -v ON_ERROR_STOP=1)

# 0. Dependencias
pnpm install

# 1. .env.local con una contraseña aleatoria para citasegura_app.
#    Se genera y se escribe sin mostrarla: no puede acabar en una captura.
#    'wx' no sobrescribe un .env.local existente.
node -e "const p=require('crypto').randomBytes(32).toString('hex');require('fs').writeFileSync('.env.local','DATABASE_URL=postgresql://citasegura_app:'+p+'@localhost:5432/citasegura\n',{flag:'wx'})"

# 2. Crear la base
"$PSQL" "${ADMIN[@]}" -d postgres -c "CREATE DATABASE citasegura;"

# 3. Scripts, en este orden. roles.sql recibe la contraseña leida de
#    .env.local, sin que aparezca en pantalla ni en el historial.
APP_PASS=$(sed -n 's|^DATABASE_URL=postgresql://citasegura_app:\([0-9a-f]*\)@.*|\1|p' .env.local)
"$PSQL" "${ADMIN[@]}" -d citasegura -f db/schema.sql
"$PSQL" "${ADMIN[@]}" -d citasegura -v app_password="$APP_PASS" -f db/roles.sql
unset APP_PASS
"$PSQL" "${ADMIN[@]}" -d citasegura -f db/sessions.sql
"$PSQL" "${ADMIN[@]}" -d citasegura -f db/appointments.sql
"$PSQL" "${ADMIN[@]}" -d postgres   -f db/hardening-connect.sql
```

`hardening-connect.sql` es **dinámico** desde el 14 de octubre: revoca `CONNECT`
de `PUBLIC` en todas las bases del servidor salvo `citasegura` y las
plantillas, y trata `template1` aparte. La versión anterior nombraba las bases
del equipo original y en uno nuevo se cortaba en la primera línea. Termina con
una tabla de las bases en las que puede entrar `citasegura_app`, y lo esperado
es `si` solo en `citasegura`. **Hay que volver a ejecutarlo cada vez que se cree
una base nueva en el servidor**: nace abierta, porque el `CONNECT` revocado en
`template1` no se hereda (comprobado el 14 de octubre).

Comprobado el 14 de octubre, conectando como `citasegura_app` con la cadena de
`.env.local`: no es superusuario, ve `users`, `sessions` y `appointments`,
`DELETE FROM users` da `permiso denegado` y la conexión a la base `postgres` da
`Usuario no tiene privilegios de conexión`.

Los scripts de `db/` son idempotentes y se pueden volver a ejecutar sin pérdida
de datos.

### La base arranca vacía

Una base montada desde cero **no tiene ninguna cuenta ni ninguna cita**. La
cuenta de pruebas principal hay que crearla en `/registro` antes de usar la
aplicación o de ejecutar `evidencia-cita18.sh`, que necesita al menos un
usuario.

Los datos del equipo anterior se perdieron con él. Para que quede constancia,
esto es lo que contenía el 13 de octubre, después de la limpieza:

| Cuenta | Citas | Origen |
|---|---|---|
| `test@gmail.com` | 0 | Cuenta de pruebas principal. |
| `test@ejemplo.com` | 0 | Creada el 6 de octubre; **su origen no está documentado** y nadie del equipo sabe explicarlo. |

La tabla `appointments` y la tabla `sessions` estaban vacías.

**Limpieza del 13 de octubre**, como `postgres` (la aplicación no tiene
`DELETE` sobre `users` ni sobre `appointments`), en una sola transacción:

- La cita de evidencia de CITA-18, `3360b46d…`, sin tocar `test@gmail.com`.
- Las dos cuentas de las pruebas con `curl` de CITA-12,
  `prueba.cita12.a.1791943252@example.com` y
  `prueba.cita12.b.1791943252@example.com`, con
  `DELETE FROM users WHERE email LIKE 'prueba.cita12.%'`. Sus 5 citas y sus 2
  sesiones se borraron en cascada (`ON DELETE CASCADE`).
