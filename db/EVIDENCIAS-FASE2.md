# CitaSegura — Evidencias de la Fase 2 (CITA-5 a CITA-10 y CITA-18)

Recopilación de evidencias de los controles de seguridad implementados en la
fase 2 del proyecto: base de datos endurecida, registro seguro, inicio de
sesión con sesiones propias, bloqueo de cuenta por intentos fallidos y el
esquema seguro de la tabla de citas.

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
(ver el apartado de limpieza). La única cuenta que sobrevive es
`test@gmail.com`, preexistente, que no se modificó en ningún momento.

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

La salida de `\ddp` posterior al cambio no se capturó en esta ejecución,
porque falló la conexión como `postgres`. La comprobación con salida real de
que los privilegios quedaron acotados está en la **evidencia 5.2**, sobre la
tabla `appointments`, que fija los suyos de forma explícita sin depender de
la regla por defecto.

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
(«Consulta de control», cancelada) sigue en la base.

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
