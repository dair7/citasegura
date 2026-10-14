# CitaSegura

Sistema de agendamiento de citas con seguridad desde el diseño. Trabajo de
Conclusión de Curso (TCC) de **Seguridad de Software**, Universidad de
Cartagena.

## Contexto

El proyecto responde al incidente de la **DIAN de 2026**, en el que se
filtraron datos personales desde su sistema de agendamiento de citas. Ese
caso define el alcance: un agendador de citas no es una aplicación trivial
—custodia nombres, correos y horarios de personas identificables—, así que
cada decisión técnica aquí se toma y se documenta desde el control de
seguridad que la justifica, no desde la comodidad de implementación.

El énfasis está en los controles que fallaron o pudieron fallar en ese
incidente: autenticación robusta, control de acceso por objeto (IDOR),
mínimo privilegio en base de datos y no exposición de datos sensibles.

## Stack

| Capa | Tecnología |
|---|---|
| Framework | Next.js 16 (App Router) + TypeScript |
| UI | Tailwind CSS 4 + shadcn/ui |
| API | API Routes propias (sin BaaS) |
| Base de datos | PostgreSQL 18 local |
| Acceso a datos | driver `pg`, consultas parametrizadas, **sin ORM** |
| Hashing | bcrypt, factor de coste 12 |
| Validación | Zod, esquema compartido cliente/servidor |
| Sesiones | propias, token opaco, cookie `httpOnly` |
| Gestor de paquetes | pnpm |

Se evitó deliberadamente un ORM y un proveedor de autenticación externo:
el objetivo académico es que los controles anti-inyección y de sesión
queden **visibles en el código** y sean auditables, no delegados a una capa
de abstracción.

## Requisitos previos

- Node.js 20 o superior
- pnpm
- PostgreSQL 18 corriendo en `localhost:5432`, con acceso de superusuario
  (`postgres`) para el montaje inicial

## Puesta en marcha

### 1. Dependencias

```bash
pnpm install
```

### 2. Base de datos

Crear la base y ejecutar los scripts **en este orden** (cada uno es
idempotente; los posteriores dependen de los anteriores):

```bash
# Crear la base de datos
psql -U postgres -c "CREATE DATABASE citasegura;"

# 1. Esquema: tabla users con restricciones CHECK
psql -U postgres -d citasegura -v ON_ERROR_STOP=1 -f db/schema.sql

# 2. Rol de aplicación con privilegios mínimos
#    La contraseña se pasa como variable, NO vive en el archivo
psql -U postgres -d citasegura -v ON_ERROR_STOP=1 \
     -v app_password="LA_CONTRASENA" -f db/roles.sql

# 3. Tabla de sesiones (FK a users, requiere el rol ya creado)
psql -U postgres -d citasegura -v ON_ERROR_STOP=1 -f db/sessions.sql

# 4. Tabla de citas (FK a users, requiere el rol ya creado)
#    Fija sus propios privilegios por columna; no depende de los por defecto
psql -U postgres -d citasegura -v ON_ERROR_STOP=1 -f db/appointments.sql

# 5. Endurecimiento: aislar citasegura_app de las demás bases del servidor
psql -U postgres -h 127.0.0.1 -p 5432 -d postgres -v ON_ERROR_STOP=1 \
     -f db/hardening-connect.sql
```

### 3. Variables de entorno

Crear `.env.local` en la raíz. El archivo está cubierto por `.gitignore`
(`.env*`) y **nunca se versiona**:

```env
# Cadena de conexión del rol de privilegios mínimos.
# NO usar el superusuario postgres.
# Formato: postgresql://USUARIO:CONTRASENA@HOST:PUERTO/BASE
DATABASE_URL=
```

El nombre **no** lleva el prefijo `NEXT_PUBLIC_`, por lo que Next.js la
mantiene solo en el servidor y jamás la incrusta en el bundle del cliente.
`src/lib/db.ts` falla al arrancar si la variable no está definida, en lugar
de conectarse con una configuración silenciosamente incorrecta.

### 4. Levantar la aplicación

```bash
pnpm dev --webpack --port 3001
```

`--webpack` es obligatorio en el equipo de desarrollo: una política de Windows
bloquea el binario nativo de SWC, y sin esa opción el servidor de desarrollo no
arranca.

Disponible en `http://localhost:3001`. El puerto 3001 es el que usan todas
las evidencias de `db/EVIDENCIAS-FASE2.md`.

Otros comandos:

```bash
pnpm build             # compilación de producción
pnpm lint              # ESLint
pnpm exec tsc --noEmit # verificación de tipos
```

## Estructura

```
db/
  schema.sql              Tabla users con restricciones CHECK
  roles.sql               Rol citasegura_app de privilegios mínimos
  sessions.sql            Tabla sessions (tokens hasheados)
  appointments.sql        Tabla appointments con privilegios por columna
  hardening-connect.sql   Revoca CONNECT de PUBLIC en las demás bases
  EVIDENCIAS-FASE2.md     Evidencias de seguridad con salida real
  scripts-evidencias/     Scripts que generaron las evidencias y sus salidas

src/
  app/
    api/auth/
      register/route.ts   POST - alta de usuario
      login/route.ts      POST - inicio de sesión + bloqueo
      logout/route.ts     POST - revocación de sesión en servidor
      me/route.ts         GET  - usuario de la sesión actual
    api/citas/
      route.ts            POST - crear cita · GET - listar las propias
      [id]/cancelar/
        route.ts          POST - cancelar una cita propia
    registro/page.tsx     Formulario de registro
    login/page.tsx        Formulario de inicio de sesión
    inicio/page.tsx       Pantalla protegida (Server Component)
    layout.tsx, page.tsx
  components/
    auth/                 Maquetación de las pantallas de autenticación
    ui/                   Componentes shadcn/ui
  lib/
    db.ts                 Pool pg + query() parametrizada
    auth/
      password.ts         hashPassword / verifyPassword (bcrypt 12)
      session.ts          Creación, lectura y revocación de sesiones
      lockout.ts          Bloqueo por intentos fallidos
    validations/
      auth.ts             Esquemas Zod de registro e inicio de sesión
      citas.ts            Esquema Zod de citas (límite enlazado al CHECK)
```

## Controles de seguridad implementados

| Control | Implementación | OWASP Top 10 |
|---|---|---|
| Consultas parametrizadas | `query()` en `src/lib/db.ts` separa SQL de datos; sin concatenación y sin ORM | A03 Injection |
| Privilegios mínimos en BD | Rol `citasegura_app` con permisos acotados por columna; la app nunca usa `postgres`. Sin `DELETE` sobre `users` ni `appointments`: una cita cancelada se marca, no se borra | A01 Broken Access Control |
| Integridad de las citas en la BD | `CHECK` de estado, fecha y longitud del motivo; `id`, `status` y `created_at` los pone siempre la base | A04 Insecure Design |
| Aislamiento entre bases | `hardening-connect.sql` revoca `CONNECT` de `PUBLIC` en las demás bases del servidor | A01 / A05 Security Misconfiguration |
| Hashing de contraseñas | bcrypt con coste 12, asíncrono, con guarda de los 72 bytes útiles | A02 Cryptographic Failures |
| Política de contraseñas | Mínimo 12 caracteres y cuatro clases (minúscula, mayúscula, número, símbolo) | A07 Auth Failures |
| Validación en servidor | El mismo esquema Zod se reejecuta sobre el cuerpo de cada petición; la del cliente es solo comodidad | A03 / A04 Insecure Design |
| Anti *mass assignment* | `z.strictObject` rechaza el cuerpo completo si llega cualquier clave no declarada | A01 / A08 Integrity Failures |
| Sesiones opacas | Token de 256 bits (`crypto.randomBytes`) guardado **hasheado** con SHA-256; la BD no permite reconstruirlo | A02 / A07 |
| Cookie endurecida | `httpOnly`, `SameSite=lax`, `secure` en producción, caducidad de 8 h | A05 / A07 |
| Logout real | Revoca la sesión en el servidor, no solo borra la cookie | A07 |
| Bloqueo de cuenta | 5 fallos consecutivos bloquean 15 min; contador incrementado en una sentencia SQL atómica | A07 |
| Anti-enumeración | El registro responde igual ante correo duplicado; el login no distingue "usuario inexistente" de "contraseña incorrecta" | A01 / A07 |
| Secretos fuera de Git | `DATABASE_URL` solo en `.env.local`; `.gitignore` cubre `.env*`; la contraseña del rol se pasa como variable de `psql` | A05 |
| Aislamiento servidor/cliente | `src/lib/db.ts` lanza error si se importa desde el navegador, para no filtrar la cadena de conexión en el bundle | A02 / A05 |
| Control de acceso por objeto (anti-IDOR) | Las rutas de citas toman el dueño de la sesión y filtran por él **en SQL**; cancelar responde el mismo 404 a una cita inexistente, ajena o con id mal formado | A01 Broken Access Control |

El control de acceso por objeto está en el código desde CITA-12. Su evidencia
y el acotado del `INSERT` sobre `users` a las columnas que usa el registro
quedan para CITA-13 (Sprint 2).

## Estado

El seguimiento está en Jira (proyecto `CITA`). El estado detallado, con lo
hecho y lo pendiente por ticket, vive en `ESTADO-PROYECTO.md`.
