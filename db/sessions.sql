-- ============================================================
--  CitaSegura - Tabla de sesiones (CITA-9)
--  Ejecutar como superusuario, CONECTADO A LA BASE citasegura:
--    psql -U postgres -d citasegura -v ON_ERROR_STOP=1 \
--         -f db/sessions.sql
--
--  El script es IDEMPOTENTE: se puede ejecutar varias veces
--  sin error ni perdida de datos.
--
--  Ejecutar DESPUES de db/schema.sql (la clave foranea apunta a
--  users) y DESPUES de db/roles.sql (el rol ya debe existir).
-- ============================================================

-- ------------------------------------------------------------
--  Tabla: sessions
-- ------------------------------------------------------------
--  DECISION CENTRAL: aqui NO se guarda el token de sesion, sino
--  su SHA-256. El token en claro existe unicamente en la cookie
--  del navegador del usuario.
--
--  Si alguien consiguiera leer esta tabla (inyeccion SQL en otro
--  endpoint, un backup filtrado, un volcado de logs), con los
--  tokens en claro se llevaria SESIONES ACTIVAS listas para usar:
--  entraria en las cuentas sin contraseña, sin tocar bcrypt y sin
--  dejar rastro de un inicio de sesion. Con el hash, lo que roba
--  no le sirve para nada.
--
--  ¿Por que SHA-256 y no bcrypt, si para las contraseñas usamos
--  bcrypt? Por dos razones:
--
--  1. bcrypt usa una sal ALEATORIA por fila, asi que su hash no
--     sirve como clave de busqueda: habria que recorrer todas las
--     sesiones comparando una por una, a ~400 ms cada una. SHA-256
--     es determinista, asi que el hash ES la clave primaria y la
--     busqueda es indexada.
--
--  2. bcrypt es lento A PROPOSITO porque las contraseñas tienen
--     poca entropia y hay que encarecer el adivinarlas. Un token
--     de 256 bits aleatorios no esta en ningun diccionario y no se
--     adivina por fuerza bruta: un hash lento no aportaria
--     seguridad y penalizaria cada peticion.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sessions (
    -- SHA-256 del token, en hexadecimal (64 caracteres).
    id            TEXT          PRIMARY KEY,

    -- A quien pertenece la sesion.
    --
    -- ON DELETE CASCADE: al borrar un usuario desaparecen sus
    -- sesiones. Sin esto quedarian sesiones huerfanas que siguen
    -- presentando una cookie valida para una cuenta que ya no
    -- existe.
    user_id       UUID          NOT NULL
                                REFERENCES users(id) ON DELETE CASCADE,

    -- Caducidad ABSOLUTA de la sesion. TIMESTAMPTZ (con zona),
    -- nunca TIMESTAMP: un instante sin zona caducaria a la hora
    -- equivocada segun donde este el servidor.
    --
    -- La comprobacion de caducidad se hace en SQL contra now(),
    -- es decir, con el reloj del SERVIDOR DE BASE DE DATOS. Si se
    -- comparara con el reloj del cliente, bastaria cambiar la hora
    -- del equipo para revivir una sesion caducada.
    expires_at    TIMESTAMPTZ   NOT NULL,

    created_at    TIMESTAMPTZ   NOT NULL DEFAULT now(),

    -- ---- Restricciones de integridad (defensa en profundidad) ----

    -- CONTROL CLAVE, espejo de users_password_hash_is_bcrypt: solo
    -- se aceptan 64 caracteres hexadecimales, la forma exacta de un
    -- SHA-256. Un token en claro (base64url, con mayusculas, '-' y
    -- '_') NO cumple este patron, asi que si el codigo intentara
    -- guardar el token sin hashear, el INSERT falla.
    CONSTRAINT sessions_id_es_sha256_hex
        CHECK (id ~ '^[0-9a-f]{64}$'),

    -- Una sesion no puede nacer ya caducada.
    CONSTRAINT sessions_caduca_despues_de_crearse
        CHECK (expires_at > created_at)
);

-- ------------------------------------------------------------
--  Indices
-- ------------------------------------------------------------
-- La busqueda por id ya va por el indice de la clave primaria.

-- Por usuario: para cerrar todas las sesiones de una cuenta de
-- golpe (util al cambiar la contraseña, y en CITA-10 al bloquear
-- una cuenta).
CREATE INDEX IF NOT EXISTS sessions_user_id_idx
    ON sessions (user_id);

-- Por caducidad: para barrer las sesiones expiradas sin recorrer
-- la tabla entera.
CREATE INDEX IF NOT EXISTS sessions_expires_at_idx
    ON sessions (expires_at);

-- ------------------------------------------------------------
--  Privilegios minimos para la aplicacion
-- ------------------------------------------------------------
--  La tabla es propiedad de 'postgres' a proposito (la crea el
--  superusuario), igual que users: asi la aplicacion no puede
--  hacerle DROP ni ALTER.
--
--  db/roles.sql configura
--    ALTER DEFAULT PRIVILEGES ... GRANT SELECT, INSERT
--  es decir, SIN UPDATE ni DELETE. Aun asi aqui se otorga lo
--  necesario de forma explicita (DELETE hace falta para el logout) y
--  se REVOCA UPDATE, por defensa en profundidad: una version anterior
--  de roles.sql si concedia UPDATE por defecto, y esa regla queda en
--  la base aunque el fichero cambie. En una base montada con esa
--  version, la tabla naceria con UPDATE; el REVOKE garantiza el
--  resultado sea cual sea el historial de la base.
--
--  ¿Por que quitar UPDATE? Porque una sesion debe ser INMUTABLE.
--  Con UPDATE, una inyeccion SQL podria:
--    - reapuntar una sesion propia a otro user_id (el de un admin)
--      y escalar privilegios sin robar ninguna credencial;
--    - estirar expires_at indefinidamente y volver la sesion eterna.
--  Para renovar una sesion se borra y se crea otra, con un token
--  nuevo, que ademas es la practica correcta (rotacion de token).
-- ------------------------------------------------------------
GRANT SELECT, INSERT, DELETE ON sessions TO citasegura_app;
REVOKE UPDATE ON sessions FROM citasegura_app;

-- No se concede TRUNCATE (no esta incluido en los GRANT de arriba):
-- una inyeccion no puede vaciar la tabla y echar a todos los
-- usuarios de golpe.
