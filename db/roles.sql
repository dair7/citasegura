-- ============================================================
--  CitaSegura - Rol de aplicacion con privilegios minimos
--
--  Ejecutar como superusuario, CONECTADO A LA BASE citasegura:
--    psql -U postgres -d citasegura \
--         -v app_password="LA_CONTRASENA" -f db/roles.sql
--
--  IMPORTANTE: la contrasena NO esta en este archivo. Se pasa como
--  variable de psql (:'app_password') porque este archivo SI se
--  versiona en Git. El valor real vive unicamente en .env.local.
--
--  Ejecutar DESPUES de db/schema.sql, porque los permisos se
--  otorgan sobre tablas que ya deben existir.
-- ============================================================

-- ------------------------------------------------------------
--  1. El rol de la aplicacion
-- ------------------------------------------------------------
--  LOGIN      -> puede conectarse.
--  Sin SUPERUSER, sin CREATEDB, sin CREATEROLE: solo lo necesario.
--
--  El script es idempotente. CREATE ROLE no admite "IF NOT EXISTS",
--  asi que se consulta antes con \gset y se decide con \if.
--  (No se usa un bloque DO $$...$$ porque psql NO interpola sus
--   variables dentro de cadenas con comillas de dolar: :'app_password'
--   llegaria literal a PostgreSQL.)
-- ------------------------------------------------------------
SELECT NOT EXISTS (
    SELECT 1 FROM pg_roles WHERE rolname = 'citasegura_app'
) AS crear_rol \gset

\if :crear_rol
    CREATE ROLE citasegura_app LOGIN PASSWORD :'app_password';
\else
    -- Ya existia: se sincroniza la contrasena con la de .env.local.
    ALTER ROLE citasegura_app WITH LOGIN PASSWORD :'app_password';
\endif

-- ------------------------------------------------------------
--  2. Quitar los permisos que PostgreSQL da "gratis"
-- ------------------------------------------------------------
--  Por defecto, el rol PUBLIC (es decir, TODOS los roles) puede
--  conectarse a cualquier base. Se revoca para que solo los roles
--  autorizados de forma explicita puedan entrar.
-- ------------------------------------------------------------
REVOKE ALL ON DATABASE citasegura FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM PUBLIC;

-- ------------------------------------------------------------
--  3. Conceder SOLO lo estrictamente necesario
-- ------------------------------------------------------------
-- Conectarse a esta base (y a ninguna otra).
GRANT CONNECT ON DATABASE citasegura TO citasegura_app;

-- Ver el esquema public. Notese que NO se concede CREATE:
-- la aplicacion no puede crear ni eliminar tablas.
GRANT USAGE ON SCHEMA public TO citasegura_app;

-- Operaciones de datos sobre la tabla users: leer (login, sesion)
-- e insertar (registro). NADA MAS.
-- NO incluye TRUNCATE, ni DROP, ni ALTER: una inyeccion SQL exitosa
-- no podria destruir la tabla users.
--
-- TAMPOCO incluye UPDATE (ver el apartado 3.b): el unico UPDATE que
-- la aplicacion necesita es sobre dos columnas concretas, y se
-- concede ahi de forma acotada.
--
-- SE NOMBRA LA TABLA, NO "ON ALL TABLES IN SCHEMA public": este
-- script se vuelve a ejecutar (es idempotente), y un GRANT sobre
-- todas las tablas alcanzaria tambien a las creadas DESPUES, como
-- appointments, a la que se le niega DELETE a proposito. Cada tabla
-- recibe sus permisos en su propio script, de forma explicita.
GRANT SELECT, INSERT ON users TO citasegura_app;

-- ------------------------------------------------------------
--  3.a  SIN DELETE sobre users (CITA-18)
-- ------------------------------------------------------------
--  La aplicacion no tiene ninguna funcionalidad de eliminar cuenta,
--  ni esta prevista en el alcance. El DELETE existia SOLO porque un
--  script de pruebas (scripts-evidencias/evidencia-cita10.sh) lo
--  usaba para borrar las cuentas de prueba que creaba.
--
--  Ampliar los permisos de la aplicacion por comodidad de desarrollo
--  es exactamente lo que el privilegio minimo busca evitar. Un
--  permiso que ningun codigo de la aplicacion usa es superficie de
--  ataque gratuita: no aporta nada al funcionamiento y solo sirve a
--  quien consiga inyectar SQL.
--
--  Y este en concreto era grave. Con ON DELETE CASCADE en sessions y
--  appointments, un "DELETE FROM users WHERE ..." inyectado no borraba
--  solo la cuenta: arrastraba todo el historial de citas de esa
--  persona. Es justo lo que appointments.sql impide negando DELETE
--  sobre las citas; dejarlo abierto en users anulaba ese control por
--  la puerta de atras.
--
--  La limpieza de datos de prueba es mantenimiento, y la ejecuta el
--  superusuario, no la aplicacion.
--
--  REVOKE EXPLICITO: el GRANT de arriba ya no incluye DELETE, pero
--  los permisos son acumulativos y en la base ya montada el DELETE
--  sigue concedido. Quitarlo del GRANT no lo retira; este REVOKE si.
--  Es idempotente: revocar un permiso que no existe no es un error.
-- ------------------------------------------------------------
REVOKE DELETE ON users FROM citasegura_app;

-- ------------------------------------------------------------
--  3.b  UPDATE acotado A DOS COLUMNAS (CITA-10)
-- ------------------------------------------------------------
--  El bloqueo de cuentas por intentos fallidos necesita escribir
--  failed_attempts y locked_until. NADA MAS.
--
--  Con un UPDATE de tabla completa, una inyeccion SQL en cualquier
--  endpoint podria:
--    - reescribir password_hash de otra cuenta (robo de cuenta sin
--      conocer la contrasena);
--    - poner role = 'admin' (escalada de privilegios);
--    - cambiar el email (secuestro por recuperacion de contrasena).
--
--  PostgreSQL permite conceder UPDATE por COLUMNA, asi que se retira
--  el permiso de tabla y se concede solo lo justo.
--
--  EL REVOKE VA PRIMERO A PROPOSITO: los permisos son acumulativos,
--  y una version anterior de este script concedia UPDATE de tabla
--  completa. Sin retirarlo, volver a ejecutar el script dejaria el
--  permiso amplio y este apartado no serviria de nada.
-- ------------------------------------------------------------
REVOKE UPDATE ON users FROM citasegura_app;
GRANT UPDATE (failed_attempts, locked_until) ON users TO citasegura_app;

-- Las secuencias (contadores) que puedan existir.
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO citasegura_app;

-- ------------------------------------------------------------
--  4. Permisos automaticos para tablas futuras
-- ------------------------------------------------------------
--  Sin esto, cada tabla nueva creada por 'postgres' naceria sin
--  permisos para la aplicacion y habria que repetir los GRANT a mano.
-- ------------------------------------------------------------
--  Solo SELECT e INSERT: ni UPDATE ni DELETE. Si una tabla futura
--  necesita actualizar o borrar, su propio script lo concede de forma
--  explicita y acotada, como se hace arriba con failed_attempts y
--  locked_until. Asi ninguna tabla nueva nace con mas permisos de los
--  que necesita.
--
--  POR QUE EL REVOKE VA PRIMERO (CITA-18)
--  Una version anterior de este script fijo como valor por defecto
--  SELECT, INSERT, UPDATE, DELETE. Esa regla NO vive en este fichero,
--  vive en el catalogo pg_default_acl de la base: editar el fichero
--  no la cambia, y ALTER DEFAULT PRIVILEGES ... GRANT solo AGREGA
--  permisos, nunca retira los que ya estaban. Se comprobo con \ddp
--  en la base real: citasegura_app=arwd/postgres (w = UPDATE,
--  d = DELETE).
--
--  El riesgo es silencioso: una tabla que nace con permisos amplios
--  los conserva sin que ningun script los muestre, y nadie se entera
--  hasta que alguien los audita. Mientras tanto, una inyeccion SQL
--  podria reescribir o borrar filas que el codigo jamas toca.
--
--  REVOKE ALL deja la regla en blanco y el GRANT siguiente la vuelve a
--  escribir con lo justo. Es idempotente: revocar algo que no estaba
--  concedido no es un error, y el resultado final es siempre el mismo.
--
--  Solo afecta a las tablas que se creen A PARTIR de ahora. Las ya
--  existentes conservan su ACL; por eso cada script de tabla
--  (sessions.sql, appointments.sql) fija la suya de forma explicita.
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    REVOKE ALL ON TABLES FROM citasegura_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT, INSERT ON TABLES TO citasegura_app;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT USAGE, SELECT ON SEQUENCES TO citasegura_app;
