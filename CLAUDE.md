@AGENTS.md

# CitaSegura — contexto del proyecto

TCC de **Seguridad de Software**, Universidad de Cartagena. Sistema de
agendamiento de citas seguro que responde al incidente de la **DIAN 2026**,
donde se filtraron datos personales desde su sistema de agendamiento.

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
- Corre en **localhost:3001** → `pnpm dev --port 3001`
- Secretos en `.env.local` (solo `DATABASE_URL`), cubierto por `.gitignore`

## Tablero

Jira, proyecto **`CITA`**. El proyecto viejo `SCRUM` ya no existe; no usar
códigos `SCRUM-N` en código, comentarios, documentos ni commits.

### Sprint 1 — Autenticación (30 sep – 6 oct), ACTIVO

| Ticket | Tarea |
|---|---|
| CITA-4 | Setup Next.js y estructura base |
| CITA-5 | PostgreSQL + esquema seguro de usuarios |
| CITA-6 | UI de registro y login |
| CITA-7 | Endpoints de registro en API |
| CITA-8 | Hashing de contraseñas con bcrypt |
| CITA-9 | Lógica de login y sesiones |
| CITA-10 | Bloqueo por intentos fallidos |

### Sprint 2 — Citas y control de acceso (7 – 13 oct)

CITA-11 UI dashboard + agendar cita · CITA-12 API de citas parametrizada ·
CITA-13 Control de acceso y anti-IDOR · CITA-14 Validación y sanitización
en servidor · CITA-15 Configuración segura de `.env`

### Sprint 3 — Verificación y entrega (14 – 20 oct)

CITA-16 Pruebas de seguridad (re-test) · CITA-17 Documentar matriz OWASP

## Convenciones de seguridad del código

Al escribir código en este proyecto, respetar lo que ya está establecido:

1. **SQL siempre parametrizado.** Usar `query()` de `src/lib/db.ts` con
   marcadores `$1, $2…`. Nunca interpolar valores en el texto SQL.
2. **La validación del servidor es la que manda.** Reejecutar el esquema
   Zod de `src/lib/validations/auth.ts` sobre el cuerpo de cada petición.
   La validación del cliente es solo comodidad para el usuario.
3. **`z.strictObject`, no `z.object`.** Rechaza claves no declaradas; es la
   defensa contra *mass assignment*.
4. **No filtrar existencia de cuentas.** Registro y login responden igual
   ante "existe" y "no existe" para evitar enumeración de usuarios.
5. **Nada de `postgres` como usuario de la app.** Solo `citasegura_app`.
   Un permiso nuevo se otorga acotado por columna en `db/roles.sql`.
6. **Los tokens de sesión se guardan hasheados** (SHA-256), nunca en claro.
7. **`src/lib/db.ts` es código de servidor.** No importarlo desde Client
   Components; tiene una guarda que lanza error si ocurre.
8. **Sin `NEXT_PUBLIC_` para secretos.** Ese prefijo los incrusta en el
   bundle del cliente.
9. **Scripts SQL idempotentes**, ejecutables varias veces sin pérdida de
   datos. Orden de montaje: `schema.sql` → `roles.sql` → `sessions.sql` →
   `hardening-connect.sql`.
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
