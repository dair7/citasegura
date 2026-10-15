-- ============================================================
--  CitaSegura - Endurecimiento: aislar citasegura_app de las
--  demas bases de datos del servidor local.
--
--  Ejecutar como superusuario:
--    psql -U postgres -h 127.0.0.1 -p 5432 -d postgres \
--         -v ON_ERROR_STOP=1 -f db/hardening-connect.sql
--
--  Es IDEMPOTENTE: volver a ejecutarlo no causa error.
--  Requiere que citasegura_app ya exista (db/roles.sql): la
--  comprobacion final pregunta por sus privilegios.
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
--  El REVOKE solo quita el CONNECT que llega a traves de PUBLIC:
--    - postgres        -> SUPERUSER, y los superusuarios IGNORAN
--                         las comprobaciones de privilegios, asi que
--                         este REVOKE no les afecta.
--    - citasegura_app  -> el rol que se quiere aislar.
--    - cualquier otro rol de login que NO sea superusuario y que
--      solo entrara a una base por PUBLIC SI queda fuera. Antes de
--      ejecutar el script en un servidor compartido, revisar:
--        SELECT rolname FROM pg_roles
--         WHERE rolcanlogin AND NOT rolsuper;
--      y concederle CONNECT explicito en su propia base:
--        GRANT CONNECT ON DATABASE su_base TO su_rol;
--
--  NO SE TOCA la base citasegura: ahi citasegura_app SI debe entrar
--  (su CONNECT explicito lo concede db/roles.sql).
-- ============================================================


-- ------------------------------------------------------------
--  BLOQUE 1: todas las demas bases del servidor, sin nombrarlas
-- ------------------------------------------------------------
--  POR QUE ES DINAMICO
--  La primera version nombraba a mano las bases de otros proyectos
--  que existian en el equipo de desarrollo original (cuatro REVOKE
--  con nombres fijos). Eso solo valia en esa maquina concreta: en un
--  equipo nuevo esas bases no existen, el primer REVOKE falla, y con
--  ON_ERROR_STOP el script se corta sin aplicar nada. Peor aun, si
--  alguien hubiera quitado esas lineas para que pasara, cualquier
--  base creada despues habria quedado abierta sin aviso.
--
--  El control que este script demuestra -que una credencial
--  filtrada de CitaSegura NO alcanza otros proyectos- tiene que
--  valer en CUALQUIER servidor, con las bases que tenga hoy. Por
--  eso las bases se leen del catalogo pg_database en el momento de
--  ejecutar, y la lista de excepciones es fija y corta.
--
--  QUE BASES SE EXCLUYEN
--    - citasegura: la propia de la aplicacion.
--    - las plantillas (datistemplate): template0 no admite
--      conexiones de nadie (datallowconn = false), y template1 se
--      trata aparte en el bloque 2, con su explicacion.
--  La base de mantenimiento 'postgres' NO es plantilla, asi que
--  entra en este bloque.
--
--  COMO FUNCIONA
--  La consulta GENERA una sentencia REVOKE por cada base, y \gexec
--  (orden de psql) ejecuta cada fila resultante como SQL. format()
--  con %I cita el nombre como identificador: una base con un nombre
--  raro (espacios, comillas, mayusculas) no puede romper ni inyectar
--  nada en la sentencia generada.
--
--  Sigue siendo idempotente: revocar un privilegio que ya no se
--  tiene no es un error en PostgreSQL.
-- ------------------------------------------------------------
SELECT format('REVOKE CONNECT ON DATABASE %I FROM PUBLIC', datname)
  FROM pg_database
 WHERE NOT datistemplate
   AND datname <> 'citasegura'
 ORDER BY datname
\gexec


-- ------------------------------------------------------------
--  BLOQUE 2: la plantilla template1
-- ------------------------------------------------------------
--  'template1' es la plantilla desde la que PostgreSQL clona cada
--  base nueva. Queda fuera del bloque 1 por ser plantilla, pero a
--  diferencia de template0 SI admite conexiones, asi que se revoca
--  aqui de forma explicita. No contiene datos de la aplicacion,
--  pero permite leer los catalogos del sistema.
--  (La base de mantenimiento 'postgres' ya la cubre el bloque 1.)
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
--  CONSECUENCIA PRACTICA, que conviene tener presente:
--  revocar CONNECT en template1 NO cierra las bases futuras. Es
--  facil suponer que las bases nuevas "heredan" el permiso de su
--  plantilla y nacen cerradas. NO es asi: TODA base que se cree en
--  este servidor despues de ejecutar este script nace ABIERTA, con
--  datacl = NULL y CONNECT para PUBLIC, y citasegura_app puede
--  entrar en ella.
--
--  Verificado de nuevo el 14 de octubre de 2026 en el equipo nuevo
--  (PostgreSQL 18.6), con template1 en {postgres=CTc/postgres}:
--    CREATE DATABASE prueba_herencia;
--    -> datacl = NULL, has_database_privilege('citasegura_app',
--       'prueba_herencia', 'CONNECT') = true
--
--  Por eso el aislamiento NO es permanente: hay que VOLVER A
--  EJECUTAR este script despues de crear cualquier base nueva en el
--  servidor. Como el bloque 1 es dinamico, basta con ejecutarlo tal
--  cual, sin editarlo. La tabla de comprobacion del final muestra
--  enseguida si alguna base quedo abierta.
--
--  ADEMAS: clonar template1 exige ser su propietario o superusuario,
--  y citasegura_app no tiene CREATEDB, asi que nunca podria crear
--  bases de todos modos. Y revocar CONNECT reduce el error clasico
--  "source database is being accessed by other users" al clonar.
-- ------------------------------------------------------------
REVOKE CONNECT ON DATABASE template1 FROM PUBLIC;


-- ------------------------------------------------------------
--  COMPROBACION: a que bases puede entrar citasegura_app
-- ------------------------------------------------------------
--  Deja el resultado en la salida del propio script, para que la
--  evidencia no dependa de una consulta aparte. Lo esperado: 'si'
--  unicamente en citasegura (y 'no' en template0, a la que nadie
--  puede conectarse aunque su ACL diga otra cosa).
SELECT datname AS base,
       CASE WHEN has_database_privilege('citasegura_app', datname, 'CONNECT')
                 AND datallowconn
            THEN 'si' ELSE 'no' END AS citasegura_app_puede_conectar
  FROM pg_database
 ORDER BY datname;


-- ============================================================
--  COMO REVERTIR
-- ============================================================
--  Cada REVOKE se deshace con su GRANT espejo. Son independientes:
--  revertir una base no afecta a las demas.
--
--  Una sola base (lo normal: devolver el acceso a un proyecto):
--    GRANT CONNECT ON DATABASE nombre_de_la_base TO PUBLIC;
--
--  Bloque 1, todas las bases que cubre, con la MISMA consulta que
--  las revoco (desde psql, conectado a la base postgres):
--    SELECT format('GRANT CONNECT ON DATABASE %I TO PUBLIC', datname)
--      FROM pg_database
--     WHERE NOT datistemplate AND datname <> 'citasegura'
--    \gexec
--  OJO: la consulta lee las bases que existen AL REVERTIR, no las
--  que existian al endurecer. Abriria tambien una base creada despues
--  o una que estuviera cerrada por otro motivo. Revisar antes la
--  lista con la misma consulta sin \gexec.
--
--  Bloque 2:
--    GRANT CONNECT ON DATABASE template1 TO PUBLIC;
--
--  COMO LEER EL ESTADO en la columna datacl de pg_database:
--    datacl = NULL          -> permisos por defecto: PUBLIC TIENE CONNECT.
--    "=Tc/postgres"         -> PUBLIC tiene TEMPORARY y CONNECT.
--    "=T/postgres"          -> PUBLIC solo tiene TEMPORARY: CONNECT REVOCADO.
--    "postgres=CTc/postgres"-> el rol postgres tiene CREATE, TEMP y CONNECT.
--  La letra 'c' es CONNECT, 'T' es TEMPORARY, 'C' es CREATE.
-- ============================================================
