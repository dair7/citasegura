#!/usr/bin/env bash
# ---------------------------------------------------------------
#  CitaSegura - Evidencia de CITA-18 (esquema seguro de citas)
#  Uso:  bash evidencia-cita18.sh
#
#  Pide la contrasena de citasegura_app UNA sola vez al inicio.
#  Todas las pruebas se ejecutan con el rol REAL de la aplicacion,
#  nunca como superusuario: lo que se demuestra es lo que la
#  aplicacion puede y no puede hacer.
#
#  No requiere que la aplicacion este corriendo.
# ---------------------------------------------------------------

PSQL="/c/Program Files/PostgreSQL/18/bin/psql.exe"
CONN=(-h 127.0.0.1 -U citasegura_app -d citasegura)

read -rsp "Contrasena de citasegura_app: " PGPASSWORD
export PGPASSWORD
echo ""

db()  { "$PSQL" "${CONN[@]}" -c "$1" 2>&1; }
sql() { "$PSQL" "${CONN[@]}" -t -A -c "$1" 2>&1; }

intento() {
  echo ""
  echo "  $1"
  echo "  ---------------------------------------------------------"
  db "$2" | sed 's/^/  /'
}

clear
echo "==============================================================="
echo " CITA-18  Esquema seguro de la tabla de citas"
echo " Todas las pruebas se ejecutan como citasegura_app"
echo " Fecha: $(date '+%Y-%m-%d %H:%M:%S')"
echo "==============================================================="

# --------------------------------------------------------------
echo ""
echo "--- 1. Estructura de la tabla y sus restricciones"
"$PSQL" "${CONN[@]}" -c "\d appointments"

# --------------------------------------------------------------
echo ""
echo "--- 2. Privilegios de la aplicacion sobre la tabla"
"$PSQL" "${CONN[@]}" -c "
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
"$PSQL" "${CONN[@]}" -c "
SELECT has_table_privilege('citasegura_app','users','DELETE')        AS borrar_usuarios,
       has_table_privilege('citasegura_app','appointments','DELETE') AS borrar_citas,
       has_table_privilege('citasegura_app','appointments','TRUNCATE') AS vaciar_citas;"

# --------------------------------------------------------------
echo ""
echo "==============================================================="
echo " 4. LO QUE LA BASE RECHAZA, aunque el codigo lo intente"
echo "==============================================================="

# Usuario real sobre el que colgar las citas de prueba
UID_PRUEBA=$(sql "SELECT id FROM users LIMIT 1;")

if [ -z "$UID_PRUEBA" ]; then
  echo ""
  echo "  No hay ningun usuario en la tabla users."
  echo "  Crea una cuenta en /registro y vuelve a ejecutar el script."
  unset PGPASSWORD
  exit 1
fi

echo ""
echo "  Las citas de prueba se cuelgan del usuario $UID_PRUEBA"

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

intento "5.1  Agendar una cita: solo dueño, fecha y motivo" \
"INSERT INTO appointments (user_id, scheduled_at, reason)
 VALUES ('${UID_PRUEBA}', now() + interval '3 days', 'Consulta de control')
 RETURNING id, status, created_at;"

echo ""
echo "  5.2  Lo que quedo guardado"
echo "  ---------------------------------------------------------"
"$PSQL" "${CONN[@]}" -x -c "
SELECT id                AS identificador,
       scheduled_at      AS fecha_de_la_cita,
       reason            AS motivo,
       status            AS estado,
       created_at        AS creada
FROM appointments
WHERE user_id = '${UID_PRUEBA}'
ORDER BY created_at DESC LIMIT 1;" | sed 's/^/  /'

intento "5.3  Cancelar la cita (unico cambio de estado permitido)" \
"UPDATE appointments SET status = 'cancelada'
 WHERE user_id = '${UID_PRUEBA}' AND status = 'programada'
 RETURNING id, status;"

# --------------------------------------------------------------
echo ""
echo "--- 6. Limpieza (como postgres: es mantenimiento, no la aplicacion)"
if [ -z "$DB_PASSWORD" ]; then
  echo "    Falta la variable DB_PASSWORD. Las citas de prueba quedan en la"
  echo "    base. Para borrarlas, como postgres:"
  echo "      DELETE FROM appointments WHERE reason LIKE 'Consulta de control%'"
  echo "         OR reason LIKE 'Control general%';"
else
  PGPASSWORD="$DB_PASSWORD" "$PSQL" -h 127.0.0.1 -U postgres -d citasegura -c "
  DELETE FROM appointments
  WHERE reason IN ('Consulta de control', 'Control general')
  RETURNING id, reason;"
fi

unset PGPASSWORD

echo ""
echo "==============================================================="
echo " Esperado:"
echo "   4.1 a 4.4  -> ERROR por restriccion CHECK o clave foranea"
echo "   4.5 a 4.9  -> ERROR 'permiso denegado' por columna"
echo "   4.10 a 4.12 -> ERROR 'permiso denegado' por tabla"
echo "   5.1 a 5.3  -> correcto: agendar, consultar y cancelar"
echo "==============================================================="
