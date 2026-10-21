# CitaSegura — Evidencias de la Fase 2

Recopilación de evidencias de los controles de seguridad implementados en la
fase 2 del proyecto: base de datos endurecida, registro seguro, inicio de
sesión con sesiones propias, bloqueo de cuenta por intentos fallidos, el
esquema seguro de la tabla de citas, la verificación del control de acceso
anti-IDOR, la validación y sanitización en el servidor, la configuración
segura del entorno, la vista de administrador y las cabeceras de seguridad
HTTP.

| | |
|---|---|
| **Última actualización** | 2026-10-20 |
| **Motor** | PostgreSQL 18, localhost:5432, autenticación scram-sha-256, en dos equipos (ver la tabla siguiente) |
| **Aplicación** | Next.js 16.3.6 (App Router), Node.js runtime |
| **Rol de la aplicación** | `citasegura_app` (sin SUPERUSER) |

Todas las salidas de este documento provienen de una ejecución real; ninguna
está transcrita a mano. Los bloques 1 a 4 se generaron el 25 de septiembre de
2026, y cada bloque posterior lleva en su cabecera la fecha y el guion que lo
generaron.

El proyecto cambió de equipo el 14 de octubre, porque el anterior se dañó, y
la base se montó desde cero en el nuevo con una versión más reciente de
PostgreSQL. Cada bloque se generó en uno de los dos:

| Bloques | Equipo | PostgreSQL |
|---|---|---|
| 1 a 4 (25 de septiembre) | Anterior | **18.1**, registrada en la salida de la evidencia 1.1 |
| 5 (8 de octubre; la 5.3 se completó el 13) | Anterior | No consta: ninguna salida del bloque registra la versión |
| 6 a 9 (14 a 16 de octubre; la salida del bloque 9 es del 14) | Nuevo | **18.6**; la limitación 6 lo registra el 14 de octubre |
| 10 (19 de octubre) | Nuevo | **18.6**: no está en la salida del guion; se comprobó aparte el mismo día (cabecera del bloque 10) |
| 11 (20 de octubre) | Nuevo | No consta: las salidas no la registran, y el bloque solo usa la base para crear y borrar sus cuentas |

Las consultas de la
aplicación se ejecutan **como `citasegura_app`**, nunca como superusuario:
un superusuario se salta las comprobaciones de privilegios y haría que las
pruebas de permisos no demostraran nada.

Las cuentas `evidencia.*@ejemplo.com` que aparecen en los bloques 2 a 4 se
crearon únicamente para generar estas evidencias y se eliminaron al terminar
(ver el apartado de limpieza). Al terminar aquella generación, el 25 de
septiembre, la única cuenta que sobrevivía era `test@gmail.com`,
preexistente, que no se modificó en ningún momento.

**Cuentas en la base a 13 de octubre de 2026**, después de la limpieza de
CITA-18 y CITA-12:

| Cuenta | Origen |
|---|---|
| `test@gmail.com` | Cuenta de pruebas principal, preexistente. |
| `test@ejemplo.com` | Creada el 6 de octubre. **Su origen no está documentado**: ese correo no aparece en ninguno de los scripts de evidencia y nadie del equipo sabe explicarla. |

## Índice

- **Bloque 1 — CITA-5: base de datos y privilegios mínimos**
  - Evidencia 1.1 — Esquema de la tabla `users`
  - Evidencia 1.2 — Esquema de la tabla `sessions`
  - Evidencia 1.3 — El rol de la aplicación no es superusuario y tiene privilegios mínimos
  - Evidencia 1.4 — Ataques ejecutados con las credenciales reales de la aplicación: todos denegados
  - Evidencia 1.5 — Aislamiento entre bases de datos
- **Bloque 2 — CITA-7 y CITA-8: registro de usuario seguro y contraseñas con bcrypt**
  - Evidencia 2.1 — Registro válido y normalización de los datos
  - Evidencia 2.2 — La contraseña se guarda como hash bcrypt, nunca en texto
  - Evidencia 2.3 — La base de datos rechaza una contraseña en texto plano
  - Evidencia 2.4 — Peticiones maliciosas o inválidas rechazadas por el servidor
  - Evidencia 2.5 — Los intentos rechazados no dejaron rastro en la base de datos
  - Evidencia 2.6 — Anti-enumeración de usuarios: el correo duplicado responde igual que un registro nuevo
- **Bloque 3 — CITA-9: inicio de sesión con sesiones propias**
  - Evidencia 3.1 — Login correcto y flags de la cookie de sesión
  - Evidencia 3.2 — En la tabla `sessions` el token está hasheado, no en texto
  - Evidencia 3.3 — Ruta protegida: solo se entra con una cookie de sesión válida
  - Evidencia 3.4 — El cierre de sesión revoca en el servidor, no solo en el navegador
  - Evidencia 3.5 — Anti-enumeración por tiempo en el login
- **Bloque 4 — CITA-10: bloqueo de cuenta por intentos fallidos**
  - Evidencia 4.1 — El contador sube con cada fallo y al quinto se activa el bloqueo
  - Evidencia 4.2 — Con la cuenta bloqueada, incluso la contraseña CORRECTA es rechazada
  - Evidencia 4.3 — Insistir durante el bloqueo no lo alarga (sin amplificación)
  - Evidencia 4.4 — Vencido el bloqueo se puede entrar, y el login correcto reinicia el contador
  - Evidencia 4.5 — El bloqueo no introduce una diferencia de tiempo que delate si la cuenta existe
  - Evidencia 4.6 — Estado final de la base de datos
- **Limpieza de las cuentas de evidencia**
- **Bloque 5 — CITA-18: esquema seguro de la tabla de citas**
  - Evidencia 5.1 — Esquema de la tabla `appointments`: restricciones `CHECK` e índices
  - Evidencia 5.2 — Privilegios de la aplicación acotados por columna
  - Evidencia 5.3 — Corrección de los privilegios por defecto del esquema
  - Evidencia 5.4 — Doce operaciones rechazadas por la base, aunque el código las intente
  - Evidencia 5.5 — Las tres operaciones que la aplicación sí puede hacer
- **Bloque 6 — CITA-13: control de acceso y anti-IDOR**
  - Evidencia 6.1 — Ningún endpoint devuelve una cita por su identificador
  - Evidencia 6.2 — Cancelar una cita ajena no produce ningún cambio, comprobado en la base
  - Evidencia 6.3 — Cita ajena e inexistente tardan lo mismo
  - Evidencia 6.4 — Los identificadores de cita no son secuenciales
  - Evidencia 6.5 — La comprobación de propiedad ocurre en la consulta a la base
  - Evidencia 6.6 — Hallazgo: la aplicación podía crear una cuenta de administrador
  - Evidencia 6.7 — Corrección: `INSERT` acotado por columna, y privilegios por defecto reducidos
  - Evidencia 6.8 — El registro y el resto de la aplicación siguen funcionando
- **Bloque 7 — CITA-14: validación y sanitización en el servidor**
  - Evidencia 7.1 — La validación no depende del navegador
  - Evidencia 7.2 — Fecha en el pasado: dos barreras independientes
  - Evidencia 7.3 — El texto se guarda literal y viaja crudo en el JSON
  - Evidencia 7.4 — El texto se escapa al mostrarse, en el renderizado del servidor
- **Bloque 8 — CITA-15: configuración segura del entorno**
  - Evidencia 8.1 — Los archivos de entorno están fuera de git, también en el historial
  - Evidencia 8.2 — `.env.example` declara exactamente lo que la aplicación lee
  - Evidencia 8.3 — Ningún secreto llega al navegador
  - Evidencia 8.4 — Sin una variable obligatoria, la aplicación no arranca
  - Evidencia 8.5 — Hallazgo: un error al arrancar dejaba el proceso vivo
- **Bloque 9 — CITA-12: API de citas parametrizada**
  - Evidencia 9.1 — Sin sesión no hay nada: 401 en las tres rutas
  - Evidencia 9.2 — Crear citas válidas
  - Evidencia 9.3 — Claves no declaradas: se rechaza el cuerpo entero
  - Evidencia 9.4 — Fecha, motivo y formato del cuerpo, validados en el servidor
  - Evidencia 9.5 — Los rechazos no dejaron ninguna fila
  - Evidencia 9.6 — Inyección SQL en el motivo: se guarda como texto
  - Evidencia 9.7 — El listado devuelve solo las citas propias
  - Evidencia 9.8 — Cancelar: la cita ajena, la inexistente y el id mal formado reciben el mismo 404
- **Bloque 10 — CITA-19: vista de administrador**
  - Evidencia 10.1 — El rol solo se asigna en la base, por cualquiera de sus dos caminos
  - Evidencia 10.2 — El administrador ve las dos listas
  - Evidencia 10.3 — Ni el hash ni los campos de bloqueo salen de la base
  - Evidencia 10.4 — El administrador solo consulta
  - Evidencia 10.5 — Sin rol, un 404 y ningún dato de la vista
  - Evidencia 10.6 — Hallazgo: el código coincide; el cuerpo y las cabeceras, no
  - Evidencia 10.7 — La reescritura en el Proxy: cuerpo idéntico, y una cabecera que Next.js pone siempre
  - Evidencia 10.8 — Con cookie y sin ella: el mismo contenido en otro orden, y por qué no es un oráculo nuevo
  - Evidencia 10.9 — El rol se lee de la base en cada petición: una cuenta degradada pierde el acceso al instante
- **Bloque 11 — CITA-16: cabeceras de seguridad HTTP**
  - Evidencia 11.1 — Antes: ninguna cabecera de seguridad, y `X-Powered-By` en las páginas
  - Evidencia 11.2 — La configuración añadida
  - Evidencia 11.3 — Después: las cinco cabeceras en las siete rutas, también en la 404 y la 401, y sin `X-Powered-By`
  - Evidencia 11.4 — `Strict-Transport-Security`: enviada, no verificable sobre HTTP
  - Evidencia 11.5 — Sin `Content-Security-Policy`: una decisión con su coste
  - Evidencia 11.6 — La interfaz sigue funcionando
  - Evidencia 11.7 — Hallazgo: las cabeceras `x-nextjs-*` y el `Vary` con `next-router-*` no se pueden quitar con un Proxy
- **Resumen de controles evidenciados**

## Tarjetas sin bloque propio

Los bloques siguen las tarjetas que tienen un control de seguridad que
demostrar. Cuatro tarjetas de los Sprints 1 y 2 no tienen bloque propio, y
esta es la razón de cada una:

| Tarjeta | Dónde está su evidencia |
|---|---|
| CITA-4 Puesta en marcha de Next.js | No introduce ningún control: es la base sobre la que se construyen los demás. |
| CITA-6 UI de registro y login | La validación del formulario es comodidad para el usuario, no un control: se salta con `curl`. Lo que la protege es el servidor, y eso es el bloque 2 (la política de contraseñas, en la 2.4). |
| CITA-8 Hashing con bcrypt | Dentro del bloque 2, en las evidencias 2.2 y 2.3: el hash se comprobó sobre la cuenta que crea el registro. |
| CITA-11 Panel de citas | Su parte de seguridad es pintar el motivo de una cita sin ejecutarlo, y está en el cierre de la 7.4. El resto del panel reutiliza la API de CITA-12, que filtra por dueño en SQL; el panel no tiene una vía propia hacia la base. |
---

# Bloque 1 — CITA-5: base de datos y privilegios mínimos

## Evidencia 1.1 — Esquema de la tabla `users`

**Qué demuestra:** La tabla impone los controles en la propia base de datos, no solo en el código de la aplicación (defensa en profundidad). Destaca `users_password_hash_is_bcrypt`: la base **rechaza el INSERT** si el valor no tiene forma de hash bcrypt, así que guardar una contraseña en texto plano es imposible incluso con un error en la aplicación. El `id` es UUID aleatorio y no un entero secuencial, para que no se puedan enumerar usuarios ni acceder a recursos ajenos cambiando un número (IDOR, OWASP A01).

**Comando**

```bash
psql -U citasegura_app -d citasegura -c "SELECT current_user, current_database(), version();" -c "\d users"
```

**Salida**

```
    usuario     |    base    |                                 version                                 
----------------+------------+-------------------------------------------------------------------------
 citasegura_app | citasegura | PostgreSQL 18.1 on x86_64-windows, compiled by msvc-19.44.35221, 64-bit
(1 row)

                                 Table "public.users"
     Column      |           Type           | Collation | Nullable |      Default      
-----------------+--------------------------+-----------+----------+-------------------
 id              | uuid                     |           | not null | gen_random_uuid()
 name            | text                     |           | not null | 
 email           | text                     |           | not null | 
 password_hash   | text                     |           | not null | 
 role            | text                     |           | not null | 'user'::text
 failed_attempts | integer                  |           | not null | 0
 locked_until    | timestamp with time zone |           |          | 
 created_at      | timestamp with time zone |           | not null | now()
Indexes:
    "users_pkey" PRIMARY KEY, btree (id)
    "users_email_key" UNIQUE CONSTRAINT, btree (email)
Check constraints:
    "users_email_format" CHECK (email ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'::text)
    "users_email_lowercase" CHECK (email = lower(email))
    "users_failed_attempts_no_negativo" CHECK (failed_attempts >= 0)
    "users_password_hash_is_bcrypt" CHECK (password_hash ~ '^\$2[aby]\$[0-9]{2}\$'::text)
    "users_role_valido" CHECK (role = ANY (ARRAY['user'::text, 'admin'::text]))
Referenced by:
    TABLE "sessions" CONSTRAINT "sessions_user_id_fkey" FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE

```

## Evidencia 1.2 — Esquema de la tabla `sessions`

**Qué demuestra:** Las sesiones se guardan por su **SHA-256**, no en texto: el `CHECK sessions_id_es_sha256_hex` solo admite 64 caracteres hexadecimales, de modo que un token en claro (base64url) no se puede insertar ni por error. La clave foránea con `ON DELETE CASCADE` evita sesiones huérfanas que sigan siendo válidas para una cuenta ya borrada.

**Comando**

```bash
psql -U citasegura_app -d citasegura -c "\d sessions"
```

**Salida**

```
                        Table "public.sessions"
   Column   |           Type           | Collation | Nullable | Default 
------------+--------------------------+-----------+----------+---------
 id         | text                     |           | not null | 
 user_id    | uuid                     |           | not null | 
 expires_at | timestamp with time zone |           | not null | 
 created_at | timestamp with time zone |           | not null | now()
Indexes:
    "sessions_pkey" PRIMARY KEY, btree (id)
    "sessions_expires_at_idx" btree (expires_at)
    "sessions_user_id_idx" btree (user_id)
Check constraints:
    "sessions_caduca_despues_de_crearse" CHECK (expires_at > created_at)
    "sessions_id_es_sha256_hex" CHECK (id ~ '^[0-9a-f]{64}$'::text)
Foreign-key constraints:
    "sessions_user_id_fkey" FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE

```

## Evidencia 1.3 — El rol de la aplicación no es superusuario y tiene privilegios mínimos

**Qué demuestra:** `citasegura_app` no puede crear bases ni roles, no ignora la seguridad por filas, solo tiene `SELECT/INSERT/DELETE` sobre las tablas, y su `UPDATE` está acotado a **dos columnas** (las del bloqueo de cuentas). Las tablas pertenecen a `postgres` a propósito, así que la aplicación no puede alterarlas ni eliminarlas. Sobre el esquema `public` tiene `USAGE` pero no `CREATE`.

**Comando**

```bash
psql -U citasegura_app -d citasegura -f consultas-de-privilegios.sql
```

**Salida**

```
--- Atributos del rol, comparados con el superusuario ---
      rol       | es_superusuario | puede_crear_bases | puede_crear_roles | ignora_seguridad_por_filas | puede_conectarse 
----------------+-----------------+-------------------+-------------------+----------------------------+------------------
 postgres       | t               | t                 | t                 | t                          | t
 citasegura_app | f               | f                 | f                 | f                          | t
(2 rows)

--- Privilegios de TABLA de citasegura_app ---
  tabla   |      privilegios       
----------+------------------------
 sessions | DELETE, INSERT, SELECT
 users    | DELETE, INSERT, SELECT
(2 rows)

--- UPDATE acotado por COLUMNA ---
 tabla |    columnas_actualizables     
-------+-------------------------------
 users | failed_attempts, locked_until
(1 row)

--- Dueno de las tablas ---
  tabla   |  dueno   
----------+----------
 sessions | postgres
 users    | postgres
(2 rows)

--- Permisos sobre el esquema public ---
 puede_usar_el_esquema | puede_crear_objetos 
-----------------------+---------------------
 t                     | f
(1 row)

```

> **Nota posterior (CITA-18).** Esta salida se conserva tal cual: es el
> registro fechado de una ejecución real del 25 de septiembre, y entonces era
> cierta. Desde CITA-18, `citasegura_app` **ya no tiene `DELETE` sobre
> `users`**. Ese permiso existía sin que ninguna funcionalidad de la aplicación
> lo usara —solo lo necesitaba un script de pruebas para borrar sus cuentas—, y
> con el borrado en cascada permitía destruir el historial de citas de una
> persona borrando su cuenta. Se retiró con un `REVOKE` explícito en
> `db/roles.sql`; la evidencia del estado actual está en el **Bloque 5**
> (evidencias 5.2 y 5.4).

## Evidencia 1.4 — Ataques ejecutados con las credenciales reales de la aplicación: todos denegados

**Qué demuestra:** Cada sentencia se ejecutó con el usuario y contraseña que usa la aplicación en producción, es decir, simulando a un atacante que ya logró una inyección SQL o se hizo con el fichero `.env.local`. El motor **deniega antes de tocar una sola fila**: ningún dato se modificó al generar esta evidencia.

### Destruir la tabla de usuarios

```sql
DROP TABLE users;
```

```
ERROR:  debe ser dueño de la tabla users
```

### Vaciar la tabla de usuarios

```sql
TRUNCATE users;
```

```
ERROR:  permiso denegado a la tabla users
```

### Crear un rol propio para persistir en el servidor

```sql
CREATE ROLE atacante LOGIN PASSWORD 'lo_que_sea';
```

```
ERROR:  se ha denegado el permiso para crear el rol
DETAIL:  Sólo los roles con el atributo CREATEROLE pueden crear roles.
```

### Escalar privilegios a administrador

```sql
UPDATE users SET role = 'admin' WHERE email = 'victima@ejemplo.com';
```

```
ERROR:  permiso denegado a la tabla users
```

### Reescribir la contrasena de otra cuenta

```sql
UPDATE users SET password_hash = '$2b$12$0000000000000000000000000000000000000000000000000000' WHERE email = 'victima@ejemplo.com';
```

```
ERROR:  permiso denegado a la tabla users
```

### Secuestrar una cuenta cambiando su correo

```sql
UPDATE users SET email = 'atacante@ejemplo.com' WHERE email = 'victima@ejemplo.com';
```

```
ERROR:  permiso denegado a la tabla users
```

### Quitar la restriccion que obliga a usar bcrypt

```sql
ALTER TABLE users DROP CONSTRAINT users_password_hash_is_bcrypt;
```

```
ERROR:  debe ser dueño de la tabla users
```

### Crear una tabla puerta trasera

```sql
CREATE TABLE puerta_trasera (id int);
```

```
ERROR:  permiso denegado al esquema public
LINE 1: CREATE TABLE puerta_trasera (id int);
                     ^
```

### Alterar una sesion para apuntarla a otro usuario

```sql
UPDATE sessions SET user_id = gen_random_uuid();
```

```
ERROR:  permiso denegado a la tabla sessions
```

### Echar a todos los usuarios borrando las sesiones de golpe

```sql
TRUNCATE sessions;
```

```
ERROR:  permiso denegado a la tabla sessions
```

### Leer los hashes de contrasena de los ROLES del servidor

```sql
SELECT rolname, rolpassword FROM pg_authid;
```

```
ERROR:  permiso denegado a la tabla pg_authid
```

> Nota: `DROP TABLE` y `ALTER TABLE` responden «debe ser dueño de la tabla»
> en lugar de «permiso denegado»; son igualmente denegaciones, y su causa es
> que las tablas pertenecen a `postgres` y no al rol de la aplicación.

## Evidencia 1.5 — Aislamiento entre bases de datos

**Qué demuestra:** El servidor local aloja otras seis bases de datos de proyectos distintos. Se revocó `CONNECT` a `PUBLIC` en todas ellas, así que una credencial de CitaSegura filtrada no sirve para leer los datos de los demás proyectos. La primera consulta muestra el privilegio efectivo y los intentos posteriores lo confirman con conexiones reales.

**Comando**

```bash
psql -U citasegura_app -d citasegura -c "SELECT datname, has_database_privilege(...)"
```

**Salida**

```
  base_de_datos  | puede_conectarse 
-----------------+------------------
 citasegura      | t
 cortex_dev      | f
 devportfolio_db | f
 notes_app_db    | f
 notes_app_final | f
 postgres        | f
 template1       | f
(7 rows)

```

**Comando**

```bash
for b in postgres cortex_dev devportfolio_db notes_app_db notes_app_final citasegura; do
    psql -U citasegura_app -d "$b" -c "SELECT 1;"
done
```

**Salida**

```
postgres           -> psql: error: connection to server at "localhost" (::1), port 5432 failed: FATAL:  permiso denegado a la base de datos «postgres» DETAIL:  Usuario no tiene privilegios de conexión.
cortex_dev         -> psql: error: connection to server at "localhost" (::1), port 5432 failed: FATAL:  permiso denegado a la base de datos «cortex_dev» DETAIL:  Usuario no tiene privilegios de conexión.
devportfolio_db    -> psql: error: connection to server at "localhost" (::1), port 5432 failed: FATAL:  permiso denegado a la base de datos «devportfolio_db» DETAIL:  Usuario no tiene privilegios de conexión.
notes_app_db       -> psql: error: connection to server at "localhost" (::1), port 5432 failed: FATAL:  permiso denegado a la base de datos «notes_app_db» DETAIL:  Usuario no tiene privilegios de conexión.
notes_app_final    -> psql: error: connection to server at "localhost" (::1), port 5432 failed: FATAL:  permiso denegado a la base de datos «notes_app_final» DETAIL:  Usuario no tiene privilegios de conexión.
citasegura         -> conexion permitida (control positivo)
```

---

# Bloque 2 — CITA-7 y CITA-8: registro de usuario seguro y contraseñas con bcrypt

Este bloque recoge dos tarjetas. CITA-7 es el endpoint de registro; CITA-8 es
el hashing de la contraseña con bcrypt, y su evidencia son la 2.2 y la 2.3,
hechas sobre la cuenta que crea el propio registro.

Endpoint `POST /api/auth/register`. Todas las peticiones de este bloque se
hacen con **curl**, es decir, saltándose por completo el formulario del
navegador: así se demuestra que el control vive en el servidor y no en la
validación del cliente, que cualquiera puede desactivar.

## Evidencia 2.1 — Registro válido y normalización de los datos

**Qué demuestra:** El servidor acepta el registro y normaliza lo recibido: recorta los espacios del nombre y pasa el correo a minúsculas antes de guardarlo, para que `PRUEBA@X.COM` y `prueba@x.com` no puedan convertirse en dos cuentas distintas. Se envían el nombre con espacios sobrantes y el correo en mayúsculas a propósito.

**Comando**

```bash
curl -i -X POST http://localhost:3001/api/auth/register -H 'Content-Type: application/json' \
     -d '{"name":"  Usuario Evidencia  ","email":"  EVIDENCIA.Fase2@Ejemplo.COM ","password":"ClaveEvidencia1!"}'
```

**Salida**

```
HTTP/1.1 201 Created
content-type: application/json

{"message":"Si el correo no estaba registrado, la cuenta ha sido creada. Ya puedes iniciar sesion."}
```

## Evidencia 2.2 — La contraseña se guarda como hash bcrypt, nunca en texto

**Qué demuestra:** Consulta directa a la base de datos sobre la cuenta recién creada. El hash tiene el prefijo `$2b$12$` (bcrypt con factor de coste 12) y 60 caracteres. La columna `posicion_de_la_clave_en_el_hash` vale **0**, que en PostgreSQL significa «no aparece»: la contraseña en claro no está en ninguna parte de la fila. El nombre se guardó sin espacios sobrantes y el correo en minúsculas.

**Comando**

```bash
psql -U citasegura_app -d citasegura -f consulta-hash.sql
```

**Salida**

```
-[ RECORD 1 ]-------------------+-------------------------------------------------------------
nombre_guardado                 | Usuario Evidencia
correo_guardado                 | evidencia.fase2@ejemplo.com
hash_guardado                   | $2b$12$TieDC.9fLw1S8sSnC7V1TOv9QXsIcV.f5kGKI.IDyGqmfS7ripai6
largo_del_hash                  | 60
prefijo                         | $2b$12$
cumple_el_check_de_bcrypt       | t
posicion_de_la_clave_en_el_hash | 0
rol_asignado                    | user
intentos_fallidos               | 0
bloqueada_hasta                 | 

```

## Evidencia 2.3 — La base de datos rechaza una contraseña en texto plano

**Qué demuestra:** Segunda barrera, independiente del código de la aplicación: se intenta insertar una fila con la contraseña sin hashear, usando las credenciales reales de la aplicación. La restricción `users_password_hash_is_bcrypt` aborta el `INSERT`. Es la razón por la que un error de programación no puede acabar en contraseñas en claro.

**Comando**

```bash
psql -U citasegura_app -d citasegura -c "INSERT INTO users (name, email, password_hash) VALUES ('Fulano', 'texto.plano@ejemplo.com', 'MiClaveEnTextoPlano123');"
```

**Salida**

```
ERROR:  el nuevo registro para la relación «users» viola la restricción «check» «users_password_hash_is_bcrypt»
DETAIL:  La fila que falla contiene (a9a3cd0b-ba15-4f94-8615-2a4a31575f5b, Fulano, texto.plano@ejemplo.com, MiClaveEnTextoPlano123, user, 0, null, 2026-09-25 22:11:26.61848-05).
```

## Evidencia 2.4 — Peticiones maliciosas o inválidas rechazadas por el servidor

**Qué demuestra:** Cuatro ataques al endpoint de registro. El tercero es el más relevante: el esquema Zod usa `z.strictObject`, que rechaza el cuerpo completo si trae claves no declaradas, de modo que enviar `"role":"admin"` no crea un administrador sino un error 400 (defensa contra *mass assignment*). El cuarto se rechaza por el `Content-Type`, lo que además dificulta el CSRF: un formulario alojado en otro sitio no puede enviar `application/json` sin un preflight CORS que este endpoint no autoriza.

### Correo con formato inválido

```bash
curl -i -X POST http://localhost:3001/api/auth/register -H 'Content-Type: application/json' \
     -d '{"name":"Atacante","email":"no-es-un-correo","password":"ClaveEvidencia1!"}'
```

```
HTTP/1.1 400 Bad Request
content-type: application/json

{"message":"Los datos enviados no son validos.","errors":{"email":["Introduce un correo electronico valido."]}}

```

### Contraseña débil (no cumple la política de CITA-6)

```bash
curl -i -X POST http://localhost:3001/api/auth/register -H 'Content-Type: application/json' \
     -d '{"name":"Atacante","email":"debil@ejemplo.com","password":"123"}'
```

```
HTTP/1.1 400 Bad Request
content-type: application/json

{"message":"Los datos enviados no son validos.","errors":{"password":["La contrasena debe tener al menos 12 caracteres.","Debe incluir al menos una letra minuscula.","Debe incluir al menos una letra mayuscula.","Debe incluir al menos un simbolo (por ejemplo ! ? # $ % & * -)."]}}

```

### Escalada de privilegios por mass assignment

```bash
curl -i -X POST http://localhost:3001/api/auth/register -H 'Content-Type: application/json' \
     -d '{"name":"Atacante","email":"escalada@ejemplo.com","password":"ClaveEvidencia1!","role":"admin"}'
```

```
HTTP/1.1 400 Bad Request
content-type: application/json

{"message":"Los datos enviados no son validos.","errors":{}}

```

### Envío tipo formulario desde otro sitio (sin JSON)

```bash
curl -i -X POST http://localhost:3001/api/auth/register -H 'Content-Type: application/x-www-form-urlencoded' \
     -d 'name=Atacante&email=csrf@ejemplo.com&password=ClaveEvidencia1!'
```

```
HTTP/1.1 415 Unsupported Media Type
content-type: application/json

{"message":"Se esperaba un cuerpo JSON."}

```

## Evidencia 2.5 — Los intentos rechazados no dejaron rastro en la base de datos

**Qué demuestra:** Ninguno de los correos usados en los ataques anteriores (`debil@`, `escalada@`, `csrf@`, `texto.plano@`) existe en la tabla: los rechazos ocurrieron **antes** de escribir nada. La única cuenta nueva es la de evidencia.

**Comando**

```bash
psql -U citasegura_app -d citasegura -c "SELECT email, role, created_at FROM users ORDER BY created_at;"
```

**Salida**

```
           correo            | rol  |            creado             
-----------------------------+------+-------------------------------
 test@gmail.com              | user | 2026-09-25 20:17:50.138864-05
 evidencia.fase2@ejemplo.com | user | 2026-09-25 22:11:26.146331-05
(2 rows)

```

## Evidencia 2.6 — Anti-enumeración de usuarios: el correo duplicado responde igual que un registro nuevo

**Qué demuestra:** Si el servidor contestara «ese correo ya está registrado», el endpoint se convertiría en un directorio de usuarios: se le pasa una lista de correos y revela quién tiene cuenta. En una aplicación de citas médicas eso ya es un dato personal. Aquí las dos respuestas son idénticas en **estado, cuerpo y tiempo**: el duplicado también ejecuta el hasheo bcrypt, para que no se delate por ser más rápido. El caso duplicado se captura por el registro del servidor, no por la respuesta.

**Comando**

```bash
# el mismo correo del 2.1, enviado por segunda vez
curl -i -X POST http://localhost:3001/api/auth/register -H 'Content-Type: application/json' \
     -d '{"name":"Otro Nombre","email":"evidencia.fase2@ejemplo.com","password":"OtraClaveDistinta9#"}'
```

**Salida**

```
HTTP/1.1 201 Created
content-type: application/json

{"message":"Si el correo no estaba registrado, la cuenta ha sido creada. Ya puedes iniciar sesion."}
```

Comparación de tiempos entre un registro nuevo y uno duplicado (cuatro
mediciones de cada uno, en segundos):

**Comando**

```bash
for i in 1 2 3 4; do
    curl -o /dev/null -X POST http://localhost:3001/api/auth/register ... -w '%{time_total}'   # correo NUEVO cada vez
    curl -o /dev/null -X POST http://localhost:3001/api/auth/register ... -w '%{time_total}'   # correo DUPLICADO
done
```

**Salida**

```
correo NUEVO (crea la cuenta)      0.696712s 0.410183s 0.542673s 0.510757s
correo DUPLICADO (ya existe)       0.621688s 0.461600s 0.578315s 0.465538s
```

> Las cuatro cuentas `evidencia.tiempos.N@ejemplo.com` se crearon solo para
> esta medición: la primera tanda las crea y la segunda repite los mismos
> correos, que es lo que provoca la violación de la restricción `UNIQUE`
> (código PostgreSQL `23505`) capturada por el endpoint.

---

# Bloque 3 — CITA-9: inicio de sesión con sesiones propias

Sesiones implementadas a mano (sin Auth.js/NextAuth) con el modelo de
**sesión opaca del lado del servidor**: la cookie no contiene datos ni firma
nada, es solo un identificador aleatorio; toda la información real vive en la
tabla `sessions`. Es lo contrario de un JWT autocontenido, y es deliberado:
un JWT no se puede revocar, y aquí cerrar sesión y bloquear cuentas exigen
poder invalidar en el servidor.

## Evidencia 3.1 — Login correcto y flags de la cookie de sesión

**Qué demuestra:** La cabecera `Set-Cookie` muestra los tres controles: **`HttpOnly`** impide que el JavaScript de la página lea la cookie, así que un XSS no puede exfiltrar el token; **`SameSite=lax`** impide que el navegador la envíe en peticiones POST originadas en otro sitio, lo que corta el CSRF clásico; y **`Max-Age=28800`** (8 horas) limita la ventana en la que un token robado sirve. El flag `Secure` está condicionado a producción, porque en desarrollo se sirve por HTTP y el navegador descartaría una cookie `Secure`. La respuesta nunca incluye el `password_hash`.

**Comando**

```bash
curl -i -c jar.txt -X POST http://localhost:3001/api/auth/login -H 'Content-Type: application/json' \
     -d '{"email":"evidencia.fase2@ejemplo.com","password":"ClaveEvidencia1!"}'
```

**Salida**

```
HTTP/1.1 200 OK
content-type: application/json
set-cookie: citasegura_session=guPT8PyE1cBzasURQYzDeKIznj0WNzq_AXKDpSURmmY; Path=/; Expires=Sat, 26 Sep 2026 11:12:54 GMT; Max-Age=28800; HttpOnly; SameSite=lax

{"message":"Sesion iniciada.","user":{"name":"Usuario Evidencia","email":"evidencia.fase2@ejemplo.com","role":"user"}}
```

## Evidencia 3.2 — En la tabla `sessions` el token está hasheado, no en texto

**Qué demuestra:** Lo que viaja en la cookie es un token aleatorio de 32 bytes (256 bits) generado con `crypto.randomBytes`, nunca con `Math.random()`, cuyo estado interno es reconstruible y haría los tokens predecibles. En la base **solo se guarda su SHA-256**: quien logre leer la tabla no obtiene sesiones utilizables. Se usa SHA-256 y no bcrypt porque el hash debe ser determinista para buscar la fila por clave primaria, y porque la lentitud de bcrypt solo aporta frente a contraseñas adivinables, no frente a tokens de 256 bits aleatorios. La comprobación es doble: el SHA-256 calculado **fuera** de la base (con `sha256sum`) coincide con el `id` almacenado.

**Comando**

```bash
# token tal como viaja en la cookie, y su SHA-256 calculado por separado
TOKEN=$(grep citasegura_session jar.txt | awk '{print $7}')
printf '%s' "$TOKEN" | sha256sum
```

**Salida**

```
token de la cookie        : guPT8PyE1cBzasURQYzDeKIznj0WNzq_AXKDpSURmmY   (43 caracteres, base64url)
sha256sum de ese token    : ba08360c66af20b3ea98b84dff57b576941fe7eae72c4d47f7116d7c832e281e
```

**Comando**

```bash
psql -U citasegura_app -d citasegura -f consulta-sesion.sql
```

**Salida**

```
-[ RECORD 1 ]--------------------+-----------------------------------------------------------------
id_guardado_en_la_base           | ba08360c66af20b3ea98b84dff57b576941fe7eae72c4d47f7116d7c832e281e
largo                            | 64
coincide_con_el_sha256_del_token | t
contiene_el_token_en_claro       | f
propietario                      | evidencia.fase2@ejemplo.com
caduca_en                        | 07:59:59
creada                           | 2026-09-25 22:12:54.013907-05

```

> El token que aparece arriba quedó **revocado** por el cierre de sesión de la
> evidencia 3.4, así que este documento no contiene una credencial utilizable.

## Evidencia 3.3 — Ruta protegida: solo se entra con una cookie de sesión válida

**Qué demuestra:** `GET /api/auth/me` es la plantilla de cómo se protegerá cualquier ruta futura. Con la cookie válida responde 200 con los datos del usuario; sin cookie y con un token inventado de la misma longitud responde 401 con el mismo mensaje. No se distingue «no había cookie» de «la cookie era inválida» ni de «la sesión caducó»: para quien no está autenticado, las tres cosas son lo mismo.

**Comando**

```bash
curl -i -b jar.txt http://localhost:3001/api/auth/me                                   # con la cookie valida
curl -i http://localhost:3001/api/auth/me                                              # sin cookie
curl -i -H 'Cookie: citasegura_session=<token inventado>' http://localhost:3001/api/auth/me
```

**Salida**

```
=== a) con la cookie valida ===
HTTP/1.1 200 OK
content-type: application/json

{"user":{"id":"d8b40159-befd-442f-ba45-fa1b47444f16","name":"Usuario Evidencia","email":"evidencia.fase2@ejemplo.com","role":"user"},"expiresAt":"2026-09-26T11:12:54.012Z"}

=== b) sin cookie ===
HTTP/1.1 401 Unauthorized
content-type: application/json

{"message":"No autenticado."}

=== c) con un token inventado de 43 caracteres ===
HTTP/1.1 401 Unauthorized
content-type: application/json

{"message":"No autenticado."}
```

## Evidencia 3.4 — El cierre de sesión revoca en el servidor, no solo en el navegador

**Qué demuestra:** Es la evidencia más importante del bloque. El logout responde con una `Set-Cookie` vacía y caducada en 1970, que es la forma de pedirle al navegador que la borre. Pero lo esencial es el `DELETE` de la fila: a continuación se reenvía **la cookie antigua, que sigue siendo un token válido**, y la ruta protegida responde 401. Si el logout solo hubiera borrado la copia del navegador, ahí habría respondido 200 — y eso es precisamente lo que un JWT autocontenido no puede evitar.

**Comando**

```bash
cp jar.txt jar-antes-del-logout.txt        # guardar la cookie antes de cerrar
curl -i -b jar.txt -X POST http://localhost:3001/api/auth/logout
curl -i -b jar-antes-del-logout.txt http://localhost:3001/api/auth/me   # reenviar la cookie ya revocada
```

**Salida**

```
=== logout ===
HTTP/1.1 200 OK
content-type: application/json
set-cookie: citasegura_session=; Path=/; Expires=Thu, 01 Jan 1970 00:00:00 GMT

{"message":"Sesion cerrada."}

=== reintento con la cookie ANTIGUA (token valido, sesion revocada) ===
HTTP/1.1 401 Unauthorized
content-type: application/json

{"message":"No autenticado."}
```

**Comando**

```bash
psql -U citasegura_app -d citasegura -c "SELECT count(*) FROM sessions ..."
```

**Salida**

```
 sesiones_de_la_cuenta_de_evidencia 
------------------------------------
                                  0
(1 row)

```

## Evidencia 3.5 — Anti-enumeración por tiempo en el login

**Qué demuestra:** El ataque que se cierra aquí no lee la respuesta, **mide el reloj**. Si el servidor, al no encontrar el correo, respondiera sin ejecutar bcrypt, ese camino tardaría ~15 ms frente a los ~400 ms de una cuenta real: bastaría cronometrar para saber qué correos tienen cuenta, aunque el mensaje sea idéntico. La defensa es comparar siempre contra un **hash señuelo** de coste 12 cuando el correo no existe, y descartar el resultado. La última fila es la referencia: un camino que no llega a bcrypt (cuerpo rechazado por Zod) para ver qué se observaría si hubiera fuga.

**Comando**

```bash
for caso in ...; do
    curl -o /dev/null -X POST http://localhost:3001/api/auth/login -H 'Content-Type: application/json' \
         -d '{"email":"...","password":"..."}' -w '%{time_total}'
done
```

**Salida**

```
cuenta EXISTE, contrasena incorrecta         0.447244s 0.439005s 0.590361s 0.453781s
correo que NO EXISTE                         0.412308s 0.540246s 0.419450s 0.447216s
referencia sin bcrypt (Zod rechaza)          0.009876s 0.010675s 0.019714s 0.010255s
```

> Los cuatro fallos de la primera fila dejaron el contador de intentos de la
> cuenta de evidencia en 4. Se reinicia con SQL directo para que el bloqueo de
> CITA-10 no interfiera en este bloque; el bloqueo se demuestra, con su propia
> cuenta, en el bloque 4.

**Comando**

```bash
psql -U citasegura_app -d citasegura -c "UPDATE users SET failed_attempts = 0 WHERE email = 'evidencia.fase2@ejemplo.com';"
```

**Salida**

```
UPDATE 1
           correo            | intentos_fallidos | bloqueada_hasta 
-----------------------------+-------------------+-----------------
 evidencia.fase2@ejemplo.com |                 0 | 
(1 row)

```

---

# Bloque 4 — CITA-10: bloqueo de cuenta por intentos fallidos

Política: **5 intentos fallidos consecutivos bloquean la cuenta 15 minutos**, y
el bloqueo vence solo, sin intervención de un administrador. La justificación
numérica: 5 intentos cada 15 minutos son 20 por hora y 480 al día, cantidad
indistinguible de cero frente a una contraseña que cumple la política de
CITA-6. Que venza solo evita que el propio bloqueo se convierta en un ataque
de saturación al soporte técnico.

El privilegio de escritura necesario está acotado a **dos columnas**
(`failed_attempts` y `locked_until`): ver las evidencias 1.3 y 1.4, donde se
comprueba que la aplicación no puede modificar `role`, `password_hash` ni
`email`.

## Evidencia 4.1 — El contador sube con cada fallo y al quinto se activa el bloqueo

**Qué demuestra:** Se crea una cuenta nueva y se falla cinco veces seguidas. El contador avanza 1, 2, 3, 4, 5 y en el quinto intento aparece `locked_until` con 15 minutos de margen. **Las cinco respuestas son idénticas** (401 y el mismo mensaje genérico): el cliente nunca sabe cuántos intentos le quedan ni que acaba de quedar bloqueado. El incremento y la decisión de bloquear ocurren en **una sola sentencia SQL atómica**, de modo que varios intentos simultáneos no pueden corromper el contador (el patrón «leer en JavaScript, sumar, escribir» perdería cuentas y el bloqueo nunca saltaría).

**Comando**

```bash
curl -X POST http://localhost:3001/api/auth/register ...                  # crear la cuenta de prueba
for i in 1 2 3 4 5; do
    curl -X POST http://localhost:3001/api/auth/login -d '{"email":"evidencia.bloqueo@ejemplo.com","password":"ClaveMala$i!"}'
    psql -c "SELECT failed_attempts, locked_until FROM users WHERE email = '...'"
done
```

**Salida**

```
register -> HTTP 201
estado inicial             -> intentos=0 | locked_until=NULL | activa
fallo 1                    -> HTTP 401 | 0.453081s | intentos=1 | locked_until=NULL | activa
fallo 2                    -> HTTP 401 | 0.424714s | intentos=2 | locked_until=NULL | activa
fallo 3                    -> HTTP 401 | 0.436809s | intentos=3 | locked_until=NULL | activa
fallo 4                    -> HTTP 401 | 0.533751s | intentos=4 | locked_until=NULL | activa
fallo 5                    -> HTTP 401 | 0.445907s | intentos=5 | bloqueada_hasta=22:29:38 | BLOQUEADA (00:14:59 restantes)
```

## Evidencia 4.2 — Con la cuenta bloqueada, incluso la contraseña CORRECTA es rechazada

**Qué demuestra:** Se envía la contraseña verdadera. La respuesta es el mismo 401 con el mismo mensaje, **y no se emite ninguna cabecera `Set-Cookie`**: no se crea sesión. Que el mensaje sea idéntico al de credenciales inválidas es el punto central del diseño: un «demasiados intentos, espera 15 minutos» sería un oráculo doble, porque solo una cuenta que existe puede bloquearse y el atacante puede provocar el bloqueo él mismo para sondear cualquier correo de una lista.

**Comando**

```bash
curl -i -X POST http://localhost:3001/api/auth/login -H 'Content-Type: application/json' \
     -d '{"email":"evidencia.bloqueo@ejemplo.com","password":"ClaveBloqueo1!"}'   # la contrasena CORRECTA
```

**Salida**

```
HTTP/1.1 401 Unauthorized
content-type: application/json

{"message":"Correo o contrasena incorrectos."}

cabeceras Set-Cookie recibidas: 0
```

## Evidencia 4.3 — Insistir durante el bloqueo no lo alarga (sin amplificación)

**Qué demuestra:** Tres intentos más con la cuenta ya bloqueada. `bloqueada_hasta` **no cambia** y el contador sigue en 5, mientras el tiempo restante baja. Es deliberado: si cada intento extendiera `locked_until`, un atacante mantendría a su víctima fuera indefinidamente con solo insistir. El bloqueo vence cuando le toca, aunque sigan llegando peticiones.

**Comando**

```bash
for i in 1 2 3; do curl -X POST http://localhost:3001/api/auth/login -d '{...basura...}'; done
```

**Salida**

```
golpe extra 1              -> HTTP 401 | 0.446405s | intentos=5 | bloqueada_hasta=22:29:38 | BLOQUEADA (00:14:57 restantes)
golpe extra 2              -> HTTP 401 | 0.557901s | intentos=5 | bloqueada_hasta=22:29:38 | BLOQUEADA (00:14:57 restantes)
golpe extra 3              -> HTTP 401 | 0.409749s | intentos=5 | bloqueada_hasta=22:29:38 | BLOQUEADA (00:14:56 restantes)
```

## Evidencia 4.4 — Vencido el bloqueo se puede entrar, y el login correcto reinicia el contador

**Qué demuestra:** Se adelanta `locked_until` al pasado para simular que transcurrieron los 15 minutos (es la única columna, junto al contador, que la aplicación puede escribir). Con el bloqueo vencido la contraseña correcta entra con 200 y cookie de sesión, y el estado queda en `intentos=0` y `locked_until=NULL`. Reiniciar es imprescindible: lo que se cuenta son fallos **consecutivos**; sin reinicio, los errores de tecleo se acumularían durante meses y cualquier cuenta acabaría bloqueándose sola.

**Comando**

```bash
psql -c "UPDATE users SET locked_until = now() - interval '1 second' WHERE email = '...';"
curl -i -X POST http://localhost:3001/api/auth/login -d '{"email":"evidencia.bloqueo@ejemplo.com","password":"<correcta>"}'
```

**Salida**

```
UPDATE 1
estado tras vencer         -> intentos=5 | bloqueada_hasta=22:14:41 | activa

HTTP/1.1 200 OK
content-type: application/json
set-cookie: citasegura_session=<token recortado>; Path=/; Expires=Sat, 26 Sep 2026 11:14:43 GMT; Max-Age=28800; HttpOnly; SameSite=lax

{"message":"Sesion iniciada.","user":{"name":"Usuario Bloqueo","email":"evidencia.bloqueo@ejemplo.com","role":"user"}}

estado tras entrar         -> intentos=0 | locked_until=NULL | activa
```

Y un fallo posterior a un bloqueo ya vencido abre una **ventana nueva**
(contador a 1, no a 6), para que una cuenta que se bloqueó una vez no vuelva a
bloquearse con un solo error para siempre:

**Comando**

```bash
psql -c "UPDATE users SET failed_attempts = 5, locked_until = now() - interval '1 minute' WHERE email = '...';"
curl -X POST http://localhost:3001/api/auth/login -d '{...contrasena incorrecta...}'
```

**Salida**

```
UPDATE 1
estado preparado           -> intentos=5 | bloqueada_hasta=22:13:43 | activa
un fallo                   -> HTTP 401 | 0.475673s | intentos=1 | locked_until=NULL | activa
```

## Evidencia 4.5 — El bloqueo no introduce una diferencia de tiempo que delate si la cuenta existe

**Qué demuestra:** La comprobación del bloqueo se hace **después** de la verificación bcrypt, no antes. Si se cortara antes de hashear, la respuesta de una cuenta bloqueada llegaría en ~15 ms en lugar de ~400 ms y, como solo una cuenta existente puede estar bloqueada, esa diferencia volvería a delatar por el reloj lo que el mensaje oculta. La invariante del endpoint es: toda petición que llega a la fase de credenciales ejecuta **exactamente una** comparación bcrypt. Los tres casos quedan indistinguibles, y el caso «no existe» cae entre los dos casos «existe».

**Comando**

```bash
for caso in activa-mala / inexistente / bloqueada; do
    curl -o /dev/null -X POST http://localhost:3001/api/auth/login -d '{...}' -w '%{time_total}'   # x4
done
```

**Salida**

```
1) cuenta ACTIVA, contrasena incorrecta    0.444811s 0.488955s 0.432139s 0.423728s
2) correo que NO EXISTE                    0.403695s 0.541318s 0.419605s 0.421365s
3) cuenta BLOQUEADA, contrasena correcta   0.410926s 0.430024s 0.648161s 0.608773s
referencia sin bcrypt (Zod rechaza)        0.049987s 0.015788s 0.018151s 0.018872s
```

## Evidencia 4.6 — Estado final de la base de datos

**Qué demuestra:** Estado de la base **después** de eliminar las cuentas de evidencia (ver el apartado de limpieza, al final). Queda únicamente `test@gmail.com`, cuenta preexistente del desarrollador que no se modificó en ningún momento: su contraseña sigue guardada como hash bcrypt, su contador de intentos está a 0 y no tiene bloqueo. La tabla `sessions` queda vacía, lo que confirma además que el `ON DELETE CASCADE` arrastró las sesiones de las cuentas borradas.

**Comando**

```bash
psql -U citasegura_app -d citasegura -c "SELECT email, role, failed_attempts, locked_until, ... FROM users;"
```

**Salida**

```
     correo     | rol  | prefijo_del_hash | intentos_fallidos | bloqueada_hasta | sesiones_activas 
----------------+------+------------------+-------------------+-----------------+------------------
 test@gmail.com | user | $2b$12$          |                 0 |                 |                0
(1 row)
```

## Limpieza de las cuentas de evidencia

Una vez generadas todas las evidencias, las cuentas creadas para este documento
se eliminaron con la sentencia siguiente. El `DELETE` arrastra sus sesiones por
la clave foránea `ON DELETE CASCADE`. El patrón solo alcanza a las cuentas
`evidencia.*` de `ejemplo.com`, así que no afecta a `test@gmail.com` ni a
ninguna cuenta real:

```sql
DELETE FROM users WHERE email LIKE 'evidencia.%@ejemplo.com' RETURNING email;
```

**Salida**

```
              email              
---------------------------------
 evidencia.fase2@ejemplo.com
 evidencia.bloqueo@ejemplo.com
 evidencia.tiempos.1@ejemplo.com
 evidencia.tiempos.2@ejemplo.com
 evidencia.tiempos.3@ejemplo.com
 evidencia.tiempos.4@ejemplo.com
(6 rows)

DELETE 6
```

El inventario de la evidencia 4.6 corresponde al estado **posterior** a esta
limpieza.

---

# Bloque 5 — CITA-18: esquema seguro de la tabla de citas

| | |
|---|---|
| **Generado** | 2026-10-08 22:34:25 |
| **Script** | `db/scripts-evidencias/evidencia-cita18.sh` |
| **Salida completa** | `db/scripts-evidencias/salida-cita18.txt` |
| **Rol** | `citasegura_app` en todas las pruebas; `postgres` solo para la limpieza |

Todas las pruebas de este bloque se ejecutan con el rol real de la aplicación:
lo que se demuestra es lo que **la aplicación** puede y no puede hacer, no lo
que puede un administrador.

> **Sobre la numeración.** Las salidas se reproducen tal como las imprimió el
> script, y el script numera sus intentos `4.1`–`4.12` y `5.1`–`5.3`. Esa
> numeración es la **del script**, no la de este documento: el «intento 4.1»
> no tiene relación con la evidencia 4.1 del bloque CITA-10.

> **Sobre la codificación.** psql en Windows escribe sus propios textos
> (`Tabla «…»`, `Índices:`) en CP1252 y los mensajes del servidor en UTF-8, así
> que el fichero de salida mezcla ambas. Aquí cada línea se muestra decodificada
> con la codificación en que se escribió; el contenido no se ha alterado. El
> encabezado cortado `Por omisi` está así en la salida original.

## Evidencia 5.1 — Esquema de la tabla `appointments`: restricciones `CHECK` e índices

**Qué demuestra:** Las reglas del dominio las impone la base de datos, no solo
el código: el estado solo admite `programada` y `cancelada`, una cita no puede
agendarse antes de crearse, y el motivo no puede estar vacío ni pasar de 500
caracteres. El `id` es un UUID aleatorio (anti-IDOR), `id`, `status` y
`created_at` tienen valores por defecto que pone la base, y `user_id` es una
clave foránea a `users`, así que no puede existir una cita sin dueño. El índice
compuesto `(user_id, scheduled_at)` sirve para listar las citas de una persona
ya ordenadas; la búsqueda por id usa el índice de la clave primaria.

**Comando**

```bash
psql -h 127.0.0.1 -U citasegura_app -d citasegura -c "\d appointments"
```

**Salida**

```
                           Tabla «public.appointments»
   Columna    |           Tipo           | Ordenamiento | Nulable  |     Por omisi      
--------------+--------------------------+--------------+----------+--------------------
 id           | uuid                     |              | not null | gen_random_uuid()
 user_id      | uuid                     |              | not null | 
 scheduled_at | timestamp with time zone |              | not null | 
 reason       | text                     |              | not null | 
 status       | text                     |              | not null | 'programada'::text
 created_at   | timestamp with time zone |              | not null | now()
Índices:
    "appointments_pkey" PRIMARY KEY, btree (id)
    "appointments_user_id_scheduled_at_idx" btree (user_id, scheduled_at)
Restricciones CHECK:
    "appointments_agendada_despues_de_crearse" CHECK (scheduled_at >= created_at)
    "appointments_reason_longitud" CHECK (char_length(reason) <= 500)
    "appointments_reason_no_vacio" CHECK (char_length(btrim(reason)) > 0)
    "appointments_status_valido" CHECK (status = ANY (ARRAY['programada'::text, 'cancelada'::text]))
Restricciones de llave foránea:
    "appointments_user_id_fkey" FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
```

## Evidencia 5.2 — Privilegios de la aplicación acotados por columna

**Qué demuestra:** A nivel de tabla, `citasegura_app` **solo tiene `SELECT`**.
Todo lo demás está concedido por columna: `INSERT` únicamente en `user_id`,
`scheduled_at` y `reason`, y `UPDATE` únicamente en `status`, que es lo único
que exige cancelar. Por eso `id`, `status` y `created_at` los pone siempre la
base con su valor por defecto: la aplicación no puede elegir el identificador,
crear una cita ya cancelada ni fechar el registro en el pasado. Tampoco puede
borrar citas, vaciar la tabla ni borrar usuarios (este último permiso se
retiró en CITA-18; ver la nota de la evidencia 1.3).

**Comando**

```bash
psql -h 127.0.0.1 -U citasegura_app -d citasegura -c "
SELECT 'tabla' AS nivel, p AS privilegio,
       has_table_privilege('citasegura_app', 'appointments', p) AS concedido
FROM unnest(ARRAY['SELECT','INSERT','UPDATE','DELETE','TRUNCATE']) AS p
UNION ALL
SELECT 'columna ' || c, p,
       has_column_privilege('citasegura_app', 'appointments', c, p)
FROM unnest(ARRAY['id','user_id','scheduled_at','reason','status','created_at']) AS c,
     unnest(ARRAY['INSERT','UPDATE']) AS p
ORDER BY 1, 2;"

psql -h 127.0.0.1 -U citasegura_app -d citasegura -c "
SELECT has_table_privilege('citasegura_app','users','DELETE')          AS borrar_usuarios,
       has_table_privilege('citasegura_app','appointments','DELETE')   AS borrar_citas,
       has_table_privilege('citasegura_app','appointments','TRUNCATE') AS vaciar_citas;"
```

**Salida**

```
        nivel         | privilegio | concedido 
----------------------+------------+-----------
 columna created_at   | INSERT     | f
 columna created_at   | UPDATE     | f
 columna id           | INSERT     | f
 columna id           | UPDATE     | f
 columna reason       | INSERT     | t
 columna reason       | UPDATE     | f
 columna scheduled_at | INSERT     | t
 columna scheduled_at | UPDATE     | f
 columna status       | INSERT     | f
 columna status       | UPDATE     | t
 columna user_id      | INSERT     | t
 columna user_id      | UPDATE     | f
 tabla                | DELETE     | f
 tabla                | INSERT     | f
 tabla                | SELECT     | t
 tabla                | TRUNCATE   | f
 tabla                | UPDATE     | f
(17 filas)

 borrar_usuarios | borrar_citas | vaciar_citas 
-----------------+--------------+--------------
 f               | f            | f
(1 fila)
```

## Evidencia 5.3 — Corrección de los privilegios por defecto del esquema

**Qué demuestra:** Los privilegios por defecto (`ALTER DEFAULT PRIVILEGES`)
deciden con qué permisos nace cada tabla nueva. Esa regla no vive en
`db/roles.sql`, sino en el catálogo `pg_default_acl` de la base, y un
`GRANT` posterior solo añade permisos: no retira los anteriores. Una versión
antigua de `roles.sql` había fijado `SELECT, INSERT, UPDATE, DELETE`, y
corregir el fichero no cambió la base. El riesgo es silencioso: una tabla que
nace con permisos amplios los conserva sin que ningún script los muestre.
CITA-18 añade a `roles.sql` un `REVOKE ALL` seguido de `GRANT SELECT, INSERT`,
de modo que las tablas nuevas nazcan solo con lectura e inserción.

**Estado observado antes del cambio.** Al consultar `\ddp` como `postgres`
el 2026-10-08, antes de aplicar CITA-18, la regla para las tablas del esquema
`public` era:

```
citasegura_app=arwd/postgres
```

Las letras `w` (`UPDATE`) y `d` (`DELETE`) eran los permisos de más. Este
valor se anotó desde la terminal; la salida completa del comando no se guardó,
por lo que **no es una salida registrada**, sino el estado observado que
motivó la corrección.

**Estado después del cambio (salida registrada).** El 2026-10-08 no se pudo
capturar, porque falló la conexión como `postgres`. Se capturó el 2026-10-13,
con la base tal como la dejó CITA-18 (sin cambios de permisos entre ambas
fechas).

**Comando**

```bash
psql -h 127.0.0.1 -U postgres -d citasegura -X -c "\ddp"
```

**Salida** (`db/scripts-evidencias/salida-cita18-ddp.txt`)

```
                 Default access privileges
  Owner   | Schema |   Type   |     Access privileges      
----------+--------+----------+----------------------------
 postgres | public | sequence | citasegura_app=rU/postgres
 postgres | public | table    | citasegura_app=ar/postgres
(2 rows)
```

La regla de las tablas pasó de `arwd` a **`ar`**: `a` (`INSERT`) y `r`
(`SELECT`), sin `w` ni `d`. Una tabla nueva ya no nace con `UPDATE` ni
`DELETE`. La de secuencias, `rU`, es `SELECT` y `USAGE`, lo que concede
`roles.sql`. psql imprimió esta vez sus textos en inglés y no en español como
en el resto del bloque: depende de la configuración regional de la terminal
desde la que se ejecuta, no de la base.

`appointments` no depende de esta regla: fija sus permisos de forma explícita,
y la **evidencia 5.2** los comprueba sobre la tabla.

## Evidencia 5.4 — Doce operaciones rechazadas por la base, aunque el código las intente

**Qué demuestra:** Si un endpoint tuviera un bug o sufriera una inyección SQL,
la base seguiría rechazando lo que no debe ocurrir. Los intentos 4.1 a 4.4
chocan con las **restricciones de integridad** (`CHECK` y clave foránea); los
intentos 4.5 a 4.12 chocan con los **permisos**. En estos últimos PostgreSQL
informa «permiso denegado a la tabla …» también cuando lo que falta es un
permiso por columna: el mensaje nombra la tabla, no la columna.

**El detalle de la transacción en el intento 4.1.** La aplicación no puede
insertar una cita con un estado propio (no tiene `INSERT` sobre `status`), así
que para llegar al `CHECK` de estado hay que pasar por el único camino que sí
tiene: insertar una cita normal y luego intentar un `UPDATE` con un estado
inventado. En la salida aparece `INSERT 0 1` —el `INSERT` se ejecutó— y a
continuación el `ERROR` del `UPDATE`. Aun así **la fila no quedó**: psql envía
las dos sentencias de `-c` en una **única transacción**, y el error del
`UPDATE` la deshizo entera, `INSERT` incluido. El `DETALLE` del error muestra
además que el `id` y el `created_at` de esa fila los generó la base, no la
aplicación.

**Comando**

```bash
bash db/scripts-evidencias/evidencia-cita18.sh   # apartado 4
```

Cada intento ejecuta, como `citasegura_app`, la sentencia que indica su
título; el texto exacto de cada una está en el script.

**Salida**

```
  Las citas de prueba se cuelgan del usuario 36f9f865-123f-4e88-818c-a732d390e980

  4.1  Estado inventado: la base solo admite 'programada' y 'cancelada'
  ---------------------------------------------------------
  INSERT 0 1
  ERROR:  el nuevo registro para la relación «appointments» viola la restricción «check» «appointments_status_valido»
  DETALLE:  La fila que falla contiene (2670cf15-d128-4552-a82d-fef3240888da, 36f9f865-123f-4e88-818c-a732d390e980, 2026-10-10 22:34:26.466593-05, Control general, atendida, 2026-10-08 22:34:26.466593-05).

  4.2  Motivo vacio
  ---------------------------------------------------------
  ERROR:  el nuevo registro para la relación «appointments» viola la restricción «check» «appointments_reason_no_vacio»
  DETALLE:  La fila que falla contiene (a0c0ff5d-1ad7-4f7f-ba04-7f7e69dd424f, 36f9f865-123f-4e88-818c-a732d390e980, 2026-10-10 22:34:26.767236-05,    , programada, 2026-10-08 22:34:26.767236-05).

  4.3  Motivo que excede la longitud maxima
  ---------------------------------------------------------
  ERROR:  el nuevo registro para la relación «appointments» viola la restricción «check» «appointments_reason_longitud»
  DETALLE:  La fila que falla contiene (4d643522-2bc1-4ff8-8a72-d921ece322b0, 36f9f865-123f-4e88-818c-a732d390e980, 2026-10-10 22:34:26.948321-05, xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx..., programada, 2026-10-08 22:34:26.948321-05).

  4.4  Cita para un usuario que no existe
  ---------------------------------------------------------
  ERROR:  inserción o actualización en la tabla «appointments» viola la llave foránea «appointments_user_id_fkey»
  DETALLE:  La llave (user_id)=(759b13a7-699e-4f6f-8838-1f2671b36640) no está presente en la tabla «users».

  4.5  Elegir el identificador de la cita (no se puede: sin permiso en 'id')
  ---------------------------------------------------------
  ERROR:  permiso denegado a la tabla appointments

  4.6  Crear una cita que nazca ya cancelada (sin permiso en 'status')
  ---------------------------------------------------------
  ERROR:  permiso denegado a la tabla appointments

  4.7  Datar el registro en el pasado para saltarse el CHECK de fechas
  ---------------------------------------------------------
  ERROR:  permiso denegado a la tabla appointments

  4.8  Cambiar el dueño de una cita (sin permiso UPDATE en 'user_id')
  ---------------------------------------------------------
  ERROR:  permiso denegado a la tabla appointments

  4.9  Mover la fecha de una cita (sin permiso UPDATE en 'scheduled_at')
  ---------------------------------------------------------
  ERROR:  permiso denegado a la tabla appointments

  4.10 Borrar una cita
  ---------------------------------------------------------
  ERROR:  permiso denegado a la tabla appointments

  4.11 Vaciar la tabla de citas de golpe
  ---------------------------------------------------------
  ERROR:  permiso denegado a la tabla appointments

  4.12 Borrar un usuario (arrastraria sus citas en cascada)
  ---------------------------------------------------------
  ERROR:  permiso denegado a la tabla users
```

## Evidencia 5.5 — Las tres operaciones que la aplicación sí puede hacer

**Qué demuestra:** Los permisos acotados no impiden el uso legítimo. La
aplicación agenda una cita indicando solo dueño, fecha y motivo, y la base
completa el resto: el `id` aleatorio, el estado `programada` y la fecha de
creación con su propio reloj. La cita se puede consultar y cancelar, que es el
único cambio de estado que el alcance contempla.

**Comando**

```bash
bash db/scripts-evidencias/evidencia-cita18.sh   # apartado 5
```

**Salida**

```
  5.1  Agendar una cita: solo dueño, fecha y motivo
  ---------------------------------------------------------
                    id                  |   status   |          created_at           
  --------------------------------------+------------+-------------------------------
   3360b46d-1187-4a9a-972f-481c1fbefd7b | programada | 2026-10-08 22:34:29.077714-05
  (1 fila)
  
  INSERT 0 1

  5.2  Lo que quedo guardado
  ---------------------------------------------------------
  -[ RECORD 1 ]----+-------------------------------------
  identificador    | 3360b46d-1187-4a9a-972f-481c1fbefd7b
  fecha_de_la_cita | 2026-10-11 22:34:29.077714-05
  motivo           | Consulta de control
  estado           | programada
  creada           | 2026-10-08 22:34:29.077714-05
  

  5.3  Cancelar la cita (unico cambio de estado permitido)
  ---------------------------------------------------------
                    id                  |  status   
  --------------------------------------+-----------
   3360b46d-1187-4a9a-972f-481c1fbefd7b | cancelada
  (1 fila)
  
  UPDATE 1
```

## Limpieza de las citas de evidencia

La limpieza del paso 6 del script, que se ejecuta como `postgres` (es
mantenimiento, no una operación de la aplicación), falló al autenticarse. Esta
es su salida real:

```
psql: error: falló la conexión al servidor en «127.0.0.1», puerto 5432: FATAL:  la autentificación password falló para el usuario «postgres»
```

Por tanto, la cita de prueba `3360b46d-1187-4a9a-972f-481c1fbefd7b`
(«Consulta de control», cancelada) siguió en la base hasta el 13 de octubre.

**Limpieza completada el 2026-10-13**, como `postgres`. La cita colgaba de
`test@gmail.com`, la cuenta de pruebas principal, así que se borró **solo la
cita**, filtrando además por ese dueño para que el `DELETE` no pudiera alcanzar
nada más. Salida real:

```
DELETE FROM appointments
 WHERE id = '3360b46d-1187-4a9a-972f-481c1fbefd7b'
   AND user_id = (SELECT id FROM users WHERE email = 'test@gmail.com')
RETURNING id, status, reason;

                  id                  |  status   |       reason        
--------------------------------------+-----------+---------------------
 3360b46d-1187-4a9a-972f-481c1fbefd7b | cancelada | Consulta de control
(1 row)

DELETE 1
```

La cuenta `test@gmail.com` sigue en la base, sin citas.

---

# Bloque 6 — CITA-13: control de acceso y anti-IDOR

| | |
|---|---|
| **Generado** | 2026-10-15 20:50:43, en el equipo nuevo (base montada desde cero). La captura previa y la regresión de la 6.8 son del 14 de octubre |
| **Script** | `db/scripts-evidencias/evidencia-cita13.sh` |
| **Salida completa** | `db/scripts-evidencias/salida-cita13.txt` |
| **Captura previa al cambio** | `db/scripts-evidencias/salida-cita13-antes.txt` (21:50:02) |
| **Rol** | API con dos cuentas propias (A y B); `citasegura_app` para el hallazgo; `postgres` solo para leer lo que la API no muestra y para limpiar |

Los cuatro criterios de la tarjeta ya se cumplían desde CITA-12. CITA-13 es la
tarea de **verificarlos**, y una verificación de verdad busca lo que falla. Lo
que ya probó CITA-12 (401 sin sesión, listado filtrado por dueño, el mismo 404
para cita ajena, inexistente y con id mal formado) no se repite aquí.

La verificación encontró un fallo, el **hallazgo** de las evidencias 6.6 y 6.7.
La captura del estado vulnerable se hizo **antes** de corregirlo, para no
repetir lo de CITA-18, donde faltó la salida del «antes».

## Evidencia 6.1 — Ningún endpoint devuelve una cita por su identificador

**Qué demuestra:** El IDOR clásico es `GET /recurso/<id>` devolviendo el recurso
de otro. En CitaSegura esa ruta **no existe**: con la sesión de A, pedir la cita
de B por su id responde lo mismo que pedir un id inventado, con cualquier
método. No hay ningún dato de la cita en la respuesta.

**Salida**

```
  GET    /citas/<ajena>        -> HTTP 404 text/html; charset=utf-8
  PATCH  /citas/<ajena>        -> HTTP 404 text/html; charset=utf-8
  DELETE /citas/<ajena>        -> HTTP 404 text/html; charset=utf-8
  GET    /citas/<inexistente>  -> HTTP 404 text/html; charset=utf-8
  PATCH  /citas/<inexistente>  -> HTTP 404 text/html; charset=utf-8
  DELETE /citas/<inexistente>  -> HTTP 404 text/html; charset=utf-8
  GET    /citas/<ajena>/cancelar -> HTTP 405  (cancelar solo admite POST)

  ¿la respuesta a la ajena contiene algun dato que solo esta en la base?
    su motivo:                      0 coincidencias
    campos de cita (scheduledAt...): 0 coincidencias
  RESULTADO: ajena e inexistente reciben la MISMA pagina 404 (salvo la
             ruta pedida y los dos valores por peticion de Next):
             la ruta no existe, para ningun id
```

**Sobre la comparación.** La página 404 de Next no es idéntica byte a byte ni
siquiera entre dos peticiones a **la misma** URL. En modo desarrollo lleva una
marca de caché (`?v=<milisegundos>`) y un token aleatorio por petición
(`__next_r`), y además repite la ruta pedida, así que el id aparece en la
respuesta. Ese id lo escribió quien hizo la petición, no sale de la base. La
primera versión del script comparaba byte a byte y marcó «difieren». Al
investigarlo se vio que la diferencia eran solo esos tres valores, y ahora el
script los normaliza antes de comparar y busca datos que solo están en la base
(el motivo y los campos de una cita).

## Evidencia 6.2 — Cancelar una cita ajena no produce ningún cambio, comprobado en la base

**Qué demuestra:** CITA-12 mostró que el endpoint **responde** 404 a la cita
ajena. Aquí se comprueba que **no la toca**, leyendo la fila en la base antes y
después. La huella es el `md5` de la fila completa: si cambiara cualquier
columna (estado, fecha, motivo, dueño), cambiaría la huella.

**Salida**

```
  en la base, ANTES:   programada | a67af8bdf50aea66c893c86f01f729a7
  A cancela la cita de B -> HTTP 404  {"message":"Cita no encontrada."}
  en la base, DESPUES: programada | a67af8bdf50aea66c893c86f01f729a7
  RESULTADO: la fila de B esta INTACTA (mismo estado, misma huella)
```

## Evidencia 6.3 — Cita ajena e inexistente tardan lo mismo

**Qué demuestra:** Si la cita ajena tardara más que la inexistente, el tiempo
de respuesta delataría que existe, igual que en el login de CITA-9 y CITA-10.

**El argumento de peso es estructural, no la medida.** Los dos casos recorren
la misma consulta y el mismo camino de código: un `UPDATE` con
`WHERE id = $1 AND user_id = $2` que afecta a 0 filas, y después un `SELECT`
de propiedad que devuelve 0 filas. La cita ajena no tiene ninguna rama propia
en el código, ni trabajo extra que la delate: para la consulta, una cita de
otra persona y una que no existe son lo mismo.

**Salida del script** (tres intentos alternados, tras una petición de
calentamiento sin contar):

```
              ajena (de B)   inexistente
  intento 1       36.1 ms        29.1 ms
  intento 2       24.4 ms        44.3 ms
  intento 3       35.7 ms        60.3 ms
```

Los dos casos se solapan y **el orden se invierte entre intentos**: la ajena
es más lenta solo en el primero, y en el segundo y el tercero la más lenta es
la inexistente. Con estas medidas los dos casos no se distinguen.

**Un mismo caso varía más consigo mismo que respecto del otro.** La
inexistente va de 29,1 a 60,3 ms pidiendo exactamente lo mismo tres veces: 31,2
ms de variación. Es más de lo que la separa de la ajena en cualquiera de los
tres intentos (7,0, 19,9 y 24,6 ms). Cualquier señal que delatara la cita
ajena quedaría enterrada bajo esa variación.

**Alcance de la medida.** Tres intentos no demuestran que no exista un canal
por tiempo. Solo muestran que, si existe, queda por debajo de la variación
normal del servidor de desarrollo. Lo que sostiene la conclusión es el
argumento estructural de arriba; la medida solo comprueba que no lo
contradice.

## Evidencia 6.4 — Los identificadores de cita no son secuenciales

**Qué demuestra:** Con ids 1, 2, 3…, conocer una cita permite adivinar las
demás, que es la mitad de un ataque IDOR. Cinco citas creadas seguidas reciben
UUID versión 4 (122 bits aleatorios) sin ninguna relación entre sí.

**Salida**

```
    1  a6275530-71b3-4015-874c-9c3dc0561a60   (version 4)
    2  22938fbb-348b-4478-8fe1-749ede4f0b26   (version 4)
    3  75495853-bf31-4fd3-854d-9f751f006602   (version 4)
    4  f007d0a9-dad3-48d5-b0c0-87d762f8daf1   (version 4)
    5  6e0b65e3-44e5-40f2-9e0e-ff11d267316f   (version 4)
```

## Evidencia 6.5 — La comprobación de propiedad ocurre en la consulta a la base

**Qué demuestra:** El tercer criterio de la tarjeta se verifica en el código,
y su efecto ya lo demostraron las evidencias de CITA-12 (listado sin citas de
B y sin `user_id`) y la 6.2. El dueño va en el `WHERE` de cada consulta, junto
al id, y sale siempre de la sesión. Nunca se traen las filas para filtrarlas
después en JavaScript.

```sql
-- src/app/api/citas/route.ts:197 (listar)
SELECT ... FROM appointments WHERE user_id = $1 ORDER BY scheduled_at

-- src/app/api/citas/[id]/cancelar/route.ts:108-109 (cancelar)
UPDATE appointments SET status = 'cancelada'
 WHERE id = $1 AND user_id = $2 AND status = 'programada'
```

## Evidencia 6.6 — Hallazgo: la aplicación podía crear una cuenta de administrador

**Qué demuestra:** Al revisar los privilegios de `citasegura_app` apareció un
fallo. El `INSERT` sobre `users` era **de tabla completa**, así que el rol de
la aplicación podía escribir también `role`, `id`, `failed_attempts`,
`locked_until` y `created_at`. Lo único que impedía crear una cuenta `admin`
era el esquema Zod del registro (`z.strictObject`): **una sola barrera, y en el
código**. Una inyección SQL en cualquier endpoint, o un endpoint futuro que
olvidara el esquema, habría bastado.

Salida real, capturada **antes** de corregirlo, conectado como
`citasegura_app` (`rolsuper = f`). El hash es falso: solo tiene la forma que
exige el `CHECK` de bcrypt. Aquí se muestra acortado con `…`; completo, en el
fichero, son `$2b$12$` seguido de 53 `x`.

```
         alcance         | insert_concedido 
-------------------------+------------------
 tabla completa          | t
 columna id              | t
 columna name            | t
 columna email           | t
 columna password_hash   | t
 columna role            | t
 columna failed_attempts | t
 columna locked_until    | t
 columna created_at      | t
(9 rows)

INSERT INTO users (name, email, password_hash, role)
VALUES ('Hallazgo CITA-13', 'hallazgo.cita13.215002@ejemplo.com', '$2b$12$xxxx…xxxx', 'admin')
RETURNING id, email, role;
                  id                  |               email                | role  
--------------------------------------+------------------------------------+-------
 262ac19a-f019-47f6-9ed6-af832190c03d | hallazgo.cita13.215002@ejemplo.com | admin
(1 row)

INSERT 0 1
```

La cuenta se borró de inmediato como `postgres`, por su id y su correo exacto
(`DELETE 1`, y después 0 cuentas `admin`). La constancia está en el mismo
fichero.

## Evidencia 6.7 — Corrección: `INSERT` acotado por columna, y privilegios por defecto reducidos

**Qué demuestra:** En `db/roles.sql`, apartado 3.c, el `INSERT` se retira de
la tabla y se concede solo sobre las tres columnas que escribe el registro.
`role` lo pone siempre la base con su `DEFAULT 'user'`. Es la misma técnica que
CITA-18 aplicó a las citas.

Se corrigió además **la causa, no solo el síntoma**: los privilegios por
defecto de las tablas futuras también eran `SELECT, INSERT` de tabla completa,
así que la próxima tabla habría nacido con el mismo agujero. Ahora son solo
`SELECT`, y cada tabla concede su escritura, por columna, en su propio script.

**Catálogo después del cambio** (`roles.sql` se ejecutó dos veces seguidas, y
las dos terminaron con código 0):

```
                                      Access privileges
 Schema | Name  | Type  |     Access privileges      |      Column privileges      | Policies 
--------+-------+-------+----------------------------+-----------------------------+----------
 public | users | table | postgres=arwdDxtm/postgres+| name:                      +| 
        |       |       | citasegura_app=r/postgres  |   citasegura_app=a/postgres+| 
        |       |       |                            | email:                     +| 
        |       |       |                            |   citasegura_app=a/postgres+| 
        |       |       |                            | password_hash:             +| 
        |       |       |                            |   citasegura_app=a/postgres+| 
        |       |       |                            | failed_attempts:           +| 
        |       |       |                            |   citasegura_app=w/postgres+| 
        |       |       |                            | locked_until:              +| 
        |       |       |                            |   citasegura_app=w/postgres | 
(1 row)

                 Default access privileges
  Owner   | Schema |   Type   |     Access privileges      
----------+--------+----------+----------------------------
 postgres | public | sequence | citasegura_app=rU/postgres
 postgres | public | table    | citasegura_app=r/postgres
(2 rows)
```

`r` = `SELECT`, `a` = `INSERT`, `w` = `UPDATE`. En la tabla solo queda `r`.

**El mismo ataque después del cambio**, desde el script:

```
  El mismo ataque, como citasegura_app:
  ERROR:  permiso denegado a la tabla users
  Cuentas admin en la base: 0
```

Las demás columnas que el registro no escribe dan el mismo error. Se probó un
`INSERT` nombrando cada una:

```
  id               -> ERROR:  permiso denegado a la tabla users
  failed_attempts  -> ERROR:  permiso denegado a la tabla users
  locked_until     -> ERROR:  permiso denegado a la tabla users
  created_at       -> ERROR:  permiso denegado a la tabla users
```

## Evidencia 6.8 — El registro y el resto de la aplicación siguen funcionando

**Qué demuestra:** Acotar un permiso no puede romper lo que la aplicación sí
necesita.

```
registro:  {"message":"Si el correo no estaba registrado, la cuenta ha sido creada. Ya puedes iniciar sesion."} -> HTTP 201
                  id                  |                email                | role | failed_attempts | locked_until 
--------------------------------------+-------------------------------------+------+-----------------+--------------
 bf2a29d6-5a27-4387-9ff2-ea8a55660e46 | regresion.cita13.215123@ejemplo.com | user |               0 | 
(1 row)

login:     HTTP 200
me:        {"user":{"id":"bf2a29d6-5a27-4387-9ff2-ea8a55660e46","name":"Regresion Cita13","email":"regresion.cita13.215123@ejemplo.com","role":"user"},"expiresAt":"2026-10-15T10:51:23.966Z"} -> HTTP 200
login fallido (UPDATE de failed_attempts): HTTP 401
                email                | role | failed_attempts 
-------------------------------------+------+-----------------
 regresion.cita13.215123@ejemplo.com | user |               1
(1 row)
```

La fila nace con `role = user`, que pone el `DEFAULT`. El login crea su sesión,
y un login fallido sigue pudiendo escribir `failed_attempts`, que es el
`UPDATE` por columna de CITA-10.

Como regresión completa se volvió a ejecutar `evidencia-cita12.sh` después del
cambio. Todos los casos dieron lo mismo que antes, también la comprobación 2.10
de que los rechazos no dejan filas y la de los tres 404 idénticos.

## Limpieza

Todas las cuentas de este bloque se borraron como `postgres`, por id y correo
exacto: las dos del script, la de la regresión y las dos de la medición de
tiempos. Al terminar, la base quedó con `users=0 appointments=0 sessions=0`.

# Bloque 7 — CITA-14: validación y sanitización en el servidor

| | |
|---|---|
| **Generado** | 2026-10-15 21:21:46 |
| **Script** | `db/scripts-evidencias/evidencia-cita14.sh` |
| **Salida completa** | `db/scripts-evidencias/salida-cita14.txt` |
| **Rol** | API con dos cuentas propias (A, y N con un nombre que es código HTML); `citasegura_app` para el `INSERT` directo del 7.2; `postgres` solo para leer lo que la API no muestra y para limpiar |

Criterios de la tarjeta y dónde se demuestra cada uno:

| Criterio | Evidencia |
|---|---|
| Cada campo se valida en el servidor con el mismo esquema que usa el cliente | 7.1 |
| Se rechazan campos no declarados en el esquema | 7.1 |
| No se aceptan citas con fecha en el pasado | 7.2 |
| Los textos se almacenan tal cual se reciben y se escapan al mostrarse, sin ejecutar nada | 7.3 y 7.4 (el motivo en el panel, en el cierre de la 7.4) |

Lo que ya probó CITA-12 con `curl` no se repite: las claves `userId` y
`status`, la fecha pasada, el motivo de 501 caracteres, el motivo en blanco y
que los rechazos no dejan filas (`salida-cita12.txt`, casos 2.1 a 2.10). Los
`CHECK` de motivo vacío y de longitud, saltándose el esquema, están en la
evidencia 5.4.

## Evidencia 7.1 — La validación no depende del navegador

**Qué demuestra:** Peticiones con `curl` directamente a `POST /api/citas`, con
sesión válida y sin pasar por ningún formulario. El servidor vuelve a ejecutar
`crearCitaSchema`, el mismo esquema que usa el cliente
(`src/lib/validations/citas.ts`), así que saltarse el navegador no salta la
validación.

**Salida**

```
  falta el motivo              -> HTTP 400  {"message":"Los datos enviados no son validos.","errors":{"reason":["Indica el motivo de la cita."]}}
  motivo con tipo numero       -> HTTP 400  {"message":"Los datos enviados no son validos.","errors":{"reason":["Indica el motivo de la cita."]}}
```

Que falte el motivo y que llegue como número dan el mismo mensaje a
propósito: el mensaje de `z.string()` cubre los dos casos, como explica el
comentario del esquema.

**Claves no declaradas: la respuesta no sirve para sondear.** Se enviaron tres
claves sobrantes, cada una con un valor de sonda reconocible: `status`
(columna real de `appointments`), `role` (columna real de `users`) y `xyz` (no
existe en ninguna tabla).

```
  clave status                 -> HTTP 400  {"message":"Los datos enviados no son validos.","errors":{}}
  clave role                   -> HTTP 400  {"message":"Los datos enviados no son validos.","errors":{}}
  clave xyz                    -> HTTP 400  {"message":"Los datos enviados no son validos.","errors":{}}

  RESULTADO: las tres respuestas son IDENTICAS byte a byte
  claves o valores enviados presentes en las respuestas: 0
```

`z.strictObject` rechaza cualquier clave que el esquema no declare, **exista o
no como columna en la base**. Por eso las tres respuestas son idénticas byte a
byte, y el `"errors":{}` vacío es el **comportamiento buscado**, no un defecto:

- Quien sondea no puede distinguir una columna real de una inventada, porque
  las dos reciben lo mismo.
- La respuesta no devuelve nada de lo enviado: ni la clave ni su valor
  (0 apariciones).
- El formulario legítimo nunca envía claves de más, así que a un usuario real
  no le falta ninguna información.

(El mecanismo: Zod pone la clave sobrante en `formErrors`, y la ruta solo
devuelve `fieldErrors`.)

Ninguno de los cinco rechazos dejó fila, contado en la base:

```
  Citas de A en la base: antes 0, despues 0
  RESULTADO: ningun rechazo dejo fila
```

## Evidencia 7.2 — Fecha en el pasado: dos barreras independientes

**Qué demuestra:** La misma cita con fecha de ayer, por dos caminos. Por la API
la frena el esquema y no llega a la base. Saltándose el esquema, con el mismo
dato por SQL directo como `citasegura_app`, que tiene `INSERT` sobre esas tres
columnas, la frena el `CHECK appointments_agendada_despues_de_crearse`. Ese
`CHECK` compara con `created_at`, que pone la base con `now()` de su propio
reloj, y la aplicación no puede escribir `created_at` (evidencia 5.4, intento
4.7). Si la primera barrera fallara, por ejemplo con un endpoint nuevo que
olvide el esquema o con una inyección SQL, la segunda sigue ahí.

**Salida**

```
  Fecha de ayer: 2026-10-14T10:00:00-05:00

  a) Por la API: la frena el esquema
  cita con fecha de ayer       -> HTTP 400  {"message":"Los datos enviados no son validos.","errors":{"scheduledAt":["La cita debe ser en una fecha futura."]}}
     citas de A en la base: 0

  b) Saltandose el esquema: el mismo dato por SQL directo,
     como citasegura_app (permiso INSERT en las tres columnas)
     ERROR:  el nuevo registro para la relación «appointments» viola la restricción «check» «appointments_agendada_despues_de_crearse»
     DETAIL:  La fila que falla contiene (68e8d439-ac6b-448b-b48b-87df1f02d370, b6ccd78d-f47d-466f-8f67-faaae2520670, 2026-10-14 10:00:00-05, Cita en el pasado por SQL, programada, 2026-10-15 21:21:49.848051-05).
     citas de A en la base: 0
```

La fila que muestra el `DETAIL` nunca llegó a existir: el id lo generó el
`DEFAULT` antes de evaluar el `CHECK`, y el recuento sigue en 0.

## Evidencia 7.3 — El texto se guarda literal y viaja crudo en el JSON

**Qué demuestra:** Dos motivos con HTML ejecutable se guardan tal cual, sin
escapar ni filtrar, y el JSON de la API los entrega crudos. Es lo correcto.
Escapar le toca a quien pinta el dato, según el contexto en que lo pinta (HTML,
atributo, URL). Escapar al guardar estropearía el dato (un `&lt;` en la base)
y no protegería los demás contextos de salida. Es el mismo principio que la
consulta parametrizada de CITA-12: el dato se trata como dato, nunca como
código.

**Salida**

```
  3.1 Dos citas con HTML en el motivo
  motivo <script>              -> HTTP 201  {"message":"Cita creada.","cita":{"id":"928f9a56-1565-4459-b58f-c23bc2755656","scheduledAt":"2026-10-18T15:00:00.000Z","reason":"<script>alert(1)</script>","status":"programada","createdAt":"2026-10-16T02:21:50.025Z"}}
  motivo <img onerror>         -> HTTP 201  {"message":"Cita creada.","cita":{"id":"98f2d1c6-0c1e-41c1-986a-82d58f376d58","scheduledAt":"2026-10-18T15:00:00.000Z","reason":"<img src=x onerror=alert(1)>","status":"programada","createdAt":"2026-10-16T02:21:50.156Z"}}
  3.2 En la base, guardados LITERALES (sin escapar ni filtrar)
              reason            | identico_al_enviado 
  ------------------------------+---------------------
   <script>alert(1)</script>    | t
   <img src=x onerror=alert(1)> | t
  (2 rows)
  3.3 En el JSON de GET /api/citas: crudos, que es lo correcto
    content-type:           application/json
    x-content-type-options: (ausente)
    '<script>alert(1)</script>' crudo:      1
    '<img src=x onerror=alert(1)>' crudo:   1
    entidades HTML (&lt;):              0
  3.4 Nada en src/ inserta HTML sin escapar
    dangerouslySetInnerHTML: 0 usos
    innerHTML / outerHTML:   0 usos
```

El JSON viaja con `content-type: application/json`, que el navegador no
interpreta como HTML. Ningún archivo de `src/` usa `dangerouslySetInnerHTML`,
`innerHTML` ni `outerHTML`, las vías por las que se pintaría HTML sin
escapar.

**Observación:** la respuesta no lleva `X-Content-Type-Options: nosniff`, la
cabecera que prohíbe al navegador adivinar un tipo distinto del declarado. Los
navegadores actuales no tratan `application/json` como HTML, así que hoy no es
explotable. Queda como limitación 8.

## Evidencia 7.4 — El texto se escapa al mostrarse, en el renderizado del servidor

**Qué demuestra:** La cuenta N se registró con el nombre
`<script>alert(1)</script>`, y `/inicio`, un Server Component, lo pinta en el
saludo. React escapa el texto al generar el HTML: sale como `&lt;script&gt;`,
y en los datos de React incrustados en la página, como `\u003cscript\u003e`.
No aparece crudo en ningún punto, así que no se ejecuta.

**Salida**

```
  3.5 El nombre de N en el HTML de /inicio (Server Component)
    nombre guardado: <script>alert(1)</script>
    GET /inicio con la sesion de N -> HTTP 200
    '<script>alert(1)</script>' crudo:                0
    escapado como texto (&lt;script&gt;...):          1
    escapado en los datos de React (\u003cscript...): 1
    donde aparece, tal como llega al navegador:
      tracking-tight">Hola, <!-- -->&lt;script&gt;alert(1)&lt;/script&gt;</div><div
```

**Sobre el guion.** En la primera ejecución, la línea de los datos de React
contaba otra vez el texto crudo: al escribir el archivo, las secuencias
`\u003c` del patrón se habían convertido en `<`. Se detectó porque daba 0
cuando una consulta aparte de la página mostró que el nombre sí estaba en esos
datos, escapado. Se corrigió el patrón y se repitió la ejecución completa.
Ningún otro resultado cambió entre las dos ejecuciones.

**Alcance al escribir este bloque, el 15 de octubre: el criterio quedaba
cerrado a medias** (se cerró después; ver el apartado siguiente). El escape
está demostrado en el camino de renderizado del servidor, con el nombre del
usuario. El motivo de una cita, que es el texto al que se refiere el criterio,
todavía no se pinta en ninguna pantalla: el panel de citas es CITA-11 y no
está en el repositorio.
Es una **limitación de la evidencia, no un fallo del control**. Ninguna
pantalla puede pintar el motivo sin escapar, porque ninguna lo pinta, y la 7.3
deja establecido que en `src/` no hay ninguna vía para insertar HTML sin
escapar.

### Cierre del criterio: el motivo en el panel

Cuando se escribió este bloque, el escape estaba demostrado **en el camino de
renderizado del servidor**, con el nombre del usuario, pero el motivo de una
cita no se pintaba en ninguna pantalla: el panel era CITA-11 y todavía no
existía. El criterio quedó cerrado a medias y se dejó escrito así, como
limitación de la evidencia y no como fallo del control.

**Ya está cerrado.** Con el panel en marcha se agendó una cita cuyo motivo era
`<script>alert(1)</script>`, y aparece escrito tal cual con sus signos de menor
y mayor tanto en la lista como en la fila «Motivo» del detalle. No se ejecutó
nada: ninguna alerta, ninguna etiqueta abierta. El texto que la base guardó
literal (evidencia 7.3) llega a la pantalla convertido en caracteres visibles,
que es exactamente el reparto que describe este bloque: la base guarda, la
pantalla escapa.

*La captura del panel con ese motivo está en la página «2.4 Evidencias
Técnicas» de Notion, al final de la evidencia de CITA-14. No se ha copiado al
repositorio. Este texto es el mismo que el de esa página.*

## Limpieza

Las dos cuentas del script se borraron como `postgres`, por id y correo
exacto, y al terminar quedaron `cuentas=0 citas=0 sesiones=0`. Las de la
primera ejecución las borró esa misma ejecución. La cuenta de la consulta
aparte (`sonda.cita14.212027@ejemplo.com`) se borró igual (`DELETE 1`, 0
restantes).

---

# Bloque 8 — CITA-15: configuración segura del entorno

| | |
|---|---|
| **Generado** | 2026-10-16 17:28:04 |
| **Script** | `db/scripts-evidencias/evidencia-cita15.sh` |
| **Salida completa** | `db/scripts-evidencias/salida-cita15.txt` |
| **Rol** | Git y el sistema de archivos; un `next build` y un `next start` propios del guion en el puerto 3015; una cuenta por la API para ver `/inicio` con sesión; `postgres` solo para capturar el id de esa cuenta y borrarla |

La única credencial de la aplicación es la cadena de conexión de
`citasegura_app`, que lleva la contraseña de la base. Todo lo que protegen los
bloques 1 a 7 (los permisos por columna, el filtro por dueño, la falta de
`DELETE`) supone que esa contraseña no la tiene nadie más. Hay tres caminos
habituales por los que deja de ser así sin que nadie ataque nada: que el
archivo que la contiene acabe en el repositorio, que el valor viaje dentro del
JavaScript o del HTML que se descarga el navegador, o que la aplicación
arranque mal configurada y nadie lo note hasta que falla delante de un
usuario. Este bloque cierra los tres.

Criterios de la tarjeta y dónde se demuestra cada uno:

| Criterio | Evidencia |
|---|---|
| Los archivos de entorno están excluidos del control de versiones | 8.1 |
| Ninguna variable con secretos lleva el prefijo que la expone al navegador | 8.3 |
| Existe un archivo de ejemplo con los nombres de las variables y sin valores reales | 8.2 |
| La aplicación falla al arrancar si falta una variable obligatoria | 8.4 y 8.5 |

**Cómo maneja el guion la contraseña.** Es el guion del proyecto con más
riesgo de filtrarla, porque la usa a propósito. La lee de `.env.local` a una
variable del shell, se la pasa a `grep` por un descriptor de fichero (nunca
como argumento, para que no aparezca en la lista de procesos) e imprime
**solo el número de apariciones**. Toda la salida de Next.js pasa además por
un filtro que tapa cualquier cadena `postgresql://` y cuenta cuántas tapó: 0.
La salida guardada se revisó línea por línea antes de versionarla, y con
búsquedas que solo cuentan: la URL completa, la contraseña completa y 15
fragmentos de 8 caracteres de ella aparecen 0 veces, y no hay ninguna cadena
hexadecimal de 32 caracteres o más.

## Evidencia 8.1 — Los archivos de entorno están fuera de git, también en el historial

**Qué demuestra:** `.gitignore` excluye cualquier `.env*` con la regla que
trae Next.js, y la excepción `!.env.example`, añadida en CITA-15, deja pasar
solo el ejemplo. Esa excepción tiene que ir **después** de `.env*`, porque en
`.gitignore` gana la última regla que coincide. Pero ignorar un archivo hoy no
dice nada de ayer: si `.env.local` se hubiera commiteado alguna vez, la
contraseña seguiría en el historial aunque el archivo ya no esté, y habría que
cambiarla. Por eso se busca también ahí, en todas las ramas, y se busca el
**valor** además de los nombres de archivo.

**Salida**

```
--- 1.1 git check-ignore -v
  .env                     -> .gitignore:34:.env*
  .env.local               -> .gitignore:34:.env*
  .env.development         -> .gitignore:34:.env*
  .env.development.local   -> .gitignore:34:.env*
  .env.production          -> .gitignore:34:.env*
  .env.production.local    -> .gitignore:34:.env*
  .env.test                -> .gitignore:34:.env*
  .env.example             -> no ignorado (.gitignore:38:!.env.example)
  git status --ignored: ?? .env.example !! .env.local 
  (!! = ignorado, ?? = sin versionar pero NO ignorado)

--- 1.2 Archivos de entorno versionados (git ls-files)
  (ninguno)

--- 1.3 Historial completo, todas las ramas
  git log --all --full-history -- .env .env.local .env.development
          .env.development.local .env.production .env.production.local .env.test
  commits que tocan alguno: 0
  la contrasena actual en el historial (git log --all -p): 0
  la contrasena actual en los archivos versionados hoy:    0
```

La contraseña que se busca es la del equipo nuevo, creada el 14 de octubre. La
del equipo anterior se dio por expuesta porque salió en capturas de pantalla,
y por eso se cambió; no se puede buscar porque ya no existe en ningún sitio.

## Evidencia 8.2 — `.env.example` declara exactamente lo que la aplicación lee

**Qué demuestra:** el archivo de ejemplo tiene sentido solo si coincide con lo
que la aplicación necesita: uno al que le falta una variable deja a quien
monta el proyecto con un fallo que no sabe explicar, y uno que sobra confunde.
Se comparan tres listas: lo que declara `.env.example`, lo que valida el
esquema de `src/lib/env.ts` más cualquier `process.env.X` del código, y los
nombres de `.env.local`. Quedan fuera `NODE_ENV` y `NEXT_RUNTIME`, que pone
el propio Node.js o Next.js y no se configuran en ningún `.env`.

**Salida**

```
--- 3.2 Nombres: declarados frente a leidos
  declaradas en .env.example:          DATABASE_URL 
  claves del esquema (src/lib/env.ts): DATABASE_URL 
  process.env.X fuera del esquema:     (excluidas NODE_ENV y NEXT_RUNTIME)
  nombres en .env.local:               DATABASE_URL 
  RESULTADO: los tres conjuntos coinciden

--- 3.3 Valores del ejemplo
  DATABASE_URL=...
  contiene el marcador CAMBIAR_POR_LA_CONTRASENA:  1
  la contrasena real en .env.example:              0
```

El valor del ejemplo es `CAMBIAR_POR_LA_CONTRASENA`, un marcador que no puede
confundirse con una contraseña, ni siquiera con una de prueba. Además, la
aplicación lo rechaza si llega tal cual (evidencia 8.4, caso 4.2).

## Evidencia 8.3 — Ningún secreto llega al navegador

**Qué demuestra:** el criterio de la tarjeta habla del prefijo
`NEXT_PUBLIC_`, que hace que Next.js copie el valor de una variable dentro del
JavaScript del cliente. Se cuenta, y no hay ninguna. Pero **el prefijo no es la
única vía**: un Server Component puede leer el secreto en el servidor y
pasárselo como prop a un Client Component, y entonces viaja serializado dentro
del HTML de la página sin que ninguna variable lleve el prefijo. Por eso la
comprobación busca el **valor** (la URL de conexión completa y la contraseña
sola) en todo lo que el navegador recibe: los 15 `.js` de `.next/static` que
genera el build, y el HTML que el servidor devuelve para `/login`,
`/registro` e `/inicio`.

**`/inicio` se pidió con una sesión válida**, la de una cuenta registrada por
el propio guion, y respondió HTTP 200 con el panel dentro (la línea de
control cuenta el texto «Mis citas» en el HTML: 1). Es importante, porque
`/inicio` es la única de las tres páginas que el servidor genera con datos de
la base, y por tanto la única donde un secreto podría colarse en el HTML. Sin
sesión responde una redirección vacía a `/login`, y buscar un secreto ahí no
habría demostrado nada.

**Salida**

```
--- 2.1 pnpm build
  - Environments: .env.local
  ✓ Compiled successfully in 743ms
  ✓ Generating static pages using 14 workers (12/12) in 852ms
  codigo de salida: 0

--- 2.2 Variables con el prefijo NEXT_PUBLIC_
  declaradas en .env.local:     0
  declaradas en .env.example:   0
  leidas en src/ (process.env): 0

--- 2.3 El VALOR en el JavaScript que se descarga el navegador
  ficheros .js revisados en .next/static: 15
  URL de conexion:  0
  contrasena:       0

--- 2.4 El VALOR en el HTML servido
  registro de cuenta de prueba -> HTTP 201
  login -> HTTP 200
  /login    HTTP 200   20094 bytes   URL: 0   contrasena: 0
  /registro HTTP 200   22415 bytes   URL: 0   contrasena: 0
  /inicio   HTTP 200   24892 bytes   URL: 0   contrasena: 0
  control: /inicio lleva el panel (no una redireccion): 1

--- 2.5 Fuera del navegador: el build del servidor
  ficheros revisados en .next/server: 282
  URL de conexion:  0
  contrasena:       0
```

(Del 2.1 se han omitido las líneas intermedias del progreso del build; están
en la salida completa.)

La 2.5 es informativa. El servidor sí puede conocer el secreto, pero lo lee de
`.env.local` **al arrancar**: no queda escrito en ninguno de los 282 archivos
del build. Así, el directorio `.next` se puede copiar o inspeccionar sin que
lleve la contraseña dentro.

Además del recuento, hay una garantía en el código: `src/lib/env.ts`, el único
módulo que lee la configuración, empieza con `import "server-only"`. Si un
Client Component lo importara, directa o indirectamente, el **build fallaría**
en lugar de meter la cadena de conexión en el JavaScript del navegador.
`src/lib/db.ts` ya tenía desde su creación una guarda equivalente, que falla
en tiempo de ejecución si se evalúa en el navegador.

## Evidencia 8.4 — Sin una variable obligatoria, la aplicación no arranca

**Qué demuestra:** `src/lib/env.ts` valida el entorno con Zod en cuanto se
importa, y `src/instrumentation.ts` lo importa en `register()`, la función que
Next.js ejecuta una vez al arrancar el servidor y antes de atender ninguna
petición. Antes de CITA-15 la comprobación de `DATABASE_URL` vivía en
`db.ts`, que solo se evalúa cuando una ruta lo usa: el servidor arrancaba
igual sin la variable y fallaba con la primera petición que tocaba la base.

Se arrancó la aplicación (`next start`, sobre el build del 8.3) en tres
configuraciones rotas y una correcta. `.env.local` **nunca se tocó sin
respaldo**: se sacó su SHA-256, se copió fuera del repositorio, cada caso
escribió su propia versión, y al terminar se restauró y se comparó el hash.

**Salida**

```
--- 4.1 .env.local sin la linea DATABASE_URL (variable AUSENTE)
  codigo de salida: 1
  peticion a /login despues: HTTP 000
  mensaje:
    ▲ Next.js 16.3.6
    ✓ Ready in 178ms
    ✓ Running next.config.ts took 50ms
    Configuracion de entorno invalida. CitaSegura no arranca:
      - DATABASE_URL: falta. Definela en .env.local (ver .env.example).

--- 4.2 .env.local copiado de .env.example sin editar (marcador)
  codigo de salida: 1
  peticion a /login despues: HTTP 000
  mensaje:
    ▲ Next.js 16.3.6
    ✓ Ready in 192ms
    ✓ Running next.config.ts took 54ms
    Configuracion de entorno invalida. CitaSegura no arranca:
      - DATABASE_URL: conserva el marcador de .env.example. Sustituyelo por la contrasena real.

--- 4.3 DATABASE_URL con el superusuario postgres
  codigo de salida: 1
  peticion a /login despues: HTTP 000
  mensaje:
    ▲ Next.js 16.3.6
    ✓ Ready in 194ms
    ✓ Running next.config.ts took 56ms
    Configuracion de entorno invalida. CitaSegura no arranca:
      - DATABASE_URL: usa el superusuario postgres. La aplicacion debe conectarse como citasegura_app.

--- 4.4 Control: .env.local restaurado
  arranca y /login responde HTTP 200
```

```
  .env.local  hash antes:   28038c8902e1...  (primeros 12 de 64)
              hash despues: 28038c8902e1...
              RESULTADO: identico byte a byte
```

En los tres casos el proceso termina solo, con código 1, y el puerto queda
cerrado. El mensaje nombra la variable y el problema, y **nunca su valor**:
los errores de arranque acaban en consolas, en registros y en capturas de
pantalla, que es justo como se expuso la contraseña del equipo anterior. Por
la misma razón no se adjunta el error de Zod como causa, porque Node lo
imprimiría entero. (La línea «Ready» la escribe Next.js antes de ejecutar
`register()`; lo que importa es que el proceso termina sin servir nada.)

**Tres comprobaciones más allá del criterio.** El criterio pide fallar si
*falta* una variable. `env.ts` rechaza también tres configuraciones que están
presentes pero son peligrosas o están a medio hacer:

- **El usuario `postgres` (caso 4.3).** Es la más importante. Los bloques 1, 5
  y 6 demuestran lo que `citasegura_app` **no** puede hacer: no puede borrar
  usuarios ni citas, no puede escribir la columna `role` (el hallazgo de
  CITA-13, evidencias 6.6 y 6.7), no puede tocar `created_at`. Todo eso son
  `GRANT` y `REVOKE` sobre ese rol. Un superusuario se salta las comprobaciones
  de privilegios, así que si la aplicación se conectara como `postgres`
  **todos esos controles dejarían de existir a la vez**, sin que nada fallara:
  el registro, el login y las citas funcionarían igual. Es un error de
  configuración fácil de cometer «para probar» y difícil de ver después. Con
  esta comprobación, la regla de privilegios mínimos (convención 5 del
  proyecto) deja de depender de que alguien se acuerde: la aplicación no
  arranca como superusuario.
- **La cadena sin contraseña.** Sin contraseña, o la conexión falla con la
  primera consulta, lejos del arranque y con un error confuso, o funciona
  porque el servidor de base de datos acepta conexiones sin contraseña, que
  sería un problema mayor del que la aplicación no debe depender.
- **El marcador del ejemplo (caso 4.2).** Copiar `.env.example` a
  `.env.local` sin editarlo es el error más previsible de quien monta el
  proyecto. Sin esta comprobación, la aplicación arrancaría y fallaría con la
  primera consulta con un error de autenticación de PostgreSQL. Con ella, el
  mensaje dice exactamente qué falta hacer.

## Evidencia 8.5 — Hallazgo: un error al arrancar dejaba el proceso vivo

**Qué se encontró.** La primera versión de `register()` se limitaba a importar
`env.ts` y dejar que su error se propagara. Al probarla con `next start` sin `DATABASE_URL`, Next.js
registró el error («Failed to prepare server», con el mensaje de `env.ts`),
**pero el proceso no terminó**. El 16 de octubre se reprodujo a propósito,
devolviendo el código a esa versión, para ver qué hacía exactamente:

- A los 6 segundos y a los 40, el proceso seguía vivo.
- `netstat` mostraba el puerto 3015 en `LISTENING`.
- Cada petición recibía **HTTP 500** al momento (`/login` en 12 ms,
  `/api/auth/me` en 4 ms), y Next.js volvía a registrar «Failed to prepare
  server» con cada una.

Es decir: la aplicación **no estaba levantada, pero lo parecía**. Un sistema de
vigilancia que comprueba que el proceso existe, o que el puerto acepta
conexiones, lo habría dado por sano. Un balanceador de carga le habría seguido
enviando usuarios. El fallo solo se vería mirando el código de cada respuesta
o leyendo los registros, y eso es exactamente lo que este criterio quiere
evitar: que una mala configuración llegue a producción sin que nadie lo note
al desplegar.

**La corrección.** `register()` captura el error, imprime solo su mensaje y
termina el proceso con `process.exit(1)` (`src/lib/arranque.ts`). Eso es
negarse a arrancar de verdad: el proceso muere, el puerto se cierra, el código
de salida dice que algo fue mal, y cualquier herramienta que arranque la
aplicación (un `systemd`, un contenedor, un guion de despliegue) lo detecta
sin tener que interpretar nada. Los casos 4.1 a 4.3 son la versión corregida:
código 1 y ninguna petición atendida. Con el código corregido de nuevo, el
proceso había terminado antes de los 6 segundos y el puerto ya no estaba en
`LISTENING`.

`process.exit` no existe en el runtime edge de Next.js, y el compilador avisa
si lo encuentra en código que ese runtime podría cargar. Por eso vive en un
módulo aparte (`src/lib/arranque.ts`) que `register()` solo importa dentro de
`if (process.env.NEXT_RUNTIME === "nodejs")`, la forma que el compilador
reconoce para dejarlo fuera de edge. Con esa estructura el build no da
ningún aviso.

## Limpieza

La cuenta de prueba se borró como `postgres`, por id y correo exacto
(`DELETE 1`, y `cuentas=0 sesiones=0`). `.env.local` quedó idéntico byte a
byte, comprobado por su hash; las copias temporales se borraron, en la raíz
del repositorio solo quedan `.env.example` y `.env.local`, y el servidor del
guion quedó parado.

**Nota sobre `.env.example` y el commit.** En el momento de la captura,
`.env.example` todavía no estaba versionado: la salida lo muestra como no
ignorado (`??`) y `git add --dry-run .env.example` responde
`add '.env.example'`, es decir, que estaba listo para entrar en el commit. No
se vuelve a ejecutar el guion después del commit, porque esa nueva salida
exigiría otro commit, y así indefinidamente. La comprobación de que ya está
versionado se hace aparte, después del commit, con
`git ls-files .env.example`, que debe listarlo.

---

# Bloque 9 — CITA-12: API de citas parametrizada

| | |
|---|---|
| **Generado** | 2026-10-14 21:16:57, en el equipo nuevo. Redactado el 16 de octubre a partir de esa salida, sin volver a ejecutar el guion |
| **Script** | `db/scripts-evidencias/evidencia-cita12.sh` |
| **Salida completa** | `db/scripts-evidencias/salida-cita12.txt` |
| **Rol** | API con dos cuentas propias (A y B); `postgres` solo para capturar sus id, contar filas en la 9.5 y limpiar |
| **Vigencia de la captura** | Comprobada el 16 de octubre contra el código de ese día. Desde la captura, en las rutas de citas, en `db/appointments.sql` y en los esquemas de validación **solo cambiaron comentarios**. `src/lib/db.ts` toma ahora la cadena de conexión de `src/lib/env.ts` (CITA-15), validada al arrancar, pero es la misma conexión con el mismo rol. `db/roles.sql` acotó el `INSERT` sobre `users` a `name`, `email` y `password_hash` (evidencia 6.7), que son justo las columnas que escribe el registro de las cuentas de prueba. Nada de eso altera lo que esta salida demuestra |

La tarjeta es de **Lina**. Construye los tres endpoints de la aplicación:
`POST /api/citas` (crear), `GET /api/citas` (listar las propias) y
`POST /api/citas/[id]/cancelar`. Lo que cubre y dónde se demuestra:

| Lo que cubre la tarjeta | Evidencia |
|---|---|
| Sesión exigida antes que nada: 401 sin sesión, en las tres rutas | 9.1 |
| El dueño de una cita sale siempre de la sesión, nunca del cuerpo | 9.2, 9.3 |
| El esquema Zod `crearCitaSchema` se reejecuta en el servidor, con `z.strictObject` | 9.3, 9.4 |
| Consultas parametrizadas: un valor nunca se interpreta como SQL | 9.6 |
| El listado se filtra por dueño en la consulta, no en el código | 9.7 |
| El mismo 404 para una cita inexistente, ajena o con id mal formado | 9.8 |

Lo que CITA-13 verificó después sobre este mismo control (que cancelar una
cita ajena no cambia la fila, que no hay diferencia de tiempo, los UUID v4) y
lo que CITA-14 añadió (las claves `role` y `xyz`, el `CHECK` de fecha) están
en los bloques 6 y 7.

**Los JSON de las salidas están recortados por el guion**, no en este
documento: el guion muestra como mucho 200 caracteres de cada respuesta y
añade `...`. Las comprobaciones (recuentos, comparaciones, búsquedas) se hacen
sobre la respuesta completa. Las fechas del JSON van en UTC: la captura empezó
a las 21:16 del 14 de octubre en Colombia, que son las 02:16 del 15 en UTC.

## Evidencia 9.1 — Sin sesión no hay nada: 401 en las tres rutas

**Qué demuestra:** Ninguna ruta de citas atiende a un anónimo. La comprobación
de sesión es lo primero que hace cada ruta, antes incluso de mirar el formato
del cuerpo: en la 1.3 llega un cuerpo que no es JSON y la respuesta sigue
siendo 401, no el 415 que recibiría alguien con sesión (9.4). Así un anónimo
no puede usar el endpoint para averiguar qué formato espera ni qué reglas de
validación tiene. Sin cookie, `getSession()` no llega a consultar la base.

**Salida**

```
  1.1  Listar sin sesion
  ---------------------------------------------------------
  GET /citas -> HTTP 401
  {"message":"No autenticado."}

  1.2  Crear sin sesion, con un cuerpo valido
  ---------------------------------------------------------
  POST /citas -> HTTP 401
  {"message":"No autenticado."}

  1.3  Crear sin sesion y con un cuerpo basura: 401, no 415 (la sesion va primero)
  ---------------------------------------------------------
  POST /citas -> HTTP 401
  {"message":"No autenticado."}

  1.4  Cancelar sin sesion
  ---------------------------------------------------------
  POST /citas/11626df7-87ee-449e-bb2c-c341d4701a44/cancelar -> HTTP 401
  {"message":"No autenticado."}
```

## Evidencia 9.2 — Crear citas válidas

**Qué demuestra:** Con sesión, una cita válida se crea con `201`. El cuerpo
solo lleva fecha y motivo: el dueño lo pone la ruta a partir de la sesión,
como primer parámetro del `INSERT`, y la respuesta no lo devuelve. Además:

- **La hora exige zona horaria y se guarda en UTC.** La 1.5 envía las 10:00
  con `-05:00` y la base guarda las `15:00:00.000Z`: la misma hora, sin
  ambigüedad. Una hora sin zona se rechaza (9.4).
- **El motivo se recorta antes de guardarse** (1.6): llega rodeado de
  espacios y se guarda sin ellos.
- **El límite del esquema es el mismo que el del `CHECK`** (1.7): un motivo de
  exactamente 500 caracteres se acepta; el de 501 se rechaza en la 9.4.

La 1.8 crea la cita de B, que en la 9.7 y la 9.8 hace de cita **ajena** para A.

**Salida**

```
  1.5  A crea una cita valida (la hora viaja con zona -05:00 y se guarda en UTC)
  ---------------------------------------------------------
  POST /citas -> HTTP 201
  {"message":"Cita creada.","cita":{"id":"144b979f-49b2-47b7-bdaa-f90952e83f49","scheduledAt":"2026-10-17T15:00:00.000Z","reason":"Renovacion de documento","status":"programada","createdAt":"2026-10-15T...

  1.6  A crea otra con el motivo rodeado de espacios: se guarda recortado
  ---------------------------------------------------------
  POST /citas -> HTTP 201
  {"message":"Cita creada.","cita":{"id":"9d1d4681-fa42-48b5-be08-293b9da12dc0","scheduledAt":"2026-10-15T20:30:00.000Z","reason":"Consulta tributaria","status":"programada","createdAt":"2026-10-15T02:1...
  motivo guardado: [Consulta tributaria]

  1.7  A crea una con un motivo de EXACTAMENTE 500 caracteres (el limite del CHECK)
  ---------------------------------------------------------
  POST /citas -> HTTP 201
  {"message":"Cita creada.","cita":{"id":"496a9eb7-e4e5-4fc9-8b2f-271abea7d032","scheduledAt":"2026-10-19T14:00:00.000Z","reason":"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx...
  longitud del motivo guardado: 500

  1.8  B crea su propia cita (sera la cita AJENA para A)
  ---------------------------------------------------------
  POST /citas -> HTTP 201
  {"message":"Cita creada.","cita":{"id":"a30fb8ec-dc5b-44f5-a7e7-907301b4c0a0","scheduledAt":"2026-10-17T15:00:00.000Z","reason":"Cita de B","status":"programada","createdAt":"2026-10-15T02:17:00.106Z"...
```

## Evidencia 9.3 — Claves no declaradas: se rechaza el cuerpo entero

**Qué demuestra:** Es la defensa contra *mass assignment* de CITA-7, aplicada a
las citas. La 2.1 cuela un `userId` para crear la cita a nombre de otro; la
2.2, un `status` para que la cita nazca cancelada. El esquema declara
exactamente dos campos y usa `z.strictObject`, así que la clave sobrante no se
ignora: **el cuerpo entero se rechaza** con `400`. La 9.5 comprueba en la base
que ninguno de los dos dejó fila, tampoco a nombre de B.

**Por qué la respuesta lleva `"errors":{}` vacío.** No es para ocultar si la
columna existe: `z.strictObject` rechaza cualquier clave que el esquema no
declare, exista o no como columna en la base, así que no hay nada que ocultar.
La razón es que **la respuesta no sirve como sonda**: es la misma sea cual sea
la clave sobrante. Aquí, `userId` y `status` reciben el mismo texto. La
evidencia 7.1 lo lleva al límite con `status` (columna real de
`appointments`), `role` (columna real de `users`) y `xyz` (no existe en
ninguna tabla): las tres respuestas son idénticas byte a byte, así que
mandando claves no se averigua nada del esquema.

**Salida**

```
  2.1  Mass assignment: userId colado en el cuerpo (el dueño sale de la sesion)
  ---------------------------------------------------------
  POST /citas -> HTTP 400
  {"message":"Los datos enviados no son validos.","errors":{}}

  2.2  Mass assignment: status colado en el cuerpo (nacer ya cancelada)
  ---------------------------------------------------------
  POST /citas -> HTTP 400
  {"message":"Los datos enviados no son validos.","errors":{}}
```

## Evidencia 9.4 — Fecha, motivo y formato del cuerpo, validados en el servidor

**Qué demuestra:** Cada regla del esquema se aplica en el servidor y responde
con el mensaje del campo que falla: fecha en el pasado, fecha sin zona
horaria, motivo de 501 caracteres y motivo en blanco (el recorte va antes de
medir, así que solo espacios cuenta como vacío). Un envío que no es JSON
recibe `415` y un JSON mal formado, `400`, sin llegar al esquema. Que la
validación no depende del navegador está en la 7.1, y la segunda barrera de la
fecha pasada, el `CHECK` de la base, en la 7.2.

**Salida**

```
  2.3  Fecha en el pasado
  ---------------------------------------------------------
  POST /citas -> HTTP 400
  {"message":"Los datos enviados no son validos.","errors":{"scheduledAt":["La cita debe ser en una fecha futura."]}}

  2.4  Fecha sin zona horaria (ambigua)
  ---------------------------------------------------------
  POST /citas -> HTTP 400
  {"message":"Los datos enviados no son validos.","errors":{"scheduledAt":["Indica una fecha y hora validas, con zona horaria."]}}

  2.5  Motivo de 501 caracteres
  ---------------------------------------------------------
  POST /citas -> HTTP 400
  {"message":"Los datos enviados no son validos.","errors":{"reason":["El motivo no puede exceder 500 caracteres."]}}

  2.6  Motivo en blanco (solo espacios)
  ---------------------------------------------------------
  POST /citas -> HTTP 400
  {"message":"Los datos enviados no son validos.","errors":{"reason":["Indica el motivo de la cita."]}}

  2.7  Envio tipo formulario (no JSON)
  ---------------------------------------------------------
  POST /citas -> HTTP 415
  {"message":"Se esperaba un cuerpo JSON."}

  2.8  JSON mal formado
  ---------------------------------------------------------
  POST /citas -> HTTP 400
  {"message":"El cuerpo de la peticion no es JSON valido."}
```

## Evidencia 9.5 — Los rechazos no dejaron ninguna fila

**Qué demuestra:** Un `400` no basta: hay que comprobar que la petición
rechazada no escribió nada. La 2.9 lo mira por la API y la 2.10 en la base,
como `postgres`, contando las citas de **las dos** cuentas y el total de la
tabla antes de la 2.1 y después de la 2.8. Se cuentan las dos porque, si el
`userId` de la 2.1 hubiera funcionado, la cita habría aparecido a nombre de B,
y mirando solo las de A no se vería.

**Salida**

```
  2.9  Los rechazos no dejaron rastro: A sigue teniendo solo sus 3 citas
  ---------------------------------------------------------
  GET /citas -> HTTP 200
  {"citas":[{"id":"9d1d4681-fa42-48b5-be08-293b9da12dc0","scheduledAt":"2026-10-15T20:30:00.000Z","reason":"Consulta tributaria","status":"programada","createdAt":"2026-10-15T02:16:59.656Z"},{"id":"144b...
  citas de A: 3

  2.10 Los rechazos no dejaron NINGUNA fila, contado en la base
  ---------------------------------------------------------
                    citas de A   citas de B   total tabla
  antes de 2.1               3            1             4
  despues de 2.8             3            1             4
  RESULTADO: ninguna fila nueva, ni a nombre de A ni de B ni de nadie
```

## Evidencia 9.6 — Inyección SQL en el motivo: se guarda como texto

**Qué demuestra:** El motivo `x'); DELETE FROM appointments; --` está
construido para cerrar la sentencia del `INSERT` y ejecutar un borrado. La
cita se crea con normalidad y el motivo queda **guardado literalmente**: todo
el acceso a la base pasa por `query()` de `src/lib/db.ts` con marcadores
`$1, $2…`, así que el valor viaja separado de la sentencia y el motor nunca lo
interpreta como código. La 3.2 comprueba que la cita de B sigue ahí.

Aunque la inyección hubiera funcionado, el borrado habría fallado igual: la
aplicación no tiene permiso de `DELETE` sobre las citas (evidencia 5.4). Son
dos barreras independientes.

**Salida**

```
  3.1  Inyeccion SQL en el motivo: se guarda como texto, no se ejecuta
  ---------------------------------------------------------
  POST /citas -> HTTP 201
  {"message":"Cita creada.","cita":{"id":"4e1fa1ee-61bf-430f-9d16-4fadb40ab6a6","scheduledAt":"2026-10-19T14:00:00.000Z","reason":"x'); DELETE FROM appointments; --","status":"programada","createdAt":"2...
  motivo guardado: [x'); DELETE FROM appointments; --]

  3.2  La tabla sigue intacta: B conserva su cita
  ---------------------------------------------------------
  GET /citas -> HTTP 200
  {"citas":[{"id":"a30fb8ec-dc5b-44f5-a7e7-907301b4c0a0","scheduledAt":"2026-10-17T15:00:00.000Z","reason":"Cita de B","status":"programada","createdAt":"2026-10-15T02:17:00.106Z"}]}
```

## Evidencia 9.7 — El listado devuelve solo las citas propias

**Qué demuestra:** El `GET` de A devuelve sus cuatro citas, ordenadas por
fecha, y ninguna de B. El filtro va **en la consulta** (`WHERE user_id = $1`,
con el usuario de la sesión), no en el código después de traerlas: las filas
ajenas nunca salen de la base, así que un error en el código no puede
devolverlas. La respuesta tampoco lleva el identificador del dueño (0
coincidencias de `user_id` o `userId`): el cliente no lo necesita.

**Salida**

```
  3.3  Listado de A: solo sus citas, ordenadas por fecha
  ---------------------------------------------------------
  GET /citas -> HTTP 200
  {"citas":[{"id":"9d1d4681-fa42-48b5-be08-293b9da12dc0","scheduledAt":"2026-10-15T20:30:00.000Z","reason":"Consulta tributaria","status":"programada","createdAt":"2026-10-15T02:16:59.656Z"},{"id":"144b...
  citas de A, en el orden en que llegan:
    2026-10-15T20:30:00.000Z  programada  9d1d4681-fa42-48b5-be08-293b9da12dc0
    2026-10-17T15:00:00.000Z  programada  144b979f-49b2-47b7-bdaa-f90952e83f49
    2026-10-19T14:00:00.000Z  programada  496a9eb7-e4e5-4fc9-8b2f-271abea7d032
    2026-10-19T14:00:00.000Z  programada  4e1fa1ee-61bf-430f-9d16-4fadb40ab6a6
  ¿aparece la cita de B (a30fb8ec-dc5b-44f5-a7e7-907301b4c0a0)?   0 coincidencias
  ¿aparece algun user_id / userId?   0 coincidencias
```

## Evidencia 9.8 — Cancelar: la cita ajena, la inexistente y el id mal formado reciben el mismo 404

**Qué demuestra:** A cancela su propia cita (`200`), y cancelarla otra vez da
`409`. Ese 409 no delata nada, porque solo puede recibirlo el dueño: la
consulta que lo decide también filtra por dueño.

Después, A intenta cancelar la cita de B (existe, pero es ajena), un UUID que
no existe y un id basura (`1 OR 1=1`). Las tres respuestas son **idénticas,
código y cuerpo byte a byte**, comparadas por el guion. Si la ajena recibiera
un 403 y la inexistente un 404, el endpoint confirmaría que una cita existe y
es de otra persona. La ajena y la inexistente las resuelve la misma consulta,
con `AND user_id = $2` en el `WHERE`. El id mal formado ni siquiera llega a la
base: lo rechaza la validación del id antes, con la misma respuesta. La 4.6
comprueba por la API que la cita de B sigue programada. La comprobación en la
base, con la huella de la fila, y la medida de tiempos son las evidencias 6.2
y 6.3.

**Salida**

```
  4.1  A cancela su propia cita
  ---------------------------------------------------------
  POST /citas/144b979f-49b2-47b7-bdaa-f90952e83f49/cancelar -> HTTP 200
  {"message":"Cita cancelada.","cita":{"id":"144b979f-49b2-47b7-bdaa-f90952e83f49","status":"cancelada"}}

  4.2  A la cancela otra vez
  ---------------------------------------------------------
  POST /citas/144b979f-49b2-47b7-bdaa-f90952e83f49/cancelar -> HTTP 409
  {"message":"La cita ya estaba cancelada."}

  4.3  A intenta cancelar la cita de B (existe, pero es AJENA)
  ---------------------------------------------------------
  POST /citas/a30fb8ec-dc5b-44f5-a7e7-907301b4c0a0/cancelar -> HTTP 404
  {"message":"Cita no encontrada."}

  4.4  A intenta cancelar un UUID que NO EXISTE
  ---------------------------------------------------------
  POST /citas/11626df7-87ee-449e-bb2c-c341d4701a44/cancelar -> HTTP 404
  {"message":"Cita no encontrada."}

  4.5  A intenta cancelar con un id basura (1 OR 1=1)
  ---------------------------------------------------------
  POST /citas/1%20OR%201=1/cancelar -> HTTP 404
  {"message":"Cita no encontrada."}

  RESULTADO: las tres respuestas son IDENTICAS (codigo y cuerpo, byte a byte)

  4.6  La cita de B no se toco: sigue programada
  ---------------------------------------------------------
  GET /citas -> HTTP 200
  {"citas":[{"id":"a30fb8ec-dc5b-44f5-a7e7-907301b4c0a0","scheduledAt":"2026-10-17T15:00:00.000Z","reason":"Cita de B","status":"programada","createdAt":"2026-10-15T02:17:00.106Z"}]}
```

## Limpieza

Las dos cuentas de prueba se borraron como `postgres`, por su id; sus citas y
sesiones cayeron en cascada (`DELETE 2`, y `cuentas=0 citas=0 sesiones=0`).

```
                    id                  |               email                
  --------------------------------------+------------------------------------
   674827d3-c9aa-4fab-a5f0-d5482fcf56b4 | prueba.cita12.a.211656@ejemplo.com
   a6ec739e-bfe1-4e60-adc2-11ce77f40c2a | prueba.cita12.b.211656@ejemplo.com
  (2 filas)
  
  DELETE 2
  Comprobacion: no queda nada de las cuentas de prueba
   cuentas | citas | sesiones 
  ---------+-------+----------
         0 |     0 |        0
  (1 fila)
```

---

# Bloque 10 — CITA-19: vista de administrador

| | |
|---|---|
| **Generado** | 2026-10-19, en el equipo nuevo: `evidencia-cita19.sh` a las 21:57:16 y `evidencia-cita19-proxy.sh` a las 21:58:37 |
| **Scripts** | `db/scripts-evidencias/evidencia-cita19.sh` y `db/scripts-evidencias/evidencia-cita19-proxy.sh` |
| **Salida completa** | `db/scripts-evidencias/salida-cita19.txt` y `db/scripts-evidencias/salida-cita19-proxy.txt` |
| **Servidor** | **Build de producción** (`next build` + `next start`, puerto 3019), levantado y parado por el propio guion. No el de desarrollo: la prueba central compara byte a byte el 404 de `/admin` con el de una ruta inexistente, y en desarrollo Next.js añade a las respuestas cosas que en producción no están |
| **Rol** | API con dos cuentas propias: N (usuario normal) y A (administrador). `postgres` solo para promover a A, que es el único camino (10.1), para retirarle el rol (10.9), para leer el hash de N sin imprimirlo (10.3) y para limpiar |
| **Código medido** | El de CITA-19 **antes de su commit**: la cabecera de la salida registra el último commit y tres entradas sin commit en `src/` (`src/app/admin/`, `src/lib/auth/administrador.ts` y `src/app/inicio/item-cita.tsx`) |
| **PostgreSQL** | **18.6**. No lo registra la salida del guion: se consultó aparte, como `postgres`, contra el mismo servidor, unos doce minutos después (salida debajo) |

Comprobación suelta de la versión, el 19 de octubre, con
`psql -h 127.0.0.1 -U postgres -d citasegura -X -c "SHOW server_version;" -c "SELECT now();"`:

```
 server_version 
----------------
 18.6
(1 row)

              now              
-------------------------------
 2026-10-19 22:09:46.596115-05
(1 row)
```

La tarjeta es de **Dair**, con dos subtareas: CITA-20 (listado de todas las
citas) y CITA-21 (listado de usuarios registrados). La historia: *como
administrador, quiero consultar todas las citas y los usuarios registrados
del sistema, para supervisar la operación.*

| Criterio de aceptación | Evidencia | Resultado |
|---|---|---|
| 1. El administrador accede al listado completo de citas y al de usuarios | 10.2 | Cumplido |
| 2. De cada usuario: nombre, correo, rol y fecha de registro; nunca la contraseña almacenada ni los campos internos de bloqueo | 10.2, 10.3 | Cumplido; qué lo garantiza, en la limitación 9 |
| 3. Un usuario normal que intente entrar recibe el mismo trato que si la vista no existiera | 10.5, 10.6, 10.7, 10.8 | **Cumplido en el código HTTP y en los datos, no en el resto de la respuesta**: limitación 10 |
| 4. La comprobación del rol ocurre en el servidor, antes de generar la página | 10.5, 10.9 | Cumplido |
| 5. El administrador consulta, pero no crea ni cancela citas en nombre de otros ni modifica cuentas | 10.4 | Cumplido |
| 6. El rol se asigna directamente en la base; la aplicación no ofrece ninguna forma de cambiarlo | 10.1 | Cumplido desde CITA-13 |

**Cómo está construida.** Una sola ruta, `/admin`, que es un Server
Component. Citas y usuarios son dos pestañas en el cliente, no
`/admin/citas` y `/admin/usuarios`: sin denegación por defecto (limitación 7),
cada ruta nueva sería otro sitio donde olvidar la comprobación. Es el mismo
criterio que las pestañas de `/inicio` en CITA-11. La comprobación del rol
vive en **un solo módulo**, `src/lib/auth/administrador.ts`
(`exigirAdministrador()`), y las consultas en `src/app/admin/datos.ts`. Ese
módulo solo exporta `cargarVistaAdministrador()`, que **empieza** llamando a la
comprobación: no hay forma de pedir esos datos sin pasar por ella. Los datos
llegan a la página ya en el HTML, como props de un Client Component que no
hace ningún `fetch`. Así no hacen falta rutas de administrador bajo `/api`, y
la comprobación no hay que repetirla en ninguna.

## Evidencia 10.1 — El rol solo se asigna en la base, por cualquiera de sus dos caminos

**Qué demuestra:** El criterio 6 no requiere construir nada: se cumple desde
CITA-13. Una cuenta de administrador se puede conseguir por **dos caminos**, y
cada uno lo cierra una evidencia distinta:

- **Crearla ya como administrador** (`INSERT` con `role = 'admin'`). Lo cierra
  la **6.7**: `citasegura_app` solo tiene `INSERT` sobre `name`, `email` y
  `password_hash`, y el rol lo pone la base con su `DEFAULT 'user'`. La **6.6**
  es el hallazgo previo: hasta CITA-13 ese ataque funcionaba.
- **Promover una cuenta existente** (`UPDATE users SET role = 'admin'`). Lo
  cierra la **1.4**: el `UPDATE` de la aplicación está acotado a
  `failed_attempts` y `locked_until`, y ese ataque se rechaza con
  `permiso denegado a la tabla users`.

El guion consulta el catálogo el día de la prueba, y ninguno de los dos
permisos existe. Por eso la cuenta A se promueve **como `postgres`**: es el
único camino, y no pasa por la aplicación.

**Salida**

```
--- 0.4 A se promueve a administrador COMO POSTGRES (criterio 6)
  La aplicacion no tiene ninguna forma de hacerlo: citasegura_app no
  puede escribir la columna role (evidencias 1.4, 6.6 y 6.7).
                   email                | role  
    ------------------------------------+-------
     prueba.cita19.a.215711@ejemplo.com | admin
    (1 row)
    
    UPDATE 1
     app_insert_role | app_update_role 
    -----------------+-----------------
     f               | f
    (1 row)
```

## Evidencia 10.2 — El administrador ve las dos listas

**Qué demuestra:** Con la sesión de A, `/admin` responde `200` y el HTML trae
las dos pestañas con contenido, no un `200` vacío. La pestaña inactiva solo se
oculta, así que las dos van siempre en el HTML. Cada pestaña tiene su línea de
control:

- **Citas:** el motivo de la cita que N agendó por la API.
- **Usuarios:** los correos de las dos cuentas.

Las cifras son 2 y 4 por cómo Next.js construye la página. Un dato que el
servidor pasa como prop a un Client Component sale dos veces: en el HTML
renderizado y en la carga útil con la que React hidrata la página. El motivo
va en una prop (2). El correo de N va en dos, como titular de su cita y en la
lista de usuarios (4). El de A va en la lista de usuarios y en la cabecera de
la página, que muestra la cuenta con la que se entró (4). Los títulos de
pestaña son texto del propio componente y salen una vez. Que los datos viajen
en el HTML es lo que obliga a la 10.3.

**Refuerzo de la 7.4, no una evidencia nueva:** entre las citas que ve el
administrador está la de motivo `<script>alert(1)</script>`, creada el 16 de
octubre para cerrar la 7.4, y se muestra como texto, sin ejecutarse. Esta
pantalla no existía cuando se evidenció CITA-14, así que el escape queda
verificado también en la vista nueva. Lo comprobó Dair en el navegador el 19
de octubre.

**Salida**

```
  GET /admin con la sesion de A -> HTTP 200   23730 bytes
  Pestana Citas:
    "Todas las citas":     1
    motivo de control:     2
  Pestana Usuarios:
    "Usuarios registrados": 1
    correo de N:           4
    correo de A:           4
```

## Evidencia 10.3 — Ni el hash ni los campos de bloqueo salen de la base

**Qué demuestra:** En el HTML que recibe el administrador no aparece el
prefijo de bcrypt, ni el hash completo de N, ni los nombres de las columnas
internas. El hash se leyó como `postgres` y se buscó sin imprimirlo. Tampoco
aparece el id de N: la vista no recibe identificadores, porque no tiene
ninguna acción que los necesite.

La segunda parte mira el código. Las consultas de la vista nombran sus
columnas una a una, sin `SELECT *`. El recuento descarta las líneas de
comentario (las que empiezan por `//`, `/*` o `*`) e imprime cuántas descarta.
La que descarta es justo el comentario «Nada de SELECT \*» de `datos.ts`, que
sin ese filtro daría un falso positivo.

**Qué lo garantiza, con precisión:** **no es un permiso.** `citasegura_app`
tiene `SELECT` sobre `password_hash`, `failed_attempts` y `locked_until`,
porque el login los necesita. Lo único que impide que salgan es que la consulta
no los pida. Si se trajeran al servidor «porque no se muestran», bastaría un
descuido al construir las props para que viajaran serializados en el HTML, la
misma vía que la 8.3 vigila para los secretos. Es la **limitación 9**.

**Salida**

```
  prefijo bcrypt $2b$:              0
  hash completo de N:                0
  nombre de campo password_hash:     0
  nombre de campo failed_attempts:   0
  nombre de campo locked_until:      0
  id de N (las cuentas no llevan id): 0

  En el codigo de la vista (src/app/admin src/lib/auth/administrador.ts), fuera de comentarios:
    SELECT *:                                       0   (en comentarios, descartadas: 1)
    password_hash, failed_attempts o locked_until:  0   (en comentarios, descartadas: 3)
```

## Evidencia 10.4 — El administrador solo consulta

**Qué demuestra:** El criterio 5 no se defiende comprobando permisos al
escribir, sino con que **no exista el código que escribe**. Bajo `/api` solo
están las seis rutas de las tarjetas anteriores, y ninguna es de
administrador ni llama a `exigirAdministrador()`. El código de la vista no
tiene ningún `INSERT`, `UPDATE` ni `DELETE`, ni ningún `fetch`. Un `POST` a
`/api/admin`, con la sesión del administrador, da 404: la ruta no existe.

`exigirAdministrador()` se llama en un solo sitio, `datos.ts`. La
comprobación de rol no está repetida, que es lo que permite auditarla.

**Salida**

```
  Rutas bajo src/app/api y sus metodos:
    /api/auth/login/route.ts                   POST 
    /api/auth/logout/route.ts                  POST 
    /api/auth/me/route.ts                      GET 
    /api/auth/register/route.ts                POST 
    /api/citas/[id]/cancelar/route.ts          POST 
    /api/citas/route.ts                        POST GET 
  Rutas de administrador bajo /api (ruta con "admin"):   0
  Rutas bajo /api que llaman a exigirAdministrador():  0
  INSERT/UPDATE/DELETE en el codigo de la vista:         0
  fetch( en el codigo de la vista:                       0
  Llamadas a exigirAdministrador() en todo src/:         1  (src/app/admin/datos.ts )
  POST /api/admin con la sesion de A -> HTTP 404
```

## Evidencia 10.5 — Sin rol, un 404 y ningún dato de la vista

**Qué demuestra:** La parte de los criterios 3 y 4 que **sí** se cumple. El
anónimo y el usuario normal con sesión reciben un **404, el mismo código** que
una ruta inexistente: no un 403, ni un «no autorizado», ni una redirección a
`/inicio`. Las tres alternativas anunciarían en la línea de estado que la
ruta existe y que hay algo detrás.

Y en ninguna de las dos respuestas hay un solo dato de la vista: ni correos,
ni el motivo de control, ni los títulos de las pestañas. Es lo que pide el
criterio 4. `exigirAdministrador()` llama a `notFound()` antes que nada;
`notFound()` lanza una excepción que corta el renderizado, y las consultas de
`datos.ts` van después, así que ni siquiera llegan a ejecutarse.

**Salida** (con `...` se omiten las comparaciones de cuerpo y cabeceras, que
son la 10.6)

```
 1. ANONIMO -> /admin, frente a una ruta inventada (criterio 3)
  GET /admin                         HTTP 404   6505 bytes
  GET /ruta-inventada-215711         HTTP 404   8398 bytes
  ...
  Datos de la vista en la respuesta de /admin:
    correo de N: 0   motivo de control: 0   "Todas las citas": 0

 2. USUARIO NORMAL CON SESION -> /admin, frente a la inventada
  GET /admin                         HTTP 404   6505 bytes
  GET /ruta-inventada-215711         HTTP 404   8398 bytes
  ...
  Datos de la vista en la respuesta de N a /admin:
    correo de A: 0   motivo de control: 0   "Usuarios registrados": 0
```

## Evidencia 10.6 — Hallazgo: el código coincide; el cuerpo y las cabeceras, no

**Qué demuestra:** El criterio 3 pide **el mismo trato** que una ruta que no
existe, y eso es más que el mismo código. Se implementó de la forma evidente,
llamando a `notFound()` desde la página. Al medirlo en producción, **el
código HTTP sí coincide (404), pero el cuerpo y las cabeceras no**, y lo que
difiere delata que `/admin` existe:

- **El cuerpo.** El de una ruta inexistente es la página 404 que Next.js
  **prerenderiza** en el build (8398 bytes). El de `/admin` se genera **al
  vuelo** (6505 bytes): un esqueleto `<html id="__next_error__">` cuya carga
  útil RSC, la que viaja dentro del HTML, nombra el segmento de la ruta,
  `"c":["","admin"]`, frente a `"_not-found"`. Lleva además la marca del
  error lanzado, `NEXT_HTTP_ERROR_FALLBACK;404`.
- **Las cabeceras.** La 404 prerenderizada sale de la caché, con
  `x-nextjs-cache: HIT`, `x-nextjs-prerender`, `x-nextjs-stale-time`, `ETag` y
  `Content-Length`. La de `/admin` sale por trozos (`Transfer-Encoding:
  chunked`) y con una cabecera `Link` que precarga las fuentes.

**Por qué no es lo mismo que un 403, y la diferencia importa.** Un 403
proclama en la línea de estado que el recurso existe y que se deniega el
acceso. Cualquier cliente, escáner o herramienta lo lee sin esfuerzo, y es un
estándar. Aquí la línea de estado dice «no existe». Para notar la diferencia
hay que guardar una 404 de referencia, comparar las dos respuestas enteras y
saber reconocer las marcas internas de Next.js. Es una fuga de existencia de
la ruta, real y documentada, pero de otro orden que una denegación explícita.
**No filtra ningún dato** (10.5).

Es la **limitación 10**.

**En pantalla no se nota.** Comprobado en el navegador por Dair el 19 de
octubre, con captura: la página que ve un usuario normal en `/admin` y la de
una ruta inventada (`/loquesea`) son idénticas, la 404 por defecto de
Next.js. Lo único que cambia es la URL de la barra. Eso **refuerza** la
limitación en vez de debilitarla: la fuga existe y es real, pero no se ve en
pantalla, solo comparando las respuestas enteras.

**Salida**

```
  GET /admin                         HTTP 404   6505 bytes
  GET /ruta-inventada-215711         HTTP 404   8398 bytes
  cuerpo:     DISTINTO (byte 22, line 1)
  cabeceras:  DISTINTAS (sin Date). < solo en /admin, > solo en la inventada:
    > Cache-Control: private, no-cache, no-store, max-age=0, must-revalidate
    < Link: </_next/static/media/797e433ab948586e-s.p.0r6juujl39pe6.woff2>; rel=preload; as="font"; crossorigin=""; type="font/woff2", </_next/static/medi
    > x-nextjs-cache: HIT
    > x-nextjs-prerender: 1
    > x-nextjs-prerender: 1
    > x-nextjs-stale-time: 300
    < Cache-Control: private, no-cache, no-store, max-age=0, must-revalidate
    > ETag: "inbax38aqq6ha"
    > Content-Length: 8398
    < Transfer-Encoding: chunked
  Que delata la ruta dentro del cuerpo (apariciones):
                                                         /admin  inventada
    id="__next_error__"                                    1    0
    \"c\":[\"\",\"admin\"]                                 1    0
    \"c\":[\"\",\"_not-found\"]                            0    1
    NEXT_HTTP_ERROR_FALLBACK;404                           1    0
    This page could not be found.                          2    6
```

`Cache-Control` aparece en las dos respuestas con el mismo valor: `diff` lo
marca porque está en otra posición.

## Evidencia 10.7 — La reescritura en el Proxy: cuerpo idéntico, y una cabecera que Next.js pone siempre

**Qué demuestra:** Que la limitación 10 es **un límite medido del framework,
no una renuncia**. Se probó la alternativa: un Proxy (el middleware de
Next.js 16), con el matcher acotado a `/admin`, que reescribe la petición hacia
una ruta inexistente. Así Next.js sirve exactamente la 404 prerenderizada.

El Proxy del guion reescribe **siempre**, sin mirar la sesión. Es el caso más
favorable posible: uno real tendría además que validar la sesión, pero ante
quien no es administrador haría esta misma reescritura. El resultado:

- **El cuerpo sale idéntico byte a byte** (8398 bytes los dos).
- **Las cabeceras, idénticas salvo una**: `x-middleware-rewrite: /__no-existe`,
  que solo lleva `/admin`.

Esa cabecera no se puede quitar. Las líneas 466 a 469 de
`node_modules/next/dist/server/lib/router-utils/resolve-routes.js` (Next.js
16.3.6) muestran que la **misma** cabecera hace dos cosas. Es la instrucción
con que el Proxy le pide a Next.js la reescritura, y Next.js la copia tal cual
a la respuesta (`resHeaders`). La única condición es que haya reescritura: en
ese código no hay ninguna opción de configuración que lo evite. Borrar la
cabecera desde el propio Proxy no se probó, porque según esas mismas líneas
sería borrar la orden de reescribir. El guion crea
`src/proxy.ts` solo para la medida y lo borra al terminar; el código entregado
no tiene Proxy.

**Salida** (`salida-cita19-proxy.txt`)

```
--- src/proxy.ts (temporal)
  | import { NextResponse, type NextRequest } from "next/server";
  | 
  | // Experimento de evidencia-cita19-proxy.sh: reescribe SIEMPRE.
  | export function proxy(request: NextRequest) {
  |   return NextResponse.rewrite(new URL("/__no-existe", request.url));
  | }
  | 
  | export const config = {
  |   matcher: "/admin",
  | };

  GET /admin                         HTTP 404   8398 bytes
  GET /ruta-inventada-215832         HTTP 404   8398 bytes
  cuerpo:     IDENTICO byte a byte
  cabeceras:  DISTINTAS (sin Date). < solo en /admin, > solo en la inventada:
    < x-middleware-rewrite: /__no-existe

  node_modules/next/dist/server/lib/router-utils/resolve-routes.js, lineas 466 a 469:
    if (middlewareHeaders['x-middleware-rewrite']) {
    const value = middlewareHeaders['x-middleware-rewrite'];
    const destination = (0, _relativizeurl.getRelativeURL)(value, initUrl);
    resHeaders['x-middleware-rewrite'] = destination;

  src/proxy.ts borrado: si
```

## Evidencia 10.8 — Con cookie y sin ella: el mismo contenido en otro orden, y por qué no es un oráculo nuevo

**Qué demuestra:** La respuesta de `/admin` al usuario normal con sesión no es
idéntica byte a byte a la del anónimo. Tiene el **mismo tamaño, el mismo HTML
y los mismos trozos de carga útil RSC**, pero uno de ellos, el del error,
llega en otra posición del flujo. Las cabeceras son idénticas. Cada respuesta
es estable: repetida, sale igual a sí misma.

**La causa.** Con una cookie, `getSession()` consulta la base antes de que se
llegue a `notFound()`. Sin cookie, ni consulta: devuelve `null` al instante.
Ese retraso cambia el punto del flujo en que sale el trozo del error.

**Qué distingue esa diferencia, medido:** con un token **inventado** del
mismo formato, la respuesta es **idéntica byte a byte a la de una cookie
válida** y distinta de la del anónimo. Así que `/admin` no distingue una
cookie válida de una inválida. Solo distingue si la petición **llevaba**
cookie o no, y eso lo sabe ya quien la envía.

**Por qué no es una exposición nueva.** Distinguir «cookie válida» de «sin
cookie» ya se puede hacer, **por diseño**, en cualquier ruta protegida del
proyecto desde CITA-9. `GET /api/auth/me` responde 200 a una sesión válida y
401 a su ausencia, en esta misma salida y en la evidencia 3.3. `/inicio`
redirige a `/login` si no hay sesión. Una ruta protegida tiene que tratar
distinto a quien tiene sesión y a quien no; para eso existe. `/admin` no
revela nada que esas rutas no revelen ya, y menos todavía: ni siquiera si la
cookie es válida. **Sería otra cosa si `/admin` distinguiera algo que ninguna
otra ruta distingue**, por ejemplo una cuenta de administrador de una normal
en su respuesta a terceros. Ahí habría un oráculo nuevo, y no lo hay: la 10.9
muestra que una cuenta sin rol recibe exactamente la misma respuesta que
cualquier otra sesión válida sin rol.

**Salida**

```
  N en /admin frente al anonimo en /admin:
    cuerpo: DISTINTO (byte 5870, line 1)
      mismo tamaño:                       si
      mismo HTML fuera de los <script>:   si
      mismos trozos RSC, sin mirar orden: si
    cabeceras: IDENTICAS (sin Date)
  Repetida la peticion de N: cuerpo IDENTICO a la primera
  Repetida la del anonimo:   cuerpo IDENTICO a la primera
  Control del oraculo de CITA-9: /api/auth/me sin cookie -> HTTP 401, con la cookie de N -> HTTP 200
  Cookie con un token inventado (43 caracteres) -> /admin HTTP 404:
    cuerpo frente al de N (cookie valida): IDENTICO byte a byte
    cuerpo frente al anonimo (sin cookie):  DISTINTO
    /api/auth/me con ese token -> HTTP 401
```

## Evidencia 10.9 — El rol se lee de la base en cada petición: una cuenta degradada pierde el acceso al instante

**Qué demuestra:** Se le retira el rol a A **como `postgres`**, sin cerrar su
sesión: su fila en `sessions` sigue ahí. Con la **misma cookie** que un
momento antes le abría la vista (10.2), la siguiente petición a `/admin` da
404, idéntico byte a byte al de N, y sin ningún dato de la vista.

Funciona porque el rol **no viaja en la cookie**. La cookie es un
identificador opaco (bloque 3), y `getSession()` hace en cada petición el
`JOIN` con `users` y lee el rol de la base en ese momento. No hay nada en el
cliente que se pueda editar para hacerse pasar por administrador, ni ninguna
copia del rol que tenga que caducar. Con un token autocontenido que
llevara el rol (un JWT), A seguiría entrando hasta que el token caducara. Es
el mismo argumento por el que la 3.4 puede revocar una sesión y un JWT no.

**Salida**

```
                   email                | role 
    ------------------------------------+------
     prueba.cita19.a.215711@ejemplo.com | user
    (1 row)
    
    UPDATE 1
  sesiones de A en la base: 1
  GET /admin con la misma cookie de A -> HTTP 404
  cuerpo frente al de N: IDENTICO byte a byte
  motivo de control: 0   correo de N: 0
```

## Limpieza

Las dos cuentas se borraron como `postgres`, por su id y su correo exacto. Sus
citas y sesiones cayeron en cascada, y no queda ni la cita de control. El
servidor del guion quedó parado.

```
  Cuentas de prueba, por id y correo exacto:
                   email                
    ------------------------------------
     prueba.cita19.a.215711@ejemplo.com
     prueba.cita19.n.215711@ejemplo.com
    (2 rows)
    
    DELETE 2
  Comprobacion: no queda rastro
     cuentas | citas | sesiones | cita_de_control 
    ---------+-------+----------+-----------------
           0 |     0 |        0 |               0
    (1 row)
    
  Temporales borrados: si
  Servidor del guion en el puerto 3019: parado
```

---

# Bloque 11 — CITA-16: cabeceras de seguridad HTTP

| | |
|---|---|
| **Generado** | 2026-10-20, en el equipo nuevo: `evidencia-cita16-cabeceras.sh antes` a las 09:41:31, `evidencia-cita16-cabeceras.sh despues` a las 09:50:48 y `evidencia-cita16-proxy.sh` a las 20:22:24 |
| **Scripts** | `db/scripts-evidencias/evidencia-cita16-cabeceras.sh` (con el argumento `antes` o `despues`) y `db/scripts-evidencias/evidencia-cita16-proxy.sh` |
| **Salida completa** | `db/scripts-evidencias/salida-cita16-cabeceras-antes.txt`, `db/scripts-evidencias/salida-cita16-cabeceras.txt` y `db/scripts-evidencias/salida-cita16-proxy.txt` |
| **Servidor** | **Build de producción** (`next build` + `next start`, puerto 3016), levantado y parado por cada guion. No el de desarrollo, que añade a las respuestas cosas que en producción no están: la limitación 8 se había medido el 15 de octubre en desarrollo, y esa medida no valía como «antes» |
| **Rol** | API con dos cuentas propias: N (usuario normal) y A (administrador, promovida como `postgres`, el único camino: 10.1). `postgres` solo para promover a A y para limpiar |
| **Código medido** | El «antes», el último commit sin cambios (`next.config.ts` sin modificar: 0 en la cabecera de la salida). El «después» y el Proxy, con el cambio de `next.config.ts` **antes de su commit** (1 en la cabecera) |
| **PostgreSQL** | No consta: ninguna de las tres salidas registra la versión. El bloque solo usa la base para crear y borrar sus cuentas de prueba |

Es la primera parte de CITA-16 (re-test de seguridad): cierra lo que se
pueda cerrar de la **limitación 8**. **El resto de la tarjeta no está en este
bloque, y queda pendiente dentro de CITA-16:** el re-test de las clases de
vulnerabilidad y los guiones del Sprint 1 que hoy no se pueden ejecutar tal
cual (README de `db/scripts-evidencias/`).

Las siete rutas medidas, las mismas en las tres salidas: `/`, `/login`,
`/inicio` con la sesión de N, `/admin` con la de A, `/admin` sin sesión (404),
`/api/citas` con la sesión de N y `/api/citas` sin sesión (401). Las dos
últimas de cada par están a propósito: una cabecera de seguridad que solo
acompañe a las respuestas correctas deja sin cubrir las de error.

Todas las medidas son con `curl -I`, que pide solo las cabeceras (método
`HEAD`). Las salidas imprimen la respuesta **completa** de cada ruta, no solo
las cabeceras buscadas.

**La afirmación que sostiene este bloque es que la aplicación ya no envía
`X-Powered-By`**, no que el framework deje de reconocerse: otras cabeceras
siguen llevando su nombre y no se pueden quitar (11.7, limitación 11).

## Evidencia 11.1 — Antes: ninguna cabecera de seguridad, y `X-Powered-By` en las páginas

**Qué demuestra:** Sobre el build de producción, sin tocar la configuración,
ninguna de las siete respuestas lleva ninguna de las seis cabeceras de
seguridad buscadas. Las cinco páginas anuncian `X-Powered-By: Next.js`.

**Corrección de un esperado que no se cumplió.** El guion declaraba, antes de
medir: «X-Powered-By: Next.js en **todas**». No fue así: **las dos respuestas
de `/api/citas` no la llevan**, ni la 200 ni la 401; solo la llevan las
páginas. Se deja escrito como no se cumplió, sin cambiar el esperado de la
salida. No se investigó por qué las rutas de la API no la envían.

**Salida** (`salida-cita16-cabeceras-antes.txt`; con `...` se omiten las otras
cinco rutas del bloque 1 y las otras cinco cabeceras del bloque 2, todas con
`-` en las siete rutas)

```
--- curl -I /  (sesion: ninguna)
  HTTP/1.1 200 OK
  Vary: rsc, next-router-state-tree, next-router-prefetch, next-router-segment-prefetch, Accept-Encoding
  x-nextjs-cache: HIT
  x-nextjs-prerender: 1
  x-nextjs-prerender: 1
  x-nextjs-stale-time: 300
  X-Powered-By: Next.js
  Cache-Control: s-maxage=31536000
  ETag: "8gsl3e8ankb5z"
  Content-Type: text/html; charset=utf-8
  Content-Length: 14493
  Date: Tue, 20 Oct 2026 14:41:46 GMT
  Connection: keep-alive
  Keep-Alive: timeout=5
...
--- curl -I /api/citas  (sesion: ninguna)
  HTTP/1.1 401 Unauthorized
  vary: rsc, next-router-state-tree, next-router-prefetch, next-router-segment-prefetch
  content-type: application/json
  Date: Tue, 20 Oct 2026 14:41:48 GMT
  Connection: keep-alive
  Keep-Alive: timeout=5

--- X-Powered-By
  / (sin sesion)               Next.js
  /login (sin sesion)          Next.js
  /inicio (N)                  Next.js
  /admin (A)                   Next.js
  /admin (sin sesion)          Next.js
  /api/citas (N)               -
  /api/citas (sin sesion)      -

--- X-Content-Type-Options
  / (sin sesion)               -
  /login (sin sesion)          -
  /inicio (N)                  -
  /admin (A)                   -
  /admin (sin sesion)          -
  /api/citas (N)               -
  /api/citas (sin sesion)      -
...
```

## Evidencia 11.2 — La configuración añadida

**Qué demuestra:** Todo el cambio está en `next.config.ts`, visible y
auditable en un solo sitio. Se escribió con la documentación de la versión
instalada (`node_modules/next/dist/docs/`, páginas `poweredByHeader` y
`headers` de `next.config.js`), no de memoria.

- `poweredByHeader: false`: la aplicación deja de enviar `X-Powered-By`.
- `headers()` con `source: "/:path*"`, para todas las rutas:

| Cabecera | Valor | Clase de ataque que corta |
|---|---|---|
| `X-Content-Type-Options` | `nosniff` | El navegador no adivina el tipo de un contenido ni ejecuta como script lo que el servidor declaró como otra cosa (la observación de la 7.3) |
| `X-Frame-Options` | `DENY` | *Clickjacking*: ninguna página puede mostrarse dentro de un `iframe` ajeno |
| `Referrer-Policy` | `no-referrer` | Al seguir un enlace no sale la URL de origen |
| `Permissions-Policy` | `camera=(), microphone=(), geolocation=()` | Un script inyectado no puede pedir cámara, micrófono ni ubicación en nombre del sitio |
| `Strict-Transport-Security` | `max-age=31536000` (un año) | Degradación a HTTP y robo de la cookie en una red intermedia. **No verificable aquí** (11.4) |

No hay `Content-Security-Policy`, a propósito (11.5). Cada cabecera lleva en
el código un comentario con el ataque que corta, y la ausencia de CSP, uno
con su motivo.

Antes de construir se comprobó que `src/` no tiene ningún `iframe`, para que
`DENY` no rompiera nada propio. La prueba de que no rompió nada es la 11.6.

## Evidencia 11.3 — Después: las cinco cabeceras en las siete rutas, también en la 404 y la 401, y sin `X-Powered-By`

**Qué demuestra:** Con el mismo guion y las mismas rutas, y esta vez **todo
lo esperado se cumplió**:

- Ninguna de las siete respuestas lleva `X-Powered-By`.
- Las siete llevan las cinco cabeceras, con los mismos valores, **incluidas
  la 404 de `/admin` sin sesión y la 401 de `/api/citas` sin sesión**.
- **La raíz `/` también**: `"/:path*"` la cubre. La documentación dice que
  `*` admite cero segmentos, y se comprobó aquí en vez de darlo por hecho.
- Ninguna lleva `Content-Security-Policy`.
- Los códigos son los del «antes» (200, 200, 200, 200, 404, 200, 401): el
  cambio no alteró ninguna respuesta.

**Salida** (`salida-cita16-cabeceras.txt`; con `...` se omiten las otras
cuatro rutas del bloque 1 y las otras cuatro cabeceras del bloque 2, con el
mismo valor en las siete rutas)

```
--- curl -I /  (sesion: ninguna)
  HTTP/1.1 200 OK
  X-Content-Type-Options: nosniff
  X-Frame-Options: DENY
  Referrer-Policy: no-referrer
  Permissions-Policy: camera=(), microphone=(), geolocation=()
  Strict-Transport-Security: max-age=31536000
  Vary: rsc, next-router-state-tree, next-router-prefetch, next-router-segment-prefetch, Accept-Encoding
  x-nextjs-cache: HIT
  x-nextjs-prerender: 1
  x-nextjs-prerender: 1
  x-nextjs-stale-time: 300
  Cache-Control: s-maxage=31536000
  ETag: "124ic1scxj3b5z"
  Content-Type: text/html; charset=utf-8
  Content-Length: 14493
  Date: Tue, 20 Oct 2026 14:50:59 GMT
  Connection: keep-alive
  Keep-Alive: timeout=5
...
--- curl -I /admin  (sesion: ninguna)
  HTTP/1.1 404 Not Found
  X-Content-Type-Options: nosniff
  X-Frame-Options: DENY
  Referrer-Policy: no-referrer
  Permissions-Policy: camera=(), microphone=(), geolocation=()
  Strict-Transport-Security: max-age=31536000
  Vary: rsc, next-router-state-tree, next-router-prefetch, next-router-segment-prefetch, Accept-Encoding
  Link: </_next/static/media/797e433ab948586e-s.p.0r6juujl39pe6.woff2>; rel=preload; as="font"; crossorigin=""; type="font/woff2", </_next/static/media/83afe278b6a6bb3c-s.p.2bn3s6zvc0dyp.woff2>; rel=preload; as="font"; crossorigin=""; type="font/woff2", </_next/static/chunks/1unlft2bcjfh1.css>; rel=preload; as="style"
  Cache-Control: private, no-cache, no-store, max-age=0, must-revalidate
  Content-Type: text/html; charset=utf-8
  Date: Tue, 20 Oct 2026 14:50:59 GMT
  Connection: keep-alive
  Keep-Alive: timeout=5
...
--- curl -I /api/citas  (sesion: ninguna)
  HTTP/1.1 401 Unauthorized
  X-Content-Type-Options: nosniff
  X-Frame-Options: DENY
  Referrer-Policy: no-referrer
  Permissions-Policy: camera=(), microphone=(), geolocation=()
  Strict-Transport-Security: max-age=31536000
  vary: rsc, next-router-state-tree, next-router-prefetch, next-router-segment-prefetch
  content-type: application/json
  Date: Tue, 20 Oct 2026 14:50:59 GMT
  Connection: keep-alive
  Keep-Alive: timeout=5

--- X-Powered-By
  / (sin sesion)               -
  /login (sin sesion)          -
  /inicio (N)                  -
  /admin (A)                   -
  /admin (sin sesion)          -
  /api/citas (N)               -
  /api/citas (sin sesion)      -

--- X-Content-Type-Options
  / (sin sesion)               nosniff
  /login (sin sesion)          nosniff
  /inicio (N)                  nosniff
  /admin (A)                   nosniff
  /admin (sin sesion)          nosniff
  /api/citas (N)               nosniff
  /api/citas (sin sesion)      nosniff
...
--- Content-Security-Policy
  / (sin sesion)               -
  /login (sin sesion)          -
  /inicio (N)                  -
  /admin (A)                   -
  /admin (sin sesion)          -
  /api/citas (N)               -
  /api/citas (sin sesion)      -
```

## Evidencia 11.4 — `Strict-Transport-Security`: enviada, no verificable sobre HTTP

**Qué demuestra:** Solo que **la aplicación envía la cabecera**, en las siete
rutas (11.3). **No demuestra que se fuerce HTTPS**, y no se presenta como
comprobado. Este entorno sirve por HTTP, y el navegador solo obedece
`Strict-Transport-Security` cuando la recibe por HTTPS; por HTTP la ignora
(RFC 6797, sección 8.1). Comprobar su efecto exige desplegar con TLS, y eso
queda fuera del entorno del proyecto.

La salida lo dice en su propio bloque 3, para que la limitación viaje con la
medida:

```
 3. STRICT-TRANSPORT-SECURITY: PUESTA, NO VERIFICABLE AQUI
---------------------------------------------------------------
 La cabecera viaja, pero este entorno sirve por HTTP. El navegador
 solo hace caso de Strict-Transport-Security cuando la recibe por
 HTTPS; por HTTP la ignora (RFC 6797, seccion 8.1). Lo unico que
 demuestra esta evidencia es que la aplicacion la envia, no que
 fuerce HTTPS. Comprobarlo exige desplegar con TLS.
```

## Evidencia 11.5 — Sin `Content-Security-Policy`: una decisión con su coste

**Qué demuestra:** Que la ausencia de CSP es una **decisión**, y cuál es su
coste. Las dos CSP posibles hoy tienen un precio:

- **La rápida, fija en `next.config.ts`, obliga a `'unsafe-inline'` en
  `script-src`.** Next.js hidrata la página con scripts en línea: los trozos
  de carga útil RSC que se ven en la 10.8 viajan dentro de
  `<script>self.__next_f.push(...)</script>`. Una política fija que no los
  permita deja la aplicación sin hidratar. Permitirlos con `'unsafe-inline'`
  autoriza también cualquier script en línea que se inyecte, que es justo el
  XSS que la CSP debía cortar. Sería ponerle a la aplicación la debilidad de
  validación que motiva este trabajo, a sabiendas.
- **La correcta, con un nonce por petición, obliga a renderizar en cada
  petición las páginas que hoy son estáticas.** La guía de CSP de la versión
  instalada (`node_modules/next/dist/docs/01-app/02-guides/content-security-policy.md`)
  dice que el nonce se genera en un Proxy y que «you **must use dynamic
  rendering** to add nonces»: las páginas estáticas se generan en el build,
  «when no request or response headers exist—so no nonce can be injected».
  Y **hoy `/` y `/login` son estáticas: medido**, con `x-nextjs-prerender: 1`
  y `x-nextjs-cache: HIT` en las dos (11.3). Añadir el nonce las sacaría del
  prerenderizado y añadiría a la aplicación su primer Proxy.

No se midió cuánto cuesta en rendimiento renderizar esas dos páginas en cada
petición; lo medido es que hoy no se renderizan así. **Esa es la decisión: no
poner una CSP que no protege, y no cambiar el modo de renderizado de la
aplicación el último día del sprint.** La CSP con nonce es una mejora
concreta, con su coste ya identificado, no una tarea olvidada.

## Evidencia 11.6 — La interfaz sigue funcionando

**Qué demuestra:** Que con las cabeceras puestas la interfaz sigue
funcionando. Lo comprobó **Dair a mano, en el navegador**, el 20 de octubre.
No se dio por comprobado con `curl`: lo que se verifica aquí es que la
interfaz responde al pulsar.

**El registro se verificó sin enviar el formulario.** Lo comprobado es la
pantalla y su validación, no el registro completo: no se creó ninguna cuenta.

- **Pantalla de registro:** se dibuja y valida. Con una contraseña de cuatro
  caracteres marca el campo en rojo y muestra «La contrasena debe tener al
  menos 12 caracteres.», con la regla completa visible desde antes de
  escribir. El formulario no se envió.
- **Inicio de sesión** con una cuenta ya existente.
- El **panel de `/inicio`** y sus dos pestañas cargan.
- Se **agendó** una cita.
- **Ver detalle:** se despliega.
- **Cancelar:** se pulsó «Cancelar cita» sobre la cita del 18 de octubre,
  salió el aviso de confirmación, se aceptó, y la cita quedó en estado
  *Cancelada* y sin botón de cancelar.
- **`/admin`**, con la cuenta de administrador, muestra las dos pestañas con
  las citas de todas las cuentas.
- **Cerrar sesión:** funciona y devuelve al formulario de acceso.
- Ningún error en la consola del navegador.

## Evidencia 11.7 — Hallazgo: las cabeceras `x-nextjs-*` y el `Vary` con `next-router-*` no se pueden quitar con un Proxy

**Qué demuestra:** Que la **limitación 11** es un límite medido del
framework, no una renuncia. Sin `X-Powered-By`, Next.js sigue poniendo su
nombre en otras cabeceras: `x-nextjs-cache`, `x-nextjs-prerender` y
`x-nextjs-stale-time` en `/` y `/login`, y el `Vary` con `next-router-*` en
las siete rutas (11.3). Se probó **un solo intento**, el directo, igual que la
alternativa del Proxy de la 10.7: un Proxy con `matcher: "/:path*"` que borra
esas cuatro cabeceras de la respuesta que devuelve.

**Resultado: no desaparece ninguna.** El build registra el Proxy
(`ƒ Proxy (Middleware)`) y los códigos de las siete rutas no cambian, pero
las cuatro cabeceras salen con los mismos valores y en las mismas rutas que
sin él.

**Por qué:** el Proxy se ejecuta **antes** de que Next.js renderice la página
o ejecute la ruta de la API. Esas cabeceras las escribe después el propio
servidor sobre la respuesta final, así que en la respuesta del Proxy todavía
no existen y no hay nada que borrar. La medida demuestra que el borrado no
tiene efecto; el orden se deduce de eso y de dónde las añade el código
(Next.js 16.3.6, rutas bajo `node_modules/next/dist/`):

| Cabecera | Archivo y línea |
|---|---|
| `Vary` de las páginas | `build/templates/app-page-runtime.js:459` |
| `x-nextjs-cache` | `build/templates/app-page-runtime.js:1056` |
| `x-nextjs-prerender` | `build/templates/app-page-runtime.js:1060` |
| `x-nextjs-stale-time` | `server/app-render/app-render.js:1864` |
| `vary` de las rutas de la API | `server/base-server.js:1225` |

**Una condición que existe y no se investigó.** `x-nextjs-cache` se escribe
dentro de un `if (!isMinimalMode)` (`app-page-runtime.js:1053`), e
`isMinimalMode` sale de un dato interno de la petición,
`getRequestMeta(req, 'minimalMode')` (línea 160), no de `next.config`. No se
siguió: no se sabe cómo se activa ni si quitaría algo más que esa cabecera.
Por eso este bloque no afirma que no exista ningún mecanismo para quitarlas,
solo que **un Proxy no lo consigue**.

El guion crea `src/proxy.ts` solo para la medida y lo borra al terminar; el
código entregado no tiene Proxy.

**Salida** (`salida-cita16-proxy.txt`; con `...` se omiten las respuestas
completas del bloque 2, que repiten las del 11.3)

```
--- src/proxy.ts (temporal)
  | import { NextResponse } from "next/server";
  | 
  | // Experimento de evidencia-cita16-proxy.sh: intenta borrar de la
  | // respuesta las cabeceras que delatan el framework.
  | export function proxy() {
  |   const respuesta = NextResponse.next();
  |   for (const nombre of [
  |     "x-nextjs-cache",
  |     "x-nextjs-prerender",
  |     "x-nextjs-stale-time",
  |     "vary",
  |   ]) {
  |     respuesta.headers.delete(nombre);
  |   }
  |   return respuesta;
  | }
  | 
  | export const config = {
  |   matcher: "/:path*",
  | };

--- pnpm build
  ✓ Compiled successfully in 1623ms
  ƒ Proxy (Middleware)
  codigo de salida: 0
...
--- x-nextjs-cache
  / (sin sesion)               HIT
  /login (sin sesion)          HIT
  /inicio (N)                  -
  /admin (A)                   -
  /admin (sin sesion)          -
  /api/citas (N)               -
  /api/citas (sin sesion)      -

--- x-nextjs-prerender
  / (sin sesion)               1  +  1
  /login (sin sesion)          1  +  1
  /inicio (N)                  -
  /admin (A)                   -
  /admin (sin sesion)          -
  /api/citas (N)               -
  /api/citas (sin sesion)      -

--- x-nextjs-stale-time
  / (sin sesion)               300
  /login (sin sesion)          300
  /inicio (N)                  -
  /admin (A)                   -
  /admin (sin sesion)          -
  /api/citas (N)               -
  /api/citas (sin sesion)      -

--- Vary
  / (sin sesion)               rsc, next-router-state-tree, next-router-prefetch, next-router-segment-prefetch, Accept-Encoding
  /login (sin sesion)          rsc, next-router-state-tree, next-router-prefetch, next-router-segment-prefetch, Accept-Encoding
  /inicio (N)                  rsc, next-router-state-tree, next-router-prefetch, next-router-segment-prefetch, Accept-Encoding
  /admin (A)                   rsc, next-router-state-tree, next-router-prefetch, next-router-segment-prefetch, Accept-Encoding
  /admin (sin sesion)          rsc, next-router-state-tree, next-router-prefetch, next-router-segment-prefetch, Accept-Encoding
  /api/citas (N)               rsc, next-router-state-tree, next-router-prefetch, next-router-segment-prefetch
  /api/citas (sin sesion)      rsc, next-router-state-tree, next-router-prefetch, next-router-segment-prefetch
...
  src/proxy.ts borrado: si
  git status de src/proxy.ts: '' (vacio = como en el repositorio)
```

## Limpieza

Cada guion borró sus dos cuentas como `postgres`, por id y correo exacto, y
sus sesiones cayeron en cascada. Los tres servidores quedaron parados. Lo
que **no** limpia `evidencia-cita16-proxy.sh` es el `.next`: el build que deja
incluye el Proxy, que no hace nada, hasta el siguiente build.

```
  Comprobacion: no queda rastro
     cuentas | sesiones 
    ---------+----------
           0 |        0
    (1 row)
    
  Temporales borrados: si
  Servidor del guion en el puerto 3016: parado
```

(Las tres salidas terminan igual.)

---

## Resumen de controles evidenciados

| Control | Evidencia | OWASP |
|---|---|---|
| Contraseñas con hash bcrypt (coste 12) y nunca en texto | 2.2, 2.3 | A02 Cryptographic Failures |
| Política de contraseñas verificada en el servidor | 2.4 | A07 Auth Failures |
| Consultas parametrizadas, sin ORM, y privilegios mínimos | 1.3, 1.4 | A03 Injection |
| Identificadores UUID, no secuenciales | 1.1 | A01 Broken Access Control |
| Defensa contra mass assignment (`z.strictObject`) | 2.4 | A04 Insecure Design |
| Anti-enumeración de usuarios en registro y login | 2.6, 3.5, 4.2, 4.5 | A07 Auth Failures |
| Sesión opaca revocable con cookie `HttpOnly`/`SameSite` | 3.1, 3.2, 3.4 | A07 Auth Failures |
| Token de sesión aleatorio (CSPRNG) y guardado hasheado | 3.2 | A02 Cryptographic Failures |
| Bloqueo de cuenta por intentos fallidos | 4.1, 4.2, 4.3, 4.4 | A07 Auth Failures |
| Aislamiento entre bases de datos del servidor | 1.5 | A01 Broken Access Control |
| Restricciones de integridad en la tabla de citas (`CHECK`, FK) | 5.1, 5.4 | A04 Insecure Design |
| Privilegios acotados por columna sobre las citas | 5.2, 5.4, 5.5 | A01 Broken Access Control |
| Sin permiso de borrado sobre citas ni usuarios | 5.2, 5.4 | A01 Broken Access Control |
| Control de acceso por objeto: cita ajena = inexistente, sin cambios ni diferencia de tiempo | 6.1, 6.2, 6.3, 6.5 | A01 Broken Access Control |
| Identificadores de cita UUID v4, no secuenciales | 6.4 | A01 Broken Access Control |
| `INSERT` sobre `users` acotado por columna: la aplicación no puede crear admins | 6.6, 6.7 | A01 Broken Access Control |
| Privilegios por defecto de tablas futuras reducidos a `SELECT` | 6.7 | A05 Security Misconfiguration |
| Validación en el servidor con el mismo esquema del cliente, sin depender del navegador | 7.1 | A04 Insecure Design |
| Claves no declaradas rechazadas con respuesta idéntica y sin eco de lo enviado | 7.1 | A04 Insecure Design |
| Fecha en el pasado rechazada en dos capas independientes (esquema y `CHECK`) | 7.2 | A04 Insecure Design |
| Texto guardado literal y escapado al mostrarse, también el motivo en el panel (anti-XSS) | 7.3, 7.4 | A03 Injection |
| Archivos de entorno fuera del repositorio y de su historial | 8.1 | A05 Security Misconfiguration |
| Ningún secreto en el JavaScript ni en el HTML que recibe el navegador | 8.3 | A05 Security Misconfiguration |
| La aplicación no arranca con el entorno incompleto, ni conectada como `postgres` | 8.4, 8.5 | A05 Security Misconfiguration |
| Sesión exigida antes que nada en las rutas de citas, también ante un cuerpo basura | 9.1 | A01 Broken Access Control |
| El dueño de la cita sale de la sesión; `userId` y `status` en el cuerpo rechazan la petición entera | 9.2, 9.3, 9.5 | A01 / A04 Insecure Design |
| Consulta parametrizada: una inyección en el motivo se guarda como texto | 9.6 | A03 Injection |
| Listado filtrado por dueño en la consulta, sin exponer el id del dueño | 9.7 | A01 Broken Access Control |
| Cita ajena, inexistente y con id mal formado: el mismo 404, byte a byte | 9.8 | A01 Broken Access Control |
| El rol de administrador solo se asigna en la base, ni al crear la cuenta ni después | 10.1 (con 1.4, 6.6 y 6.7) | A01 Broken Access Control |
| Vista de administrador: rol comprobado en el servidor, en un solo módulo, antes de cualquier consulta | 10.2, 10.4, 10.5 | A01 Broken Access Control |
| Ni el hash ni los campos de bloqueo salen de la base: columnas nombradas (limitación 9) | 10.3 | A01 Broken Access Control |
| El administrador solo consulta: no existe ninguna ruta que escriba | 10.4 | A01 Broken Access Control |
| Sin rol, el mismo código 404 que una ruta inexistente y ningún dato; cuerpo y cabeceras delatan la ruta (limitación 10) | 10.5, 10.6, 10.7, 10.8 | A01 Broken Access Control |
| El rol se lee de la base en cada petición: degradar una cuenta surte efecto al instante | 10.9 | A01 Broken Access Control |
| La aplicación ya no envía `X-Powered-By` (otras cabeceras de Next.js siguen: limitación 11) | 11.1, 11.3, 11.7 | A05 Security Misconfiguration |
| `nosniff`, `X-Frame-Options: DENY`, `Referrer-Policy` y `Permissions-Policy` en todas las respuestas, también 404 y 401 | 11.2, 11.3, 11.6 | A05 Security Misconfiguration |
| `Strict-Transport-Security` enviada; **su efecto no es verificable sobre HTTP** | 11.3, 11.4 | A05 Security Misconfiguration |

### Limitaciones conocidas, documentadas en el código

1. **DoS por bloqueo**: quien conozca un correo puede dejar a esa persona
   fuera 15 minutos con 5 intentos basura. Se mitigaría con un límite por IP,
   retardo progresivo o CAPTCHA tras el tercer fallo.
2. **Sin aviso al usuario legítimo**: ni el registro duplicado ni el bloqueo le
   dicen nada a la persona afectada, porque decirlo sería un oráculo de
   enumeración. La solución estándar es avisar por correo, canal que solo lee
   el dueño de la cuenta; requiere servidor de correo.
3. **Sin barrido de sesiones caducadas**: las filas expiradas ya no validan,
   pero se acumulan en la tabla.
4. **Sin límite de peticiones por IP**: es la defensa que falta para completar
   los controles anti-fuerza bruta.
5. **Transiciones de estado de las citas sin control en la base**: el `CHECK`
   y el `UPDATE` acotado a `status` limitan qué valores admite el estado, pero
   no en qué orden cambian, así que una cita cancelada podría reactivarse
   (`cancelada → programada`) si el endpoint de cancelar tuviera un bug o
   sufriera una inyección. Se resolvería con un trigger `BEFORE UPDATE` que
   solo admita `programada → cancelada`.
6. **El aislamiento entre bases no es permanente**: lo que demuestra la
   evidencia 1.5 es cierto para las bases que existían cuando se ejecutó
   `db/hardening-connect.sql`, pero no se extiende a las que se creen
   después. Una base nueva nace con `CONNECT` para `PUBLIC` y
   `citasegura_app` puede entrar en ella hasta que se vuelva a ejecutar el
   script. Revocar `CONNECT` en `template1` **no** lo evita: el permiso de
   conexión vive en el catálogo global `pg_database` y no se copia de la
   plantilla. Comprobado el 14 de octubre de 2026 en PostgreSQL 18.6: con
   `template1` revocado, una base recién creada tenía `datacl = NULL` y
   `has_database_privilege('citasegura_app', ..., 'CONNECT') = true`.

   Las dos soluciones que parecen obvias **no funcionan** en PostgreSQL 18,
   y se comprobó en el servidor dentro de transacciones que se deshicieron:

   - `ALTER DEFAULT PRIVILEGES ... ON DATABASES` no existe y da
     `error de sintaxis en o cerca de «DATABASES»`. Los privilegios por
     defecto solo cubren objetos de *dentro* de una base (tablas,
     secuencias, funciones, tipos, esquemas).
   - Un disparador de eventos sobre `CREATE DATABASE` se rechaza con
     `los "triggers" por evento no están soportados para CREATE DATABASE`.
     Los disparadores de eventos viven dentro de una base y no ven la
     creación de objetos globales del servidor.

   **Trabajo futuro**: restringir en `pg_hba.conf` las bases a las que
   `citasegura_app` puede autenticarse. Las reglas se evalúan en orden y
   gana la primera que coincide, así que bastaría con dos líneas antes de
   las generales:

   ```
   host  citasegura  citasegura_app  127.0.0.1/32  scram-sha-256
   host  all         citasegura_app  all           reject
   ```

   (más sus equivalentes para `::1/128`). Así el rechazo ocurre en la
   autenticación, antes de mirar ningún permiso, y cubre también las bases
   que todavía no existen. No se ha aplicado ni probado: cambia la
   configuración de todo el servidor y no solo la de CitaSegura. Mientras
   tanto, la regla operativa es volver a ejecutar `hardening-connect.sql`
   después de crear cualquier base. Como ese script es dinámico, no hace
   falta editarlo, y la tabla con que termina muestra si alguna base quedó
   abierta.
7. **La protección es por ruta: no hay denegación por defecto.** Cada ruta
   protegida comprueba la sesión por su cuenta, llamando a `getSession()` al
   principio: `GET /api/auth/me`, `GET` y `POST /api/citas`,
   `POST /api/citas/[id]/cancelar`, la página `/inicio` y, desde CITA-19, la
   página `/admin` (a través de `exigirAdministrador()`). No hay ninguna capa
   común que lo haga por ellas. La revisión de CITA-13 confirmó que hoy no
   falta en ninguna: las únicas rutas sin comprobación son las públicas por
   diseño (`/`, `/login`, `/registro`, `POST /api/auth/login`,
   `POST /api/auth/register`) y `POST /api/auth/logout`, que sin sesión
   responde 200 sin hacer nada.

   El problema es lo que pasa **mañana**. Una ruta nueva que olvide llamar a
   `getSession()` queda abierta a cualquiera, y nada avisa: no falla al
   compilar, no falla al probarla con sesión, y funciona perfectamente para
   quien la escribió. **Una ruta que nadie protegió es otra vía hacia el mismo
   resultado: datos de una persona accesibles para otra.** El control existe y
   funciona en todas las rutas salvo en una, y esa basta para exponer los
   datos. Mientras la protección dependa de que cada ruta se acuerde de
   pedirla, el sistema es tan seguro como su ruta más descuidada (OWASP A01,
   Broken Access Control).

   **Trabajo futuro**: invertir el modelo para **denegar por defecto**. En
   Next.js 16 el middleware se llama *Proxy* (`src/proxy.ts`) y se ejecuta
   antes de cualquier ruta. Rechazaría toda petición sin cookie de sesión,
   salvo una lista explícita y corta de rutas públicas. Así, olvidar algo deja
   la ruta **cerrada**, no abierta, y el fallo se ve en cuanto alguien la
   prueba. La documentación de Next advierte de que el Proxy sirve para
   comprobaciones *optimistas*, como la presencia de la cookie, y no debe ser
   la única autorización. Por eso no sustituiría a `getSession()`: cada ruta
   seguiría validando la sesión contra la base. Serían dos capas, y la
   primera fallaría siempre hacia el lado seguro.
8. **Cabeceras de seguridad HTTP: cerrada en parte el 20 de octubre
   (bloque 11).**

   **Cómo estaba, el 15 de octubre.** Las respuestas no llevaban
   `X-Content-Type-Options: nosniff` (evidencia 7.3). Con `curl` sobre
   `/login` y `/api/auth/me`, en el servidor de desarrollo, tampoco aparecían
   `Content-Security-Policy` ni `X-Frame-Options`, y sí
   `X-Powered-By: Next.js`, que anuncia el framework. No era explotable por la
   vía del 7.3, porque los navegadores actuales no interpretan
   `application/json` como HTML, pero sin `nosniff` esa garantía dependía del
   navegador y no del servidor. La medida en producción del 20 de octubre lo
   confirmó con un matiz: `X-Powered-By` solo salía en las páginas, no en la
   API (11.1).

   **Lo que se cerró** (11.2, 11.3, 11.6). En las siete rutas medidas,
   incluidas la 404 y la 401:
   - La aplicación ya no envía `X-Powered-By`.
   - Envía `X-Content-Type-Options: nosniff`, que hace que la garantía del
     7.3 dependa ahora del servidor.
   - Envía `X-Frame-Options: DENY`, `Referrer-Policy: no-referrer` y
     `Permissions-Policy` con cámara, micrófono y ubicación denegados.
   - La interfaz sigue funcionando, comprobado a mano.

   **Lo que sigue abierto:**
   - **`Content-Security-Policy`, por decisión y con su coste** (11.5). La
     fija obligaría a `'unsafe-inline'`, que anula su protección contra XSS.
     La de nonce obliga a renderizar en cada petición `/` y `/login`, que hoy
     están prerenderizadas (medido).
     **Trabajo futuro**: un Proxy que genere el nonce por petición, aceptando
     el renderizado dinámico de esas páginas.
   - **`Strict-Transport-Security` se envía, pero su efecto no se ha
     verificado** (11.4): por HTTP el navegador la ignora.
     **Trabajo futuro**: comprobarla en un despliegue con TLS.
   - **Next.js sigue siendo reconocible por sus cabeceras**, aunque ya no
     envíe `X-Powered-By`: es la limitación 11.
9. **Que el hash no salga de la base depende de la consulta, no de un
   permiso.** `citasegura_app` tiene `SELECT` sobre `password_hash`,
   `failed_attempts` y `locked_until` porque el login los necesita. La vista
   de administrador no los muestra porque su consulta nombra solo `name`,
   `email`, `role` y `created_at` (evidencia 10.3). Es un control del código:
   una consulta futura que pidiera esas columnas, o un `SELECT *`, las traería
   sin que la base lo impidiera, y desde el servidor viajarían serializadas en
   el HTML si acabaran en las props de un Client Component.
   **Trabajo futuro**: un segundo rol de base de datos, de solo lectura, con
   `SELECT` únicamente sobre `name`, `email`, `role` y `created_at` de `users`
   (y lo que la vista lea de `appointments`). La vista de administrador lo
   usaría con **su propio pool de conexiones**. Así pedir el hash desde esa
   vista daría `permiso denegado`, como hoy lo da escribir `role` (10.1). No
   está construido.
10. **El 404 de `/admin` delata que la ruta existe: el código HTTP coincide;
   el cuerpo y las cabeceras, no.**
   Quien no es administrador recibe un 404, el **mismo código HTTP** que una
   ruta inexistente, y ningún dato de la vista (10.5). Pero **el cuerpo y las
   cabeceras son distintos** (10.6). La 404 de una ruta inexistente es la
   página prerenderizada, con `x-nextjs-cache: HIT`, `ETag` y
   `Content-Length`. La de `/admin` se genera al vuelo y su carga útil RSC
   nombra el segmento `"admin"`. Quien compare las dos respuestas enteras
   puede saber que la vista existe. En pantalla no se nota: en el navegador
   las dos muestran la misma 404 por defecto (10.6).

   **No es lo mismo que un 403.** Un 403 lo dice en la línea de estado, a
   cualquier cliente y por estándar. Aquí la línea de estado dice «no
   existe», y para ver la diferencia hay que comparar la respuesta completa
   con una 404 de referencia y conocer las marcas internas de Next.js. Es una
   fuga de existencia, no de datos.

   **La alternativa se midió y no la cierra** (10.7). Un Proxy que reescribe
   `/admin` hacia una ruta inexistente deja el cuerpo idéntico byte a byte,
   pero Next.js 16.3.6 añade siempre a la respuesta la cabecera
   `x-middleware-rewrite` con el destino
   (`next/dist/server/lib/router-utils/resolve-routes.js`, líneas 466 a 469).
   **Trabajo futuro**: repetir la medida de `evidencia-cita19-proxy.sh` con
   cada versión nueva de Next.js. Si la cabecera deja de enviarse, el Proxy
   cierra la limitación, con `exigirAdministrador()` como segunda capa.
11. **Las cabeceras `x-nextjs-*` y el `Vary` con `next-router-*` llevan el
   nombre del framework, y un Proxy no las quita.** Medido con un Proxy en
   Next.js 16.3.6 (11.7): no se pueden quitar, porque las fija el servidor
   después del Proxy. `x-nextjs-cache`, `x-nextjs-prerender` y
   `x-nextjs-stale-time` salen en `/` y `/login`, y el `Vary` con
   `next-router-*` en todas las rutas. Se añaden en
   `node_modules/next/dist/build/templates/app-page-runtime.js` (líneas 459,
   1056 y 1060), `node_modules/next/dist/server/app-render/app-render.js`
   (línea 1864) y `node_modules/next/dist/server/base-server.js` (línea 1225).
   Hay una condición que existe y no se investigó: `x-nextjs-cache` depende
   de `isMinimalMode` (`app-page-runtime.js`, línea 1053), un dato interno de
   la petición, no una opción de `next.config`.
   **Trabajo futuro**: repetir la medida de `evidencia-cita16-proxy.sh` con
   cada versión nueva de Next.js, igual que la de la limitación 10.
