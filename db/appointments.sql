-- ============================================================
--  CitaSegura - Tabla de citas (CITA-18)
--  Ejecutar como superusuario, CONECTADO A LA BASE citasegura:
--    psql -U postgres -d citasegura -v ON_ERROR_STOP=1 \
--         -f db/appointments.sql
--
--  El script es IDEMPOTENTE: se puede ejecutar varias veces
--  sin error ni perdida de datos.
--
--  Ejecutar DESPUES de db/schema.sql (la clave foranea apunta a
--  users) y DESPUES de db/roles.sql (el rol ya debe existir).
-- ============================================================

-- ------------------------------------------------------------
--  Tabla: appointments
-- ------------------------------------------------------------
--  Esta es la tabla que el caso DIAN pone en el centro: los datos
--  personales se filtraron desde un sistema de agendamiento. Por
--  eso aqui cada restriccion la impone la BASE DE DATOS, no solo
--  el codigo. Si un endpoint tiene un bug o sufre una inyeccion,
--  PostgreSQL sigue rechazando lo que no debe existir.
--
--  Alcance decidido: el usuario crea, lista, ve y CANCELA sus
--  citas. No puede modificarlas ni borrarlas.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS appointments (
    -- UUID aleatorio, igual que users.id, y no un entero
    -- autoincremental. Con ids secuenciales (/api/citas/41,
    -- /api/citas/42...) basta sumar uno a la URL para probar citas
    -- ajenas: es el IDOR clasico (OWASP A01: Broken Access Control).
    -- Un UUID v4 tiene 122 bits aleatorios: no se puede adivinar.
    --
    -- OJO: el UUID dificulta ADIVINAR ids, pero NO es el control de
    -- acceso. El control es que cada consulta filtre por el dueño
    -- (CITA-13). Un id puede filtrarse por un log o un enlace
    -- compartido, y aun asi no debe abrir una cita ajena.
    id            UUID          PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Dueño de la cita. Es la columna sobre la que descansa todo el
    -- control anti-IDOR: WHERE id = $1 AND user_id = $2.
    --
    -- NOT NULL: no puede existir una cita sin dueño, porque una cita
    -- huerfana no la podria filtrar ningun WHERE user_id = ... y
    -- quedaria fuera de cualquier control de acceso.
    --
    -- ON DELETE CASCADE: al borrar una cuenta desaparecen sus citas,
    -- que son datos personales de esa persona. Sin esto quedarian
    -- citas sin titular, datos personales que ya nadie gestiona.
    user_id       UUID          NOT NULL
                                REFERENCES users(id) ON DELETE CASCADE,

    -- Fecha y hora de la cita. TIMESTAMPTZ (con zona), nunca
    -- TIMESTAMP: una hora sin zona se interpreta segun la zona del
    -- servidor, y la misma cita apareceria a horas distintas segun
    -- donde se lea.
    scheduled_at  TIMESTAMPTZ   NOT NULL,

    -- Motivo de la cita, en texto libre. Es el campo con mas riesgo
    -- de la tabla: lo escribe el usuario y puede contener datos
    -- sensibles. Por eso tiene limites en la base (ver CHECK abajo).
    reason        TEXT          NOT NULL,

    -- Estado. Nace 'programada'; la unica transicion que existe es
    -- a 'cancelada'. No hay estado 'borrada': una cita no se borra.
    status        TEXT          NOT NULL DEFAULT 'programada',

    created_at    TIMESTAMPTZ   NOT NULL DEFAULT now(),

    -- ---- Restricciones de integridad (defensa en profundidad) ----

    -- Solo existen estos dos estados. Sin este CHECK, un bug o una
    -- inyeccion podrian dejar estados inventados ('confirmada',
    -- 'admin', '') que el codigo no sabe tratar y que pueden saltarse
    -- comprobaciones escritas como status = 'programada'.
    CONSTRAINT appointments_status_valido
        CHECK (status IN ('programada', 'cancelada')),

    -- Una cita no puede estar agendada antes de crearse, es decir,
    -- no se pueden crear citas en el pasado. Se compara contra
    -- created_at, que por defecto es now() del SERVIDOR DE BASE DE
    -- DATOS: el reloj del cliente no interviene, asi que cambiar la
    -- hora del equipo no permite saltarse la regla.
    CONSTRAINT appointments_agendada_despues_de_crearse
        CHECK (scheduled_at >= created_at),

    -- El motivo no puede estar vacio ni ser solo espacios: btrim()
    -- quita los blancos antes de medir.
    CONSTRAINT appointments_reason_no_vacio
        CHECK (char_length(btrim(reason)) > 0),

    -- Limite de longitud. Un TEXT sin limite permite meter megas en
    -- cada peticion: llena el disco, infla cada listado y cada
    -- respaldo (denegacion de servicio por almacenamiento). 500
    -- caracteres sobran para un motivo de cita. El esquema Zod de
    -- CITA-14 debe usar el MISMO limite; este CHECK es el respaldo si
    -- la validacion del servidor fallara.
    CONSTRAINT appointments_reason_longitud
        CHECK (char_length(reason) <= 500)
);

-- ------------------------------------------------------------
--  Indices
-- ------------------------------------------------------------
-- Buscar una cita por su id ya va por el indice de la clave
-- primaria. Crear otro seria un indice duplicado sin beneficio.
-- La consulta anti-IDOR (WHERE id = $1 AND user_id = $2) entra por
-- ese indice y comprueba el dueño sobre una sola fila.

-- Listar las citas de un usuario, ordenadas por fecha. Con
-- (user_id, scheduled_at) PostgreSQL encuentra las citas de esa
-- persona y las devuelve ya ordenadas, sin recorrer la tabla ni
-- ordenar despues.
CREATE INDEX IF NOT EXISTS appointments_user_id_scheduled_at_idx
    ON appointments (user_id, scheduled_at);

-- ------------------------------------------------------------
--  Privilegios minimos para la aplicacion
-- ------------------------------------------------------------
--  La tabla es propiedad de 'postgres' a proposito (la crea el
--  superusuario), igual que users y sessions: asi la aplicacion no
--  puede hacerle DROP ni ALTER.
--
--  NO SE CONFIA EN LOS PRIVILEGIOS POR DEFECTO. La regla de
--  ALTER DEFAULT PRIVILEGES vive en la base, no en roles.sql, y ya
--  se comprobo que puede ser mas amplia de lo que dice el fichero
--  (\ddp mostro citasegura_app=arwd). Por eso se borra todo y se
--  concede de forma explicita: el resultado es el mismo sea cual sea
--  el historial de la base.
-- ------------------------------------------------------------

-- 1. Empezar de cero. Un REVOKE ALL sobre la tabla retira tambien
--    los permisos por columna, asi que volver a ejecutar el script
--    deja siempre el mismo resultado.
REVOKE ALL ON appointments FROM citasegura_app;
REVOKE ALL ON appointments FROM PUBLIC;

-- 2. Consultar citas.
GRANT SELECT ON appointments TO citasegura_app;

-- 3. INSERT SOLO SOBRE LAS COLUMNAS QUE RELLENA LA APLICACION:
--    el dueño, la fecha y el motivo. Las otras tres las pone SIEMPRE
--    la base con su DEFAULT, porque la aplicacion no tiene permiso
--    para escribirlas:
--      - id         -> gen_random_uuid(). Una inyeccion no puede
--                      elegir el identificador (por ejemplo, uno ya
--                      conocido o predecible).
--      - status     -> 'programada'. No se puede crear una cita que
--                      nazca ya cancelada.
--      - created_at -> now() del servidor. No se puede datar el
--                      registro en el pasado para que el CHECK
--                      scheduled_at >= created_at deje pasar una
--                      cita en una fecha ya vencida.
--    Un INSERT que nombre cualquiera de esas columnas falla con
--    "permission denied", aunque el valor sea valido.
GRANT INSERT (user_id, scheduled_at, reason) ON appointments
    TO citasegura_app;

-- 4. UPDATE SOLO SOBRE status: es lo unico que exige cancelar.
--    Con UPDATE de tabla completa, una inyeccion SQL podria:
--      - cambiar user_id y "regalar" o robar citas entre cuentas;
--      - mover scheduled_at o reescribir reason (alterar el
--        historial sin dejar rastro);
--      - cambiar created_at y desmontar el CHECK de fechas.
--    Concedido por columna, PostgreSQL rechaza cualquier UPDATE que
--    toque otra columna con "permission denied", aunque el SQL
--    llegue intacto a la base.
GRANT UPDATE (status) ON appointments TO citasegura_app;

-- 5. SIN DELETE, a proposito. Una cita cancelada se MARCA, no se
--    borra. Ni un error de programacion ni una inyeccion SQL
--    (por ejemplo un "; DELETE FROM appointments --") pueden
--    eliminar el historial: PostgreSQL lo rechaza por permisos.
--    El historial completo es ademas lo que permite auditar despues
--    quien agendo y cancelo que: ante un incidente, sin historial no
--    hay forma de reconstruir que paso ni a quien afecto.
--
--    Tampoco TRUNCATE: no esta en ningun GRANT de arriba.

-- ------------------------------------------------------------
--  LIMITACION CONOCIDA: la base no controla las transiciones
--  de estado
-- ------------------------------------------------------------
--  El permiso UPDATE (status) y el CHECK de status limitan QUE
--  valores puede tener el estado, pero no EN QUE ORDEN cambia. Un
--  CHECK solo ve la fila nueva, no la anterior, asi que la base no
--  distingue "programada -> cancelada" (legitimo) de
--  "cancelada -> programada" (revivir una cita cancelada).
--
--  Hoy esa regla la impone solo el codigo: el endpoint de cancelar
--  (CITA-12) escribe siempre 'cancelada' y nunca otro valor. Un bug
--  o una inyeccion SQL en ese endpoint podria reactivar una cita
--  cancelada; lo que NO podria es borrarla, cambiar su dueño, su
--  fecha o su motivo, porque eso lo siguen impidiendo los permisos.
--
--  La solucion estandar es un trigger BEFORE UPDATE que rechace
--  cualquier transicion que no sea programada -> cancelada. Queda
--  fuera del alcance y se documenta como trabajo futuro, junto al
--  barrido de sesiones caducadas, el aviso por correo y el limite
--  de peticiones por IP.
