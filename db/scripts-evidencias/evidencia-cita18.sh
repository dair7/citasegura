#!/usr/bin/env bash
# ---------------------------------------------------------------
#  CitaSegura - Evidencia de CITA-18 (esquema seguro de citas)
#  Uso:  bash evidencia-cita18.sh
#  Requiere: psql, node y .env.local
#
#  Todas las pruebas se ejecutan con el rol REAL de la aplicacion,
#  nunca como superusuario: lo que se demuestra es lo que la
#  aplicacion puede y no puede hacer. La conexion de citasegura_app
#  se lee de la DATABASE_URL de .env.local, que NUNCA se imprime.
#
#  Las citas de prueba cuelgan de una cuenta PROPIA del guion
#  (prueba.cita18.*@ejemplo.com), no de una cuenta real: antes se
#  usaba la primera de 'users', y la prueba 5.3 cancelaba sus citas
#  programadas. Al final se borra como 'postgres', por id capturado Y
#  correo exacto, y sus citas con ella; la contrasena de postgres se
#  toma de DB_PASSWORD o, si no existe, de PGPASSWORD.
#
#  Si alguna orden no termina como se espera, queda dicho en la propia
#  salida y el guion termina con codigo 1.
#
#  No requiere que la aplicacion este corriendo.
# ---------------------------------------------------------------

PSQL="/c/Program Files/PostgreSQL/18/bin/psql.exe"
CORREO="prueba.cita18.$(date +%H%M%S)@ejemplo.com"
DIR=$(cd "$(dirname "$0")" && pwd)
RAIZ=$(cd "$DIR/../.." && pwd)

ADMIN_PASS="${DB_PASSWORD:-$PGPASSWORD}"
if [ -z "$ADMIN_PASS" ]; then
  echo "Falta la contrasena de postgres: define DB_PASSWORD o PGPASSWORD."
  exit 1
fi

# Cadena del rol de la aplicacion: se lee del fichero y solo se pasa a
# psql. No se muestra: la contrasena anterior se filtro en una captura.
APP_URL=$(sed -n 's|^DATABASE_URL=||p' "$RAIZ/.env.local" | tr -d '\r')
if [ -z "$APP_URL" ]; then
  echo "No se encontro DATABASE_URL en .env.local."
  exit 1
fi

# El descriptor 3 es siempre la salida del guion: por ahi se avisa de
# un fallo.
exec 3>&1
FALLOS=0

# El rol REAL de la aplicacion: lo que se demuestra es lo que ella puede hacer.
psql_app()   { PGPASSWORD= "$PSQL" "$APP_URL" -w "$@"; }
# Superusuario: solo para limpiar.
psql_admin() { PGPASSWORD="$ADMIN_PASS" "$PSQL" -h 127.0.0.1 -U postgres -d citasegura -w "$@"; }

# comprobar CODIGO_ESPERADO orden...
# Ejecuta la orden con la salida de errores unida a la normal y la
# imprime con la sangria de SANGRIA. Aqui muchos rechazos SON el
# resultado (psql termina con codigo 1); si el codigo no es el
# esperado, lo dice en la salida y lo cuenta: una prueba de la
# seccion 4 que no diera error tambien sale como fallo.
SANGRIA=""
comprobar() {
  local esperado="$1"; shift
  local salida codigo
  salida=$("$@" 2>&1; printf 'x%s' "$?")
  codigo=${salida##*x}
  salida=${salida%x*}
  if [ "$codigo" = "$esperado" ]; then
    printf '%s' "$salida" | sed "s/^/${SANGRIA}/"
  else
    printf '%s' "$salida" | sed "s/^/${SANGRIA}/" >&3
    echo "    FALLO DEL GUION: psql termino con codigo ${codigo} (se esperaba ${esperado}); esta medida no vale." >&3
    FALLOS=$((FALLOS + 1))
  fi
}
app() { comprobar 0 psql_app "$@"; }

# Seccion 4: se espera el rechazo (codigo 1). Seccion 5: que funcione (0).
ESPERADO=0
intento() {
  echo ""
  echo "  $1"
  echo "  ---------------------------------------------------------"
  SANGRIA="  " comprobar "$ESPERADO" psql_app -c "$2"
}

LIMPIADO=0
limpieza() {
  [ "$LIMPIADO" = 1 ] && return
  LIMPIADO=1
  echo ""
  echo "--- 6. Limpieza (como postgres: es mantenimiento, no la aplicacion)"
  if [ -z "$UID_PRUEBA" ]; then
    echo "    No se capturo ningun id: no hay cuenta de prueba que borrar."
    return
  fi
  # Por el id capturado Y el correo exacto, nunca por un patron ni por
  # motivo: antes se borraba con reason IN ('Consulta de control',
  # 'Control general'), que se llevaba cualquier cita real con ese motivo.
  comprobar 0 psql_admin -c "DELETE FROM appointments
             WHERE user_id = '${UID_PRUEBA}'
            RETURNING id, reason;"
  comprobar 0 psql_admin -c "DELETE FROM users
             WHERE id = '${UID_PRUEBA}' AND email = '${CORREO}'
            RETURNING id, email;"
  comprobar 0 psql_admin -c "SELECT
             (SELECT count(*) FROM users        WHERE id      = '${UID_PRUEBA}') AS cuentas,
             (SELECT count(*) FROM appointments WHERE user_id = '${UID_PRUEBA}') AS citas;"
}
trap 'limpieza; exit 130' INT TERM

# Solo si la salida es una terminal: redirigida a un fichero, clear
# meteria secuencias de escape en la evidencia.
[ -t 1 ] && clear
echo "==============================================================="
echo " CITA-18  Esquema seguro de la tabla de citas"
echo " Todas las pruebas se ejecutan como citasegura_app"
echo " Fecha: $(date '+%Y-%m-%d %H:%M:%S')"
echo "==============================================================="

# --------------------------------------------------------------
echo ""
echo "--- 1. Estructura de la tabla y sus restricciones"
app -c "\d appointments"

# --------------------------------------------------------------
echo ""
echo "--- 2. Privilegios de la aplicacion sobre la tabla"
app -c "
SELECT 'tabla' AS nivel, p AS privilegio,
       has_table_privilege('citasegura_app', 'appointments', p) AS concedido
FROM unnest(ARRAY['SELECT','INSERT','UPDATE','DELETE','TRUNCATE']) AS p
UNION ALL
SELECT 'columna ' || c, p,
       has_column_privilege('citasegura_app', 'appointments', c, p)
FROM unnest(ARRAY['id','user_id','scheduled_at','reason','status','created_at']) AS c,
     unnest(ARRAY['INSERT','UPDATE']) AS p
ORDER BY 1, 2;"

# --------------------------------------------------------------
echo ""
echo "--- 3. La aplicacion NO puede borrar usuarios ni citas"
app -c "
SELECT has_table_privilege('citasegura_app','users','DELETE')        AS borrar_usuarios,
       has_table_privilege('citasegura_app','appointments','DELETE') AS borrar_citas,
       has_table_privilege('citasegura_app','appointments','TRUNCATE') AS vaciar_citas;"

# --------------------------------------------------------------
echo ""
echo "==============================================================="
echo " 4. LO QUE LA BASE RECHAZA, aunque el codigo lo intente"
echo "==============================================================="

# Cuenta propia sobre la que colgar las citas de prueba. La crea
# citasegura_app con los mismos permisos que el registro, y con un hash
# bcrypt real (coste 12, como la aplicacion) de una contrasena aleatoria
# que no se guarda en ningun sitio: nadie puede entrar con ella.
HASH=$(cd "$RAIZ" && node -e '
  const bcrypt = require("bcryptjs");
  bcrypt.hash(require("crypto").randomBytes(24).toString("base64url"), 12).then(h => console.log(h));
')
UID_PRUEBA=$(psql_app -t -A -q -c "
INSERT INTO users (name, email, password_hash)
VALUES ('Prueba Cita18', '${CORREO}', '${HASH}')
RETURNING id;" 2>&1)
unset HASH
if ! [[ "$UID_PRUEBA" =~ ^[0-9a-f-]{36}$ ]]; then
  echo ""
  printf '%s\n' "$UID_PRUEBA"
  echo "  FALLO DEL GUION: no se pudo crear la cuenta de prueba. Se aborta."
  exit 1
fi

echo ""
echo "  Las citas de prueba se cuelgan del usuario $UID_PRUEBA"

ESPERADO=1

intento "4.1  Estado inventado: la base solo admite 'programada' y 'cancelada'" \
"INSERT INTO appointments (user_id, scheduled_at, reason)
 VALUES ('${UID_PRUEBA}', now() + interval '2 days', 'Control general');
 UPDATE appointments SET status = 'atendida'
 WHERE user_id = '${UID_PRUEBA}';"

intento "4.2  Motivo vacio" \
"INSERT INTO appointments (user_id, scheduled_at, reason)
 VALUES ('${UID_PRUEBA}', now() + interval '2 days', '   ');"

intento "4.3  Motivo que excede la longitud maxima" \
"INSERT INTO appointments (user_id, scheduled_at, reason)
 VALUES ('${UID_PRUEBA}', now() + interval '2 days', repeat('x', 600));"

intento "4.4  Cita para un usuario que no existe" \
"INSERT INTO appointments (user_id, scheduled_at, reason)
 VALUES (gen_random_uuid(), now() + interval '2 days', 'Cita huerfana');"

intento "4.5  Elegir el identificador de la cita (no se puede: sin permiso en 'id')" \
"INSERT INTO appointments (id, user_id, scheduled_at, reason)
 VALUES ('00000000-0000-0000-0000-000000000001', '${UID_PRUEBA}',
         now() + interval '2 days', 'Id elegido a dedo');"

intento "4.6  Crear una cita que nazca ya cancelada (sin permiso en 'status')" \
"INSERT INTO appointments (user_id, scheduled_at, reason, status)
 VALUES ('${UID_PRUEBA}', now() + interval '2 days', 'Nace cancelada', 'cancelada');"

intento "4.7  Datar el registro en el pasado para saltarse el CHECK de fechas" \
"INSERT INTO appointments (user_id, scheduled_at, reason, created_at)
 VALUES ('${UID_PRUEBA}', now() - interval '10 days', 'Cita retroactiva',
         now() - interval '20 days');"

intento "4.8  Cambiar el dueño de una cita (sin permiso UPDATE en 'user_id')" \
"UPDATE appointments SET user_id = gen_random_uuid()
 WHERE user_id = '${UID_PRUEBA}';"

intento "4.9  Mover la fecha de una cita (sin permiso UPDATE en 'scheduled_at')" \
"UPDATE appointments SET scheduled_at = now() + interval '90 days'
 WHERE user_id = '${UID_PRUEBA}';"

intento "4.10 Borrar una cita" \
"DELETE FROM appointments WHERE user_id = '${UID_PRUEBA}';"

intento "4.11 Vaciar la tabla de citas de golpe" \
"TRUNCATE appointments;"

intento "4.12 Borrar un usuario (arrastraria sus citas en cascada)" \
"DELETE FROM users WHERE id = '${UID_PRUEBA}';"

# --------------------------------------------------------------
echo ""
echo "==============================================================="
echo " 5. LO QUE LA APLICACION SI PUEDE HACER"
echo "==============================================================="

ESPERADO=0

intento "5.1  Agendar una cita: solo dueño, fecha y motivo" \
"INSERT INTO appointments (user_id, scheduled_at, reason)
 VALUES ('${UID_PRUEBA}', now() + interval '3 days', 'Consulta de control')
 RETURNING id, status, created_at;"

echo ""
echo "  5.2  Lo que quedo guardado"
echo "  ---------------------------------------------------------"
SANGRIA="  " app -x -c "
SELECT id                AS identificador,
       scheduled_at      AS fecha_de_la_cita,
       reason            AS motivo,
       status            AS estado,
       created_at        AS creada
FROM appointments
WHERE user_id = '${UID_PRUEBA}'
ORDER BY created_at DESC LIMIT 1;"

intento "5.3  Cancelar la cita (unico cambio de estado permitido)" \
"UPDATE appointments SET status = 'cancelada'
 WHERE user_id = '${UID_PRUEBA}' AND status = 'programada'
 RETURNING id, status;"

# --------------------------------------------------------------
trap - INT TERM
limpieza

echo ""
echo "==============================================================="
echo " Esperado:"
echo "   4.1 a 4.4  -> ERROR por restriccion CHECK o clave foranea"
echo "   4.5 a 4.9  -> ERROR 'permiso denegado' por columna"
echo "   4.10 a 4.12 -> ERROR 'permiso denegado' por tabla"
echo "   5.1 a 5.3  -> correcto: agendar, consultar y cancelar"
echo "   6          -> citas y cuenta de prueba borradas; quedan 0"
echo "==============================================================="
echo ""
if [ "$FALLOS" -gt 0 ]; then
  echo " RESULTADO DEL GUION: ${FALLOS} medida(s) no terminaron como se esperaba"
  echo " (ver FALLO DEL GUION). Esta salida NO vale como evidencia."
  exit 1
fi
echo " RESULTADO DEL GUION: todas las medidas se hicieron."
