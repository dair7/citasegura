# CitaSegura

Sistema de agendamiento de citas con seguridad desde el diseño. Trabajo de
Conclusión de Curso (TCC) de **Seguridad de Software**, Universidad de
Cartagena.

## Contexto

El proyecto parte de una clase de sistema, no de un caso concreto: una
aplicación de agendamiento de citas que maneja datos personales, desarrollada
por un proveedor externo, en la que fallos de control de acceso y de
validación exponen los datos de los ciudadanos.

Un agendador de citas no es una aplicación trivial: custodia nombres, correos
y horarios de personas identificables. Por eso cada decisión técnica de
CitaSegura se toma y se documenta desde el control de seguridad que la
justifica, no desde la comodidad de implementación, y cada control se
justifica por la clase de fallo que impide: una cita ajena accesible por su
id (IDOR), una ruta sin autenticación, una inyección, una entrada que no se
valida en el servidor o una cuenta que se puede enumerar.

El énfasis está en esas clases de fallo: autenticación robusta, control de
acceso por objeto, validación en el servidor, mínimo privilegio en la base de
datos y no exposición de datos sensibles.

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

- Node.js 20.9 o superior, el mínimo de Next.js 16. Para ejecutar
  `db/scripts-evidencias/evidencia-cita7-esquema.mts` hace falta 22.6 o
  superior, que ejecuta TypeScript sin compilarlo.
- pnpm
- PostgreSQL 18 corriendo en `localhost:5432`, con acceso de superusuario
  (`postgres`) para el montaje inicial

## Puesta en marcha

Si clonas en Windows, los scripts `.sh` ya llegan con finales LF y no hay que
hacer nada; el porqué está en «Finales de línea al clonar en Windows», al
final de este apartado.

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

Copiar `.env.example` a `.env.local` en la raíz y sustituir el marcador por
la contraseña que recibió `db/roles.sql`:

```bash
cp .env.example .env.local
```

`.env.example` sí se versiona: lleva los nombres de las variables y un
marcador en lugar de cada valor. `.env.local` está cubierto por `.gitignore`
(`.env*`, con la excepción `!.env.example`) y **nunca se versiona**.

La única variable es `DATABASE_URL`, la cadena de conexión de
`citasegura_app`. No lleva el prefijo `NEXT_PUBLIC_`, por lo que Next.js la
mantiene solo en el servidor y jamás la incrusta en el bundle del cliente.

`src/lib/env.ts` valida el entorno con Zod, y `src/instrumentation.ts` lo
ejecuta al arrancar el servidor, antes de atender ninguna petición. **La
aplicación se niega a arrancar** si `DATABASE_URL` falta, está vacía, no es
una URL `postgresql://`, usa el superusuario `postgres`, no lleva contraseña
o conserva el marcador de `.env.example`. El mensaje de error nombra la
variable y nunca su valor.

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

### Finales de línea al clonar en Windows

**Los scripts `.sh` tienen que quedar en LF.** Git para Windows trae
`core.autocrlf=true` en su configuración de sistema y convierte los archivos
de texto a CRLF al clonar. Es un fallo que **solo aparece al clonar en otra
máquina**: en el equipo donde se escribieron los scripts nunca se ve.

Que un script CRLF falle o no depende de **qué `bash` lo ejecuta**, y eso
depende de desde dónde se escriba el comando:

| Se escribe `bash` en… | Resuelve a | `script.sh` (por el shebang) | `bash script.sh` |
|---|---|---|---|
| Git Bash | el bash de Git para Windows | funciona | funciona |
| PowerShell o cmd | `C:\Windows\System32\bash.exe`, es decir **WSL** | `env: $'bash\r': No such file or directory` | `syntax error near unexpected token $'{\r'` |

Git Bash tolera el `\r`, y por eso el fallo pasa desapercibido. En WSL, la
invocación directa lee el shebang y busca un intérprete llamado `bash\r`.
`bash script.sh` se salta el shebang, pero falla igual en cuanto el `\r` del
cuerpo rompe una línea; en `evidencia-cita12.sh` ocurre en la línea 53. Con
un script de una sola línea puede parecer que funciona.

Fue lo que pasó el 14 de octubre: `bash -c "db/scripts-evidencias/evidencia-cita12.sh | tee ..."`,
escrito en PowerShell, se ejecutó en WSL e invocó el script directamente.
Además, **`| tee` oculta el fallo**: el código de salida de una tubería es el
de su último comando, así que el comando terminó con 0 aunque el script no
llegó a arrancar.

Desde el 14 de octubre, `.gitattributes` fuerza `eol=lf` para los `*.sh`, y
esa regla tiene prioridad sobre `core.autocrlf` de quien clone. En un clon
nuevo no hay que hacer nada. Para comprobarlo:

```bash
git ls-files --eol -- '*.sh'   # debe decir w/lf en todos
```

Ojo con `grep -c $'\r'` para contar retornos de carro: el `grep` de Git Bash
trata CRLF como fin de línea y devuelve 0 aunque el archivo esté en CRLF.

**Si tu clon es anterior a `.gitattributes`**, el `git pull` que lo trae no
reescribe los archivos que ya tenías. Si no tienes cambios en los scripts,
vuelve a escribirlos desde el repositorio:

```bash
git status --short -- db/scripts-evidencias/   # comprobar que no hay cambios propios
rm db/scripts-evidencias/*.sh
git checkout -- db/scripts-evidencias/
```

## Estructura

```
.env.example              Nombres de las variables de entorno, sin valores
ESTADO-PROYECTO.md        Estado por tarjeta y punto de retomada del trabajo
CLAUDE.md                 Contexto y convenciones de seguridad del proyecto

db/
  schema.sql              Tabla users con restricciones CHECK
  roles.sql               Rol citasegura_app de privilegios mínimos
  sessions.sql            Tabla sessions (tokens hasheados)
  appointments.sql        Tabla appointments con privilegios por columna
  hardening-connect.sql   Revoca CONNECT de PUBLIC en las demás bases
  EVIDENCIAS-FASE2.md     Evidencias de seguridad con salida real
  scripts-evidencias/     Scripts que generaron las evidencias y sus salidas

src/
  instrumentation.ts      Valida el entorno al arrancar el servidor
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
    inicio/
      page.tsx            Pantalla protegida (Server Component)
      panel-citas.tsx     Panel de citas: lista y pestañas
      formulario-cita.tsx Formulario de agendar cita
      item-cita.tsx       Una cita con su detalle y su cancelación
      boton-cerrar-sesion.tsx, estilos.ts, tipos.ts
    layout.tsx, page.tsx
  components/
    auth/                 Maquetación de las pantallas de autenticación
    identidad/            Logotipo, fondo y tarjeta compartidos
    ui/                   Componentes shadcn/ui
  lib/
    env.ts                Variables de entorno validadas con Zod
    arranque.ts           Termina el proceso si el entorno no es válido
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
| Salida escapada | El motivo de la cita se guarda literal y React lo escapa al pintarlo; no se usa `dangerouslySetInnerHTML` | A03 Injection (XSS) |
| Sesiones opacas | Token de 256 bits (`crypto.randomBytes`) guardado **hasheado** con SHA-256; la BD no permite reconstruirlo | A02 / A07 |
| Cookie endurecida | `httpOnly`, `SameSite=lax`, `secure` en producción, caducidad de 8 h | A05 / A07 |
| Logout real | Revoca la sesión en el servidor, no solo borra la cookie | A07 |
| Bloqueo de cuenta | 5 fallos consecutivos bloquean 15 min; contador incrementado en una sentencia SQL atómica | A07 |
| Anti-enumeración | El registro responde igual ante correo duplicado; el login no distingue "usuario inexistente" de "contraseña incorrecta" | A01 / A07 |
| Secretos fuera de Git | `DATABASE_URL` solo en `.env.local`; `.gitignore` cubre `.env*` y solo deja pasar `.env.example`, que no lleva valores; la contraseña del rol se pasa como variable de `psql` | A05 |
| Configuración validada al arrancar | `src/lib/env.ts` y `src/instrumentation.ts`: sin `DATABASE_URL` válida, o con el superusuario `postgres`, la aplicación no arranca; el error no muestra el valor | A05 |
| Aislamiento servidor/cliente | `src/lib/db.ts` lanza error si se importa desde el navegador, y `src/lib/env.ts` lleva `server-only`, para no filtrar la cadena de conexión en el bundle | A02 / A05 |
| Control de acceso por objeto (anti-IDOR) | Las rutas de citas toman el dueño de la sesión y filtran por él **en SQL**; cancelar responde el mismo 404 a una cita inexistente, ajena o con id mal formado | A01 Broken Access Control |

Las evidencias, con el comando ejecutado y su salida real, están en
`db/EVIDENCIAS-FASE2.md`.

## Estado

El seguimiento está en Jira (proyecto `CITA`). El estado detallado, con lo
hecho y lo pendiente por ticket, vive en `ESTADO-PROYECTO.md`.
