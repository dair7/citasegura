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

-- Operaciones de datos sobre las tablas existentes.
-- NO incluye TRUNCATE, ni DROP, ni ALTER: una inyeccion SQL exitosa
-- no podria destruir la tabla users.
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public
    TO citasegura_app;

-- Las secuencias (contadores) que puedan existir.
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO citasegura_app;

-- ------------------------------------------------------------
--  4. Permisos automaticos para tablas futuras
-- ------------------------------------------------------------
--  Sin esto, cada tabla nueva creada por 'postgres' naceria sin
--  permisos para la aplicacion y habria que repetir los GRANT a mano.
-- ------------------------------------------------------------
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO citasegura_app;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT USAGE, SELECT ON SEQUENCES TO citasegura_app;
