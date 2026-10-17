# Estado del proyecto — CitaSegura

> Punto de retomada. Última actualización: **2026-10-16**.
> **Sprint 1 cerrado** el 6 de octubre: 7 de 7 historias, 34 puntos.
> **Sprint 2 en curso** (7 – 13 oct, 30 puntos), con las seis tarjetas
> implementadas:
> - **CITA-18**, **CITA-13**, **CITA-14**, **CITA-11** y **CITA-15**: subidas.
> - **CITA-12**: código subido; su evidencia, el bloque 9 de
>   `EVIDENCIAS-FASE2.md`, se redactó el 16 de octubre y está **pendiente de
>   commit**. Es de Lina.
>
> Entrega final: **31 de octubre**.

## Qué es el proyecto

**CitaSegura** — aplicación web segura de agendamiento de citas, desarrollada como
TCC de **Seguridad de Software**. El objetivo no es la aplicación en sí, sino
demostrar y poder defender oralmente cada control de seguridad.

### De qué problema parte

De una **clase de sistema**, no de un caso concreto: una aplicación de
agendamiento de citas que maneja datos personales, desarrollada por un
**proveedor externo**, en la que fallos de **control de acceso** y de
**validación** exponen los datos de los ciudadanos.

Cada control se justifica por la **clase de fallo** que impide: una cita
ajena accesible por su id (IDOR), una ruta sin autenticación, una inyección,
una entrada que no se valida en el servidor, una cuenta que se puede
enumerar. Son las clases que llevan a que un sistema de agendamiento exponga
los datos de una persona a otra, y no hace falta el nombre de ninguna
institución para defenderlas.

En el repositorio no se nombra a ninguna institución real, ni directamente
ni con perífrasis: ni en documentos, ni en comentarios del código, ni en los
guiones, ni en los mensajes de commit nuevos.

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
| **CITA-12** | Implementada, verificada en la aplicación con `curl` y subida el 13 oct (`194e4ac`). Evidencia documentada el 16 oct en el **bloque 9** (9.1 a 9.8), redactada desde `salida-cita12.txt` (14 oct) sin volver a ejecutar el guion, tras comprobar que desde la captura el código de la API solo cambió en comentarios. **Pendiente de commit** | `POST /api/citas`, `GET /api/citas` y `POST /api/citas/[id]/cancelar`. Sesión exigida antes que nada (401), dueño tomado siempre de la sesión, listado filtrado por dueño en SQL, esquema Zod `crearCitaSchema` compartido, y el mismo 404 para una cita inexistente, ajena o con id mal formado. |
| **CITA-13** | Verificada, documentada (bloque 6) y subida el 14 oct (`e067144`) | Los cuatro criterios se cumplían desde CITA-12; se verificaron con `evidencia-cita13.sh`. Encontró y cerró un hallazgo: `citasegura_app` podía escribir la columna `role` de `users`. |
| **CITA-14** | Verificada, documentada (bloque 7) y subida el 15 oct (`90e13d1`). El criterio del escape al mostrarse quedó **cerrado** el 16 oct con el cierre de la evidencia 7.4 | Validación en el servidor sin depender del navegador, claves sobrantes con respuesta idéntica, fecha pasada frenada en dos capas, texto guardado literal y escapado al mostrarse. |
| **CITA-11** | Implementada, probada en el navegador y subida el 16 oct (`dcff07b`). Su parte de seguridad, pintar el motivo sin ejecutarlo, está en el cierre de la evidencia 7.4 | Panel de `/inicio`: lista, agendar, detalle desplegable sin petición y cancelar con confirmación. Ver la nota 5 de «Qué SIGUE». |
| **CITA-15** | Implementada, verificada, documentada (bloque 8) y subida el 16 oct (`8fd51b5`) | `.env.example` versionable, validación del entorno con Zod al arrancar, y la aplicación se niega a arrancar si falta una variable o la configuración es peligrosa. Ver la nota 6 de «Qué SIGUE». |

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

Las descripciones están escritas para esta lista: **no son los asuntos de
los commits tal cual**, así que no coinciden con `git log`. Lo que identifica
cada commit es el hash.

| Commit | Tarjeta | Qué contiene |
|---|---|---|
| `8fd51b5` | CITA-15 | Configuración segura del entorno, y puesta al día de la documentación |
| `dcff07b` | CITA-11 | Panel de citas en `/inicio` |
| `90e13d1` | CITA-14 | Validación y sanitización en el servidor; corrección de los tiempos de CITA-13 |
| `e067144` | CITA-13 | Verificación del control de acceso, cierre del hallazgo del `INSERT` sobre `users` y corrección de cómo se describía el problema de partida |
| `c5c63ff` | CITA-13 | `INSERT` sobre `users` acotado a tres columnas en `db/roles.sql`, y la captura del hallazgo antes del cambio (`salida-cita13-antes.txt`) |
| `f82919f` | CITA-12 | `.gitattributes` con finales LF para los `.sh`, y la salida del guion de CITA-12 con su documentación |
| `4080bea` | CITA-12 | Estado del proyecto puesto al día tras la API de citas |
| `194e4ac` | CITA-12 | API de citas con validación y filtrado por dueño |
| `f2e485a` | CITA-18 | Evidencia del esquema seguro de citas (bloque 5) |
| `6d383d1` | CITA-6 | Pantallas de login e inicio, y rediseño del registro |
| `2f32cce` | CITA-7 a CITA-10 | Guiones de evidencia del Sprint 1 |
| `08a635b` | — | Cambio de los códigos del tablero anterior a CITA, y documentación del proyecto |
| `f8d80dc` | — | `ESTADO-PROYECTO.md` como punto de retomada |
| `dd62cd7` | CITA-5, CITA-7 a CITA-10 | Evidencias del Sprint 1 (bloques 1 a 4) |
| `e5dcc6a` | CITA-10 | Bloqueo de cuenta tras 5 intentos fallidos |
| `2cb0863` | CITA-9 | Inicio de sesión con sesiones propias y cookie `httpOnly` |
| `693be08` | CITA-5, CITA-7, CITA-8 | Base de datos endurecida y registro de usuario seguro |
| `d6cee02` | CITA-4 | Proyecto inicial generado con create-next-app |

*Nota: los commits anteriores a `08a635b` llevan en el asunto el código del
tablero anterior. La tarjeta de esta tabla es su equivalente en el tablero
actual, asignada por el contenido de cada commit.*

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
| 2 | **CITA-12** | API de citas parametrizada | Lina | 5 | implementada y subida; evidencia documentada (bloque 9), pendiente de commit |
| 3 | **CITA-13** | Control de acceso y anti-IDOR | Dair | 8 | verificada, documentada y subida (`e067144`) |
| 4 | **CITA-14** | Validación y sanitización en servidor | Javier | 5 | verificada, documentada y subida (`90e13d1`); 7.4 cerrada el 16 oct |
| 5 | **CITA-11** | UI dashboard + agendar cita | Javier | 5 | implementada y subida (`dcff07b`) |
| 6 | **CITA-15** | Configuración segura de `.env` | Lina | 2 | verificada, documentada y subida (`8fd51b5`) |

Notas para lo que queda:

3. **CITA-13** — **Control de acceso por objeto (anti-IDOR).** Es el control
   estrella del trabajo: el IDOR es la clase de fallo por la que un sistema de
   agendamiento acaba exponiendo datos personales ajenos, que es el problema
   del que parte el proyecto (ver «De qué problema parte», arriba). El filtro
   por dueño ya está en el código de CITA-12: las tres consultas usan el usuario
   de la sesión (`WHERE ... user_id = $2`), y cancelar responde el mismo 404 a
   una cita inexistente, ajena o con id mal formado. Al planificar CITA-12 se
   dejaron fuera, para CITA-13 y CITA-14, los cambios de permisos de la base y
   los scripts de evidencia. No hay `proxy.ts`: cada ruta comprueba la sesión
   por su cuenta.
   **Hecho el 14 de octubre y subido en `e067144`.** Los cuatro criterios de la
   tarjeta se cumplían desde CITA-12; CITA-13 los verificó con
   `evidencia-cita13.sh` (bloque 6 de `EVIDENCIAS-FASE2.md`), que no repite lo
   que ya probó CITA-12:
   - Ninguna ruta devuelve una cita por id: `GET`, `PATCH` y `DELETE
     /api/citas/<id>` dan la misma página 404 para una cita ajena y para una
     inexistente.
   - Cancelar la cita ajena deja su fila intacta, comprobado en la base con el
     `md5` de la fila completa.
   - Ajena e inexistente no se distinguen por tiempo: los dos casos recorren la
     misma consulta y el mismo camino de código. Los tres intentos del script
     se solapan y el orden se invierte entre ellos. Eso no demuestra que no
     haya canal por tiempo, solo que queda por debajo de la variación normal.
   - Los identificadores son UUID v4.

   **Hallazgo corregido:** `citasegura_app` tenía `INSERT` de tabla completa
   sobre `users` y podía crear una cuenta `admin` por SQL. Se capturó la salida
   real **antes** de corregirlo (`salida-cita13-antes.txt`). Ahora, en
   `roles.sql` apartado 3.c, el permiso es `INSERT (name, email, password_hash)`,
   y el mismo ataque da `permiso denegado`. Se cerró también la causa: los
   privilegios por defecto de las tablas futuras pasaron de `SELECT, INSERT` a
   solo `SELECT`. El comentario de `register/route.ts` ahora nombra el permiso
   por columna como la garantía real. Con la regresión (registro, login,
   bloqueo y `evidencia-cita12.sh` completo) todo sigue funcionando.

   **Revisión de sesiones:** hoy no falta la comprobación en ninguna ruta ni
   página protegida, pero la protección es por ruta y no hay denegación por
   defecto. Queda como limitación 7 de `EVIDENCIAS-FASE2.md`, con la propuesta
   de un `proxy.ts` que deniegue por defecto.
4. **CITA-14** — El esquema `crearCitaSchema` (`z.strictObject`, reejecutado en
   el servidor) ya existe en `src/lib/validations/citas.ts` desde CITA-12.
   **Decidido el 15 de octubre:** cuando llega una clave no declarada, la
   respuesta trae `"errors":{}` (Zod la pone en `formErrors`, no en
   `fieldErrors`; el registro se comporta igual), y se deja así como
   comportamiento buscado. `z.strictObject` rechaza cualquier clave sobrante,
   exista o no como columna, así que la respuesta es idéntica para `role`,
   `status` o `xyz`: no sirve para sondear qué campos reconoce el sistema, no
   devuelve nada de lo que envió el atacante, y el formulario legítimo nunca
   manda claves de más. (El argumento de que nombrar la clave «confirmaría
   que la columna existe» se descartó: no se sostiene.)
   **Pendiente (Dair, en Notion):** corregir la página 2.4 de Notion, donde
   está escrita la versión descartada del argumento.
   **Hecho el 15 de octubre y subido en `90e13d1`.** `evidencia-cita14.sh`
   (bloque 7 de `EVIDENCIAS-FASE2.md`, salida en `salida-cita14.txt`) no
   repite lo que ya probó CITA-12 y verifica:
   - Por `curl`, sin formulario: falta un campo y tipo equivocado dan 400; las
     claves `status`, `role` y `xyz` dan respuestas idénticas byte a byte, sin
     eco de la clave ni de su valor; ningún rechazo deja fila.
   - Fecha de ayer en dos capas: el esquema la frena en la API, y por SQL
     directo como `citasegura_app` la frena el `CHECK`
     `appointments_agendada_despues_de_crearse`.
   - Los motivos `<script>…` e `<img onerror…>` se guardan literales y van
     crudos en el JSON (lo correcto); en `src/` no hay
     `dangerouslySetInnerHTML`. Un nombre de usuario con `<script>` sale
     escapado en el HTML de `/inicio`.
   - **Criterio 4, cerrado el 16 de octubre.** Al escribir el bloque el
     motivo no se pintaba en ninguna pantalla, porque CITA-11 no existía, y la
     7.4 quedó con un «Cierre pendiente». Con el panel en marcha se agendó una
     cita con el motivo `<script>alert(1)</script>`: aparece como texto en la
     lista y en el detalle, sin ejecutarse. La 7.4 lleva ahora el mismo texto
     de cierre que la página 2.4 de Notion, donde está la captura.
   - Observación nueva: las respuestas no llevan cabeceras de seguridad
     (`nosniff`, CSP) y sí `X-Powered-By`. Limitación 8.
5. **CITA-11** — **Hecha y subida el 16 de octubre (`dcff07b`).** El panel
   sustituye el contenido provisional de `/inicio`, que sigue siendo un Server
   Component que comprueba la sesión antes de generar HTML (criterio 4). El
   resto vive en el cliente (`src/app/inicio/`):
   - La lista sale siempre de `GET /api/citas`, que filtra por dueño en SQL;
     el panel no tiene una vía propia hacia la base.
   - **El detalle se despliega con los datos que ya trae la lista**, sin
     pedir nada: crear `GET /api/citas/[id]` habría reabierto la superficie
     que CITA-12 cerró y habría hecho falsa la evidencia 6.1.
   - **«Mis citas» y «Agendar» son pestañas en el cliente, no rutas**: sin
     denegación por defecto (limitación 7), cada ruta nueva es un sitio más
     donde olvidarse de comprobar la sesión.
   - El formulario valida con `crearCitaSchema`, el mismo esquema del
     servidor, y envía `scheduledAt` con la zona horaria del navegador.
     Enter en la fecha o la hora pasa al campo siguiente en vez de enviar el
     formulario a medias.
   - Cancelar pide confirmación y no se ofrece en las citas ya canceladas
     (el servidor respondería 409).
   - Se extrajeron a `src/components/identidad/` el logotipo, la marca de
     agua, el fondo oscuro y la tarjeta de cristal; `/login` y `/registro`
     sirven el mismo HTML que antes. El panel no lleva marca de agua: allí
     hay un panel dedicado a la marca, y el de citas está lleno de contenido.
6. **CITA-15** — **Hecha y subida el 16 de octubre (`8fd51b5`).** Evidencia
   en el bloque 8 de `EVIDENCIAS-FASE2.md` (`evidencia-cita15.sh`, salida en
   `salida-cita15.txt`).
   - `.gitignore`: `!.env.example` después de `.env*`, que también ignoraba
     el ejemplo. Ningún archivo de entorno estuvo nunca en el historial, y la
     contraseña actual aparece 0 veces en él: no hubo que rotar nada.
   - `.env.example`: solo `DATABASE_URL`, con el marcador
     `CAMBIAR_POR_LA_CONTRASENA`.
   - `src/lib/env.ts`: valida el entorno con Zod al importarse, con
     `import "server-only"`. Además de que falte la variable, rechaza el
     usuario `postgres` (la aplicación no puede arrancar como superusuario y
     saltarse los privilegios de CITA-5, 18 y 13), la cadena sin contraseña y
     el marcador del ejemplo. El mensaje nombra la variable y nunca su valor.
     `db.ts` lee de ahí.
   - `src/instrumentation.ts` y `src/lib/arranque.ts`: la validación corre al
     arrancar, no con la primera petición que toca la base.
   - **Hallazgo (evidencia 8.5):** si `register()` solo lanza el error,
     Next.js registra «Failed to prepare server» pero el proceso sigue vivo,
     escuchando y respondiendo HTTP 500 a todo, lo que un vigilante de
     procesos o de puertos daría por sano. Por eso termina con
     `process.exit(1)`. Comprobado con `next start` el 16 de octubre.
   - Tras el commit, comprobar aparte con `git ls-files .env.example` que el
     ejemplo quedó versionado (la captura lo muestra listo para entrar, con
     `git add --dry-run`). No volver a ejecutar el guion entero por eso.
   - El guion exige el servidor de desarrollo **parado**: modifica
     `.env.local` (sobre copia, y lo restaura comprobando el hash) y
     `next dev` recargaría cada versión intermedia.

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
| `db/roles.sql` | Crea el rol `citasegura_app` sin `SUPERUSER`/`CREATEDB`/`CREATEROLE`. Sobre `users` le da **`SELECT`**, **`INSERT` solo en `name`, `email` y `password_hash`** (CITA-13: así no puede escribir `role`) y **`UPDATE` solo en `failed_attempts` y `locked_until`**; el `DELETE` se retiró con un `REVOKE` explícito en CITA-18. Reinicia los privilegios por defecto de tablas futuras a **solo `SELECT`** (CITA-13) y nombra cada tabla, nunca `ON ALL TABLES`. Recibe la contraseña como variable de psql, nunca escrita en el archivo. |
| `db/sessions.sql` | Tabla `sessions`: el id es el **SHA-256 del token** (`CHECK` de 64 hexadecimales), FK a `users` con `ON DELETE CASCADE`, y `REVOKE UPDATE` para que una sesión sea inmutable. |
| `db/appointments.sql` | Tabla `appointments` (CITA-18): `CHECK` de estado, fecha y motivo, FK al dueño, y privilegios **por columna**: `INSERT (user_id, scheduled_at, reason)` y `UPDATE (status)`, sin `DELETE`. Fija sus permisos con `REVOKE ALL` y `GRANT` explícitos, sin depender de los privilegios por defecto. |
| `db/hardening-connect.sql` | `REVOKE CONNECT` de `PUBLIC` en **todas** las demás bases del servidor, leídas de `pg_database` al ejecutar (no nombradas a mano), para que una credencial filtrada de CitaSegura no alcance otros proyectos. |
| `db/EVIDENCIAS-FASE2.md` | Anexo del informe: evidencias con comando y salida real. Bloques 1 a 4 del Sprint 1 (el 2 recoge CITA-7 y CITA-8), 5 de CITA-18, 6 de CITA-13, 7 de CITA-14, 8 de CITA-15 y 9 de CITA-12. Un apartado junto al índice explica qué tarjetas no tienen bloque propio y por qué. Cierra con la tabla de controles contra OWASP y las limitaciones conocidas. |
| `db/scripts-evidencias/` | Los guiones que generaron las evidencias y sus salidas guardadas. Su `README.md` tiene la tabla de cada guion con su tarjeta y lo que demuestra, cómo se ejecutan y qué hace falta tener levantado, el significado de los dos nombres con sufijo (`salida-cita13-antes.txt`, `salida-cita18-ddp.txt`) y por qué hoy no se pueden ejecutar tal cual los guiones de CITA-8, 9 y 10. |
| `db/scripts-evidencias/evidencia-cita7-esquema.mts` | Era `probe-auth.mts`, en la raíz: la prueba del esquema `registerSchema` con 13 casos, sin servidor. Movido el 16 de octubre porque cubre reglas que ningún otro guion prueba por separado (cada requisito de la contraseña, el tope de 72 bytes). Se ejecuta con **`node`, no con `bash`**; salida en `salida-cita7-esquema.txt`. Sigue **excluido del type-check** en `tsconfig.json`. |

### Lógica de seguridad (`src/lib/`)

| Archivo | Qué hace |
|---|---|
| `src/lib/db.ts` | Único punto de acceso a PostgreSQL: pool singleton y `query()` **parametrizada**. Falla si se importa desde el navegador. Toma la cadena de conexión de `env.ts`. |
| `src/lib/env.ts` | (CITA-15) Único módulo que lee la configuración de `process.env`. La valida con Zod al importarse: `DATABASE_URL` presente, `postgresql://`, con contraseña, sin el marcador de `.env.example` y **sin el usuario `postgres`**. El mensaje de error nombra la variable, nunca su valor. `import "server-only"`: el build falla si lo importa un Client Component. |
| `src/lib/arranque.ts` y `src/instrumentation.ts` | (CITA-15) `register()` valida el entorno al arrancar el servidor y, si falla, termina el proceso con código 1 (evidencia 8.5: sin eso, el proceso seguía vivo respondiendo 500). |
| `.env.example` | (CITA-15) Nombres de las variables con un marcador en lugar del valor. Versionable gracias a `!.env.example` en `.gitignore`. |
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
| `/inicio` | **Server Component protegido**: resuelve la sesión con `getSession()` antes de renderizar y redirige a `/login` si no la hay. Desde CITA-11 contiene el panel de citas (pestañas «Mis citas» y «Agendar», en el cliente), que pide sus datos a la API de citas. |

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
7. **Sin denegación por defecto** — cada ruta protegida llama a `getSession()`
   por su cuenta. Una ruta nueva que lo olvide queda abierta sin aviso. Una
   ruta que nadie protegió es otra vía hacia el mismo resultado: datos de una
   persona accesibles para otra. La solución es un `src/proxy.ts` que
   rechace toda petición sin cookie de sesión salvo una lista de rutas
   públicas, manteniendo `getSession()` en cada ruta. Detalle en la limitación
   7 de `db/EVIDENCIAS-FASE2.md`.
8. **Sin cabeceras de seguridad HTTP** — ni `X-Content-Type-Options:
   nosniff`, ni `Content-Security-Policy`, ni `X-Frame-Options`, y sí
   `X-Powered-By: Next.js` (comprobado el 15 de octubre). Se declararían en
   `next.config.ts`. Detalle en la limitación 8 de `db/EVIDENCIAS-FASE2.md`.

Los puntos 2 a 8 quedan documentados como trabajo futuro.

## Cómo arrancar

```bash
pnpm dev --webpack --port 3001   # --webpack: SWC nativo bloqueado por política de Windows
pnpm build                       # compila y pasa el type-check
pnpm lint
```

Desde CITA-15, la aplicación **no arranca** si `.env.local` no tiene
`DATABASE_URL`, si conserva el marcador de `.env.example` o si conecta como
`postgres`. El mensaje dice qué variable falla y por qué, sin mostrar su
valor. `.env.example` tiene los nombres que hacen falta.

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
