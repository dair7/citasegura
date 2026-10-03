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

# 4. Endurecimiento: aislar citasegura_app de las demás bases del servidor
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
pnpm dev --port 3001
```

Disponible en `http://localhost:3001`. El puerto 3001 es el que usan todas
las evidencias de `db/EVIDENCIAS-FASE2.md`.

Otros comandos:

```bash
pnpm build       # compilación de producción
pnpm lint        # ESLint
npx tsc --noEmit # verificación de tipos
```

## Estructura

```
db/
  schema.sql              Tabla users con restricciones CHECK
  roles.sql               Rol citasegura_app de privilegios mínimos
  sessions.sql            Tabla sessions (tokens hasheados)
  hardening-connect.sql   Revoca CONNECT de PUBLIC en las demás bases
  EVIDENCIAS-FASE2.md     Evidencias de seguridad con salida real

src/
  app/
    api/auth/
      register/route.ts   POST - alta de usuario
      login/route.ts      POST - inicio de sesión + bloqueo
      logout/route.ts     POST - revocación de sesión en servidor
      me/route.ts         GET  - usuario de la sesión actual
    registro/page.tsx     Formulario de registro
    layout.tsx, page.tsx
  components/ui/          Componentes shadcn/ui
  lib/
    db.ts                 Pool pg + query() parametrizada
    auth/
      password.ts         hashPassword / verifyPassword (bcrypt 12)
      session.ts          Creación, lectura y revocación de sesiones
      lockout.ts          Bloqueo por intentos fallidos
    validations/
      auth.ts             Esquemas Zod compartidos cliente/servidor
```

## Controles de seguridad implementados

| Control | Implementación | OWASP Top 10 |
|---|---|---|
| Consultas parametrizadas | `query()` en `src/lib/db.ts` separa SQL de datos; sin concatenación y sin ORM | A03 Injection |
| Privilegios mínimos en BD | Rol `citasegura_app` con permisos acotados por columna; la app nunca usa `postgres` | A01 Broken Access Control |
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

Control de acceso por objeto (anti-IDOR), pendiente para el Sprint 2
(CITA-13), sobre el esquema ya preparado en `db/schema.sql`.

## Estado

El seguimiento está en Jira (proyecto `CITA`). El estado detallado, con lo
hecho y lo pendiente por ticket, vive en `ESTADO-PROYECTO.md`.
