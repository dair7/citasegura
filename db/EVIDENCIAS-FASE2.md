# CitaSegura — Evidencias de la Fase 2 (CITA-5 a CITA-10, CITA-18, CITA-13 y CITA-14)

Recopilación de evidencias de los controles de seguridad implementados en la
fase 2 del proyecto: base de datos endurecida, registro seguro, inicio de
sesión con sesiones propias, bloqueo de cuenta por intentos fallidos, el
esquema seguro de la tabla de citas, la verificación del control de acceso
anti-IDOR y la validación y sanitización en el servidor.

| | |
|---|---|
| **Generado** | 2026-09-25 22:09:54 HPS |
| **Último commit** | `e5dcc6a SCRUM-7: bloqueo de cuenta tras 5 intentos fallidos` |
| **Motor** | PostgreSQL 18.1, localhost:5432, autenticación scram-sha-256 |
| **Aplicación** | Next.js 16.3.6 (App Router), Node.js runtime |
| **Rol de la aplicación** | `citasegura_app` (sin SUPERUSER) |

*Nota: el mensaje de commit conserva el código del tablero anterior (SCRUM);
la equivalencia con el tablero actual (CITA) está en la tabla de tickets de
`ESTADO-PROYECTO.md`.*

Todas las salidas de este documento provienen de una ejecución real hecha en
la fecha indicada; ninguna está transcrita a mano. Las consultas de la
aplicación se ejecutan **como `citasegura_app`**, nunca como superusuario:
un superusuario se salta las comprobaciones de privilegios y haría que las
pruebas de permisos no demostraran nada.

Las cuentas `evidencia.*@ejemplo.com` que aparecen en los bloques 2 a 4 se
crearon únicamente para generar estas evidencias y se eliminaron al terminar
(ver el apartado de limpieza). En la fecha de generación, la única cuenta que
sobrevivía era `test@gmail.com`, preexistente, que no se modificó en ningún
momento.

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
- **Bloque 2 — CITA-7: registro de usuario seguro**
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
- **Resumen de controles evidenciados**

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

# Bloque 2 — CITA-7: registro de usuario seguro

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
| Los textos se almacenan tal cual se reciben y se escapan al mostrarse, sin ejecutar nada | 7.3 y 7.4, **cerrado a medias** (ver el alcance de la 7.4) |

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

**Alcance: el criterio queda cerrado a medias.** El escape está demostrado en
el camino de renderizado del servidor, con el nombre del usuario. El motivo de
una cita, que es el texto al que se refiere el criterio, todavía no se pinta
en ninguna pantalla: el panel de citas es CITA-11 y no está en el repositorio.
Es una **limitación de la evidencia, no un fallo del control**. Ninguna
pantalla puede pintar el motivo sin escapar, porque ninguna lo pinta, y la 7.3
deja establecido que en `src/` no hay ninguna vía para insertar HTML sin
escapar.

### Cierre pendiente: el motivo en el panel (CITA-11)

*Pendiente hasta que CITA-11 esté en el repositorio.* Para cerrar el criterio
basta añadir aquí, sin rehacer nada de lo anterior:

1. Un párrafo que diga cómo pinta el panel el motivo (Server o Client
   Component) y que no usa `dangerouslySetInnerHTML`.
2. Una captura del panel con una cita cuyo motivo sea
   `<script>alert(1)</script>`, mostrado como texto y sin ejecutarse.

## Limpieza

Las dos cuentas del script se borraron como `postgres`, por id y correo
exacto, y al terminar quedaron `cuentas=0 citas=0 sesiones=0`. Las de la
primera ejecución las borró esa misma ejecución. La cuenta de la consulta
aparte (`sonda.cita14.212027@ejemplo.com`) se borró igual (`DELETE 1`, 0
restantes).

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
| Texto guardado literal y escapado al mostrarse (anti-XSS; el motivo, pendiente de CITA-11) | 7.3, 7.4 | A03 Injection |

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
   `POST /api/citas/[id]/cancelar` y la página `/inicio`. No hay ninguna capa
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
8. **Sin cabeceras de seguridad HTTP**: las respuestas no llevan
   `X-Content-Type-Options: nosniff` (evidencia 7.3). Con `curl` sobre
   `/login` y `/api/auth/me` el 15 de octubre, en el servidor de desarrollo,
   tampoco aparecen `Content-Security-Policy` ni `X-Frame-Options`, y sí
   `X-Powered-By: Next.js`, que anuncia el framework. Hoy no es explotable
   por la vía del 7.3, porque los navegadores actuales no interpretan
   `application/json` como HTML, pero sin `nosniff` esa garantía depende del
   navegador y no del servidor.
   **Trabajo futuro**: declarar las cabeceras en `next.config.ts` con
   `headers()`, quitar `X-Powered-By` con `poweredByHeader: false`, y
   comprobarlo con `curl -I`.
