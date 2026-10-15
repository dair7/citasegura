@AGENTS.md

# CitaSegura — contexto del proyecto

TCC de **Seguridad de Software**, Universidad de Cartagena. Sistema de
agendamiento de citas seguro que responde al incidente de la **DIAN 2026**,
donde se expusieron datos personales a través del sistema de agendamiento de
un proveedor externo. **El mecanismo técnico no se publicó**: no afirmar en
código, comentarios ni documentos cómo falló la DIAN. Justificar cada control
por la clase de fallo que impide.

El criterio que manda: cada decisión técnica se justifica por un control de
seguridad, y ese control debe quedar **visible y auditable en el código**.
Por eso no hay ORM ni proveedor de autenticación externo.

## Stack

Next.js 16 (App Router) + TypeScript + Tailwind 4 + shadcn/ui.
API Routes propias (**no Supabase, no BaaS**). PostgreSQL 18 local con rol
de privilegios mínimos `citasegura_app`. Driver `pg` **sin ORM**. bcrypt
coste 12. Validación Zod compartida cliente/servidor. Sesiones propias
opacas con cookie `httpOnly` y token hasheado SHA-256.

- Gestor: **pnpm** (no npm, no yarn)
- Corre en **localhost:3001** → `pnpm dev --webpack --port 3001`
  - `--webpack` es obligatorio: una política de Windows bloquea el binario
    nativo de SWC, y sin esa opción el servidor de desarrollo no arranca.
- Secretos en `.env.local` (solo `DATABASE_URL`), cubierto por `.gitignore`

## Tablero

Jira, proyecto **`CITA`**. El proyecto viejo `SCRUM` ya no existe; no usar
códigos `SCRUM-N` en código, comentarios, documentos ni commits.

Equipo: **Dair**, **Lina**, **Javier**. Entrega final: **31 de octubre**.

### Cronograma

| Sprint | Tema | Fechas | Estado |
|---|---|---|---|
| 0 | Preparación | 28 – 29 sep | cerrado |
| 1 | Autenticación | 30 sep – 6 oct | cerrado, 34 pts |
| 2 | Citas y control de acceso | 7 – 13 oct | **EN CURSO**, 30 pts |
| 3 | Verificación y entrega | 14 – 20 oct | planificado, 16 pts |

### Sprint 1 — Autenticación, CERRADO (7/7 historias, 34 pts)

CITA-4 Setup Next.js · CITA-5 PostgreSQL + esquema de usuarios · CITA-6 UI
de registro y login · CITA-7 Endpoint de registro · CITA-8 bcrypt · CITA-9
Login y sesiones · CITA-10 Bloqueo por intentos fallidos.

Flujo completo funcionando: registro → login → `/inicio` (protegida) →
cerrar sesión.

### Sprint 2 — Citas y control de acceso (7 – 13 oct), EN CURSO

En **orden de ejecución por dependencias** (no por número):

| Orden | Ticket | Tarea | Responsable | Pts | Estado |
|---|---|---|---|---|---|
| 1 | CITA-18 | Esquema seguro de la tabla de citas | Dair | 5 | cerrada (`f2e485a`) |
| 2 | CITA-12 | API de citas parametrizada | Lina | 5 | implementada y subida (`194e4ac`); evidencia pendiente |
| 3 | CITA-13 | Control de acceso y anti-IDOR | Dair | 8 | pendiente |
| 4 | CITA-14 | Validación y sanitización en servidor | Javier | 5 | pendiente |
| 5 | CITA-11 | UI dashboard + agendar cita | Javier | 5 | pendiente |
| 6 | CITA-15 | Configuración segura de `.env` | Lina | 2 | pendiente |

El detalle de cada ticket, y lo que quedó a medias en CITA-18, está en
`ESTADO-PROYECTO.md`.

### Sprint 3 — Verificación y entrega (14 – 20 oct), planificado

| Ticket | Tarea | Responsable | Pts |
|---|---|---|---|
| CITA-19 | Vista de administrador (citas y usuarios) | Dair | 8 |
| CITA-16 | Pruebas de seguridad (re-test) | Javier | 5 |
| CITA-17 | Documentar matriz OWASP | Lina | 3 |

CITA-18 y CITA-19 se crearon en la retrospectiva del Sprint 1 porque eran
entregables que faltaban en el backlog; por eso su numeración es alta
aunque CITA-18 sea lo primero del Sprint 2.

## Alcance de las citas (decidido en la planificación)

Una cita tiene: **dueño, fecha y hora, motivo, estado y fecha de creación**.

El usuario puede **crear** una cita, **listar las suyas** y **cancelarla**.
**No puede modificarla.**

| Método | Ruta | Acción |
|---|---|---|
| `POST` | `/api/citas` | crear |
| `GET` | `/api/citas` | listar las propias |
| `POST` | `/api/citas/[id]/cancelar` | cancelar |

- **No hay `GET /api/citas/[id]`**: la lista ya da todo lo que la interfaz
  necesita, y cada endpoint de más es superficie de ataque de más.
- **Cancelar es una acción con nombre propio y sin cuerpo**, no un `PATCH`
  sobre el recurso: un `PATCH` recibiría un cuerpo diciendo qué modificar y
  reabriría el *mass assignment*. Con `POST .../cancelar` el endpoint solo sabe
  hacer una cosa. (No es por `SameSite`: `lax` protege igual a ambos métodos.)

El **administrador** (CITA-19, Sprint 3) puede consultar todas las citas y
la lista de usuarios registrados. **No** puede crear ni cancelar en nombre
de otros, ni modificar cuentas.

## Definición de terminado

Una historia está terminada cuando se cumplen las tres:

1. La funcionalidad se ejecuta en local y se comprobó su comportamiento
   **en la aplicación**, no solo en el código.
2. El código está confirmado y subido al repositorio.
3. La evidencia queda documentada **dentro del mismo sprint**.

## Convenciones de seguridad del código

Al escribir código en este proyecto, respetar lo que ya está establecido:

1. **SQL siempre parametrizado.** Usar `query()` de `src/lib/db.ts` con
   marcadores `$1, $2…`. Nunca interpolar valores en el texto SQL.
2. **La validación del servidor es la que manda.** Reejecutar el esquema
   Zod de `src/lib/validations/` (`auth.ts`, `citas.ts`) sobre el cuerpo de
   cada petición. La validación del cliente es solo comodidad para el usuario.
3. **`z.strictObject`, no `z.object`.** Rechaza claves no declaradas; es la
   defensa contra *mass assignment*.
4. **No filtrar existencia de cuentas.** Registro y login responden igual
   ante "existe" y "no existe" para evitar enumeración de usuarios.
5. **Nada de `postgres` como usuario de la app.** Solo `citasegura_app`.
   Un permiso nuevo se otorga acotado (por columna si hace falta) en el
   script de su tabla: los de `users` en `db/roles.sql`, los de `sessions` y
   `appointments` en su propio script. Nunca `ON ALL TABLES`.
6. **Los tokens de sesión se guardan hasheados** (SHA-256), nunca en claro.
7. **`src/lib/db.ts` es código de servidor.** No importarlo desde Client
   Components; tiene una guarda que lanza error si ocurre.
8. **Sin `NEXT_PUBLIC_` para secretos.** Ese prefijo los incrusta en el
   bundle del cliente.
9. **Scripts SQL idempotentes**, ejecutables varias veces sin pérdida de
   datos. Orden de montaje: `schema.sql` → `roles.sql` → `sessions.sql` →
   `appointments.sql` → `hardening-connect.sql`.
10. **Comentarios en español**, explicando *por qué* el control existe y
    qué ataque previene. Es material de evaluación académica, no solo
    código. El código y los identificadores van sin tildes.

## Archivos de referencia

- `ESTADO-PROYECTO.md` — estado por ticket, punto de retomada del trabajo
- `db/EVIDENCIAS-FASE2.md` — evidencias de seguridad con la salida real de
  cada comando (usan el puerto 3001)
- `README.md` — puesta en marcha y matriz de controles con referencia OWASP

## Notas de trabajo

- `AGENTS.md` lo regenera `next dev`; no borrar el bloque
  `BEGIN/END:nextjs-agent-rules`.
- No hacer commit sin que se pida explícitamente.
