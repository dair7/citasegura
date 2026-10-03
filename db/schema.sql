-- ============================================================
--  CitaSegura - Esquema de base de datos
--  Ejecutar con:
--    psql -U postgres -d citasegura -f db/schema.sql
--
--  El script es IDEMPOTENTE: se puede ejecutar varias veces
--  sin error ni perdida de datos.
-- ============================================================

-- ------------------------------------------------------------
--  Tabla: users
-- ------------------------------------------------------------
--  Nota sobre gen_random_uuid(): desde PostgreSQL 13 viene
--  incluida en el nucleo, no hace falta instalar la extension
--  pgcrypto.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS users (
    -- Clave primaria UUID en lugar de entero autoincremental.
    -- Un id secuencial (1, 2, 3...) permite enumerar usuarios y
    -- acceder a recursos ajenos cambiando el numero en la URL
    -- (IDOR - OWASP A01: Broken Access Control).
    id                UUID          PRIMARY KEY DEFAULT gen_random_uuid(),

    name              TEXT          NOT NULL,

    -- El correo identifica la cuenta, por eso es UNIQUE.
    -- Se guarda siempre en minusculas para que "Ana@x.com" y
    -- "ana@x.com" no puedan convertirse en dos cuentas distintas.
    email             TEXT          NOT NULL UNIQUE,

    -- NUNCA la contrasena en texto plano: solo el hash bcrypt.
    password_hash     TEXT          NOT NULL,

    -- Minimo privilegio: toda cuenta nueva nace como 'user'.
    -- El rol 'admin' se asigna de forma deliberada, nunca por defecto.
    role              TEXT          NOT NULL DEFAULT 'user',

    -- Contador de intentos de inicio de sesion fallidos consecutivos.
    -- Se reinicia a 0 tras un inicio de sesion correcto. (CITA-10)
    failed_attempts   INTEGER       NOT NULL DEFAULT 0,

    -- NULL = la cuenta no esta bloqueada.
    -- Con fecha = bloqueada hasta ese instante. (CITA-10)
    locked_until      TIMESTAMPTZ,

    -- TIMESTAMPTZ (con zona horaria), no TIMESTAMP: un timestamp
    -- sin zona pierde el huso y los bloqueos expirarian a la hora
    -- equivocada segun la zona del servidor.
    created_at        TIMESTAMPTZ   NOT NULL DEFAULT now(),

    -- ---- Restricciones de integridad (defensa en profundidad) ----
    -- La base de datos rechaza datos invalidos aunque la aplicacion
    -- tenga un bug. No se confia solo en la validacion del codigo.

    -- Obliga a normalizar el correo a minusculas.
    CONSTRAINT users_email_lowercase
        CHECK (email = lower(email)),

    -- Formato minimo de correo: algo@algo.algo, sin espacios.
    CONSTRAINT users_email_format
        CHECK (email ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'),

    -- CONTROL CLAVE: solo se aceptan hashes bcrypt.
    -- Un hash bcrypt empieza por $2a$ / $2b$ / $2y$ seguido del
    -- factor de coste ($10$, $12$...). Si el codigo intentara
    -- guardar la contrasena en texto plano, este CHECK hace
    -- fallar el INSERT.
    CONSTRAINT users_password_hash_is_bcrypt
        CHECK (password_hash ~ '^\$2[aby]\$[0-9]{2}\$'),

    -- Solo existen estos dos roles.
    CONSTRAINT users_role_valido
        CHECK (role IN ('user', 'admin')),

    -- El contador de fallos no puede ser negativo.
    CONSTRAINT users_failed_attempts_no_negativo
        CHECK (failed_attempts >= 0)
);

-- El UNIQUE de email ya crea su propio indice, por eso no se
-- agrega otro: seria un indice duplicado sin beneficio.
