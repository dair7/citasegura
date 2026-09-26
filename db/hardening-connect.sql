-- ============================================================
--  CitaSegura - Endurecimiento: aislar citasegura_app de las
--  demas bases de datos del servidor local.
--
--  Ejecutar como superusuario:
--    psql -U postgres -h 127.0.0.1 -p 5432 -d postgres \
--         -v ON_ERROR_STOP=1 -f db/hardening-connect.sql
--
--  Es IDEMPOTENTE: volver a ejecutarlo no causa error.
-- ============================================================
--
--  PROBLEMA
--  PostgreSQL concede CONNECT al rol PUBLIC (es decir, a TODOS
--  los roles) en cada base de datos nueva. Por eso citasegura_app,
--  pese a tener privilegios minimos sobre la tabla users, podia
--  conectarse a las otras bases del servidor y leer sus catalogos
--  del sistema (nombres de bases, roles, estructuras de tablas).
--  Es fuga de informacion, aunque no pudiera leer datos de usuario.
--
--  POR QUE ES SEGURO
--  En este servidor solo dos roles pueden iniciar sesion:
--    - postgres        -> SUPERUSER, y los superusuarios IGNORAN
--                         las comprobaciones de privilegios, asi que
--                         este REVOKE no les afecta.
--    - citasegura_app  -> el rol que se quiere aislar.
--  Se verifico que los otros proyectos locales usan PGUSER=postgres.
--
--  NO SE TOCA la base citasegura: ahi citasegura_app SI debe entrar.
-- ============================================================


-- ------------------------------------------------------------
--  BLOQUE 1: bases de datos de otros proyectos
-- ------------------------------------------------------------
REVOKE CONNECT ON DATABASE cortex_dev      FROM PUBLIC;
REVOKE CONNECT ON DATABASE devportfolio_db FROM PUBLIC;
REVOKE CONNECT ON DATABASE notes_app_db    FROM PUBLIC;
REVOKE CONNECT ON DATABASE notes_app_final FROM PUBLIC;


-- ------------------------------------------------------------
--  BLOQUE 2: base de mantenimiento y plantilla
-- ------------------------------------------------------------
--  'postgres' es la base de mantenimiento a la que se conectan por
--  defecto las herramientas administrativas. 'template1' es la
--  plantilla desde la que PostgreSQL clona cada base nueva.
--  Ninguna contiene datos de la aplicacion, pero ambas permiten
--  leer los catalogos del sistema.
--
--  REVOCAR CONNECT EN template1 ROMPE LA CREACION DE BASES NUEVAS?
--  NO. Son dos cosas distintas:
--
--    1) El privilegio CONNECT vive en la columna datacl de la tabla
--       pg_database, que es un catalogo GLOBAL del servidor. No vive
--       dentro de la base. Al ejecutar CREATE DATABASE, PostgreSQL
--       copia el CONTENIDO de la plantilla (esquemas, tablas,
--       extensiones) pero inserta una fila NUEVA en pg_database con
--       datacl = NULL, es decir con los permisos POR DEFECTO.
--       El datacl de la plantilla NO se hereda.
--
--       Verificado empiricamente en este servidor: con template1
--       teniendo un datacl explicito ({=c/postgres,...}), una base
--       recien clonada nacio con datacl = NULL. Si se heredara,
--       habria nacido con el ACL de la plantilla.
--
--    2) Lo que SI se hereda son los permisos de los objetos DENTRO
--       de la plantilla. Si se revocara USAGE del esquema public DE
--       template1, todas las bases nuevas naceran con ese esquema
--       restringido. Este script NO toca nada dentro de template1:
--       solo el CONNECT a nivel de base.
--
--  ADEMAS: clonar template1 exige ser su propietario o superusuario,
--  y citasegura_app no tiene CREATEDB, asi que nunca podria crear
--  bases de todos modos. Y revocar CONNECT reduce el error clasico
--  "source database is being accessed by other users" al clonar.
-- ------------------------------------------------------------
REVOKE CONNECT ON DATABASE postgres  FROM PUBLIC;
REVOKE CONNECT ON DATABASE template1 FROM PUBLIC;


-- ============================================================
--  COMO REVERTIR
-- ============================================================
--  Cada REVOKE se deshace con su GRANT espejo. Son independientes:
--  revertir una base no afecta a las demas.
--
--  Bloque 1:
--    GRANT CONNECT ON DATABASE cortex_dev      TO PUBLIC;
--    GRANT CONNECT ON DATABASE devportfolio_db TO PUBLIC;
--    GRANT CONNECT ON DATABASE notes_app_db    TO PUBLIC;
--    GRANT CONNECT ON DATABASE notes_app_final TO PUBLIC;
--
--  Bloque 2:
--    GRANT CONNECT ON DATABASE postgres  TO PUBLIC;
--    GRANT CONNECT ON DATABASE template1 TO PUBLIC;
--
--  Revertir TODO de una vez:
--    psql -U postgres -h 127.0.0.1 -p 5432 -d postgres -c "GRANT CONNECT ON DATABASE cortex_dev TO PUBLIC; GRANT CONNECT ON DATABASE devportfolio_db TO PUBLIC; GRANT CONNECT ON DATABASE notes_app_db TO PUBLIC; GRANT CONNECT ON DATABASE notes_app_final TO PUBLIC; GRANT CONNECT ON DATABASE postgres TO PUBLIC; GRANT CONNECT ON DATABASE template1 TO PUBLIC;"
--
--  COMO LEER EL ESTADO en la columna datacl de pg_database:
--    datacl = NULL          -> permisos por defecto: PUBLIC TIENE CONNECT.
--    "=Tc/postgres"         -> PUBLIC tiene TEMPORARY y CONNECT.
--    "=T/postgres"          -> PUBLIC solo tiene TEMPORARY: CONNECT REVOCADO.
--    "postgres=CTc/postgres"-> el rol postgres tiene CREATE, TEMP y CONNECT.
--  La letra 'c' es CONNECT, 'T' es TEMPORARY, 'C' es CREATE.
-- ============================================================
