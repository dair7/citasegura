#!/usr/bin/env bash
# ---------------------------------------------------------------
#  CitaSegura - Evidencia de CITA-8 (hashing con bcrypt)
#  Uso:  bash evidencia-cita8.sh
#  Requiere: app corriendo en localhost:3001, psql y .env.local
#
#  Las consultas se hacen como citasegura_app con la DATABASE_URL de
#  .env.local, que NUNCA se imprime. Las dos cuentas de prueba se
#  borran al final como 'postgres', por id capturado Y correo exacto;
#  su contrasena se toma de DB_PASSWORD o, si no existe, de PGPASSWORD.
#
#  Si alguna consulta no se puede hacer, el error queda en la propia
#  salida (no solo en la pantalla) y el guion termina con codigo 1.
# ---------------------------------------------------------------

PSQL="/c/Program Files/PostgreSQL/18/bin/psql.exe"
U="http://localhost:3001/api/auth/register"
CLAVE="ClaveEvidencia1!"
CORREO="evidencia.bcrypt.$(date +%H%M%S)@ejemplo.com"
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

if [ "$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:3001/api/auth/me")" != "401" ]; then
  echo "La aplicacion no responde en localhost:3001."
  echo "Arrancala con: pnpm dev --webpack --port 3001"
  exit 1
fi

# El descriptor 3 es siempre la salida del guion, aunque quien llama
# descarte la suya: por ahi se avisa de un fallo.
exec 3>&1
FALLOS=0

# El rol REAL de la aplicacion: lo que se demuestra es lo que ella puede hacer.
psql_app()   { PGPASSWORD= "$PSQL" "$APP_URL" -w "$@"; }
# Superusuario: solo para capturar los ids y para limpiar.
psql_admin() { PGPASSWORD="$ADMIN_PASS" "$PSQL" -h 127.0.0.1 -U postgres -d citasegura -w "$@"; }

# comprobar CODIGO_ESPERADO orden...
# Ejecuta la orden con la salida de errores unida a la normal. Antes el
# error de psql iba solo a la pantalla: guardada con tee, la seccion
# quedaba vacia, sin rastro del fallo, y el guion terminaba con codigo 0.
# Si el codigo no es el esperado, lo dice en la salida y lo cuenta.
comprobar() {
  local esperado="$1"; shift
  local salida codigo
  salida=$("$@" 2>&1; printf 'x%s' "$?")
  codigo=${salida##*x}
  salida=${salida%x*}
  if [ "$codigo" = "$esperado" ]; then
    printf '%s' "$salida"
  else
    printf '%s' "$salida" >&3
    echo "    FALLO DEL GUION: psql termino con codigo ${codigo} (se esperaba ${esperado}); esta medida no vale." >&3
    FALLOS=$((FALLOS + 1))
  fi
}
app() { comprobar 0 psql_app "$@"; }

# Id de una cuenta por su correo exacto. Solo se acepta con forma de
# UUID: un mensaje de error de psql no puede pasar por un id.
capturar_id() {
  local id
  id=$(psql_admin -t -A -c "SELECT id FROM users WHERE email = '$1';" 2>&1)
  if [[ "$id" =~ ^[0-9a-f-]{36}$ ]]; then
    echo "$id"
  elif [ -n "$id" ]; then
    echo "$id" >&3
  fi
}

CUENTAS=()  # "id correo" de cada cuenta creada por este guion
LIMPIADO=0
limpieza() {
  [ "$LIMPIADO" = 1 ] && return
  LIMPIADO=1
  echo ""
  echo "--- Limpieza (como postgres: es mantenimiento, no la aplicacion)"
  if [ ${#CUENTAS[@]} -eq 0 ]; then
    echo "    No se capturo ningun id: no hay cuentas de prueba que borrar."
    return
  fi
  # Por los ids capturados Y el correo exacto, nunca por un patron.
  local ids=() correos=() par
  for par in "${CUENTAS[@]}"; do
    ids+=("'${par%% *}'")
    correos+=("'${par#* }'")
  done
  local lista_ids lista_correos
  lista_ids=$(IFS=,; echo "${ids[*]}")
  lista_correos=$(IFS=,; echo "${correos[*]}")
  # Sin tuberia: comprobar tiene que correr en este shell para contar.
  comprobar 0 psql_admin -c "DELETE FROM users
             WHERE id IN (${lista_ids})
               AND email IN (${lista_correos})
            RETURNING id, email;"
  comprobar 0 psql_admin -c "SELECT count(*) AS cuentas_que_quedan
             FROM users WHERE id IN (${lista_ids});"
}
trap 'limpieza; exit 130' INT TERM

# Solo si la salida es una terminal: redirigida a un fichero, clear
# meteria secuencias de escape en la evidencia.
[ -t 1 ] && clear
echo "==============================================================="
echo " CITA-8  Hashing de contrasenas con bcrypt"
echo " Fecha: $(date '+%Y-%m-%d %H:%M:%S')"
echo "==============================================================="

# --------------------------------------------------------------
echo ""
echo "--- 1. Creamos una cuenta por el endpoint de registro"
echo "    Contrasena enviada en claro: $CLAVE"
curl -s -w '\n>> HTTP %{http_code}   (%{time_total}s)\n' \
  -X POST "$U" -H "Content-Type: application/json" \
  -d "{\"name\":\"Usuario Bcrypt\",\"email\":\"${CORREO}\",\"password\":\"${CLAVE}\"}"
ID_UNO=$(capturar_id "$CORREO")
if [ -z "$ID_UNO" ]; then
  echo "    FALLO DEL GUION: no se pudo crear la cuenta de prueba o capturar su id."
  echo "    Se aborta. Si el registro dio 201, la cuenta queda en la base: $CORREO"
  limpieza
  exit 1
fi
CUENTAS+=("$ID_UNO $CORREO")

# --------------------------------------------------------------
echo ""
echo "--- 2. Que quedo guardado en la base de datos"
app -x -c "
SELECT
  email                                   AS correo,
  password_hash                           AS hash_guardado,
  length(password_hash)                   AS largo_del_hash,
  left(password_hash, 7)                  AS prefijo,
  (password_hash ~ '^\\\$2[aby]\\\$[0-9]{2}\\\$') AS cumple_el_check_de_bcrypt,
  strpos(password_hash, '${CLAVE}')       AS posicion_de_la_clave_en_el_hash
FROM users
WHERE email = '${CORREO}';"

echo "    NOTA: posicion_de_la_clave_en_el_hash = 0 significa 'no aparece'."
echo "          La contrasena en claro no esta en ninguna parte de la fila."

# --------------------------------------------------------------
echo ""
echo "--- 3. La base de datos rechaza una contrasena en texto plano"
echo "    (INSERT directo con las credenciales REALES de la aplicacion)"
# Aqui el error ES el resultado: psql debe terminar con codigo 1. Con 0
# la fila habria entrado (y se borra en la limpieza); con 2, no conecto.
comprobar 1 psql_app -c "
INSERT INTO users (name, email, password_hash)
VALUES ('Fulano', 'texto.plano@ejemplo.com', 'MiClaveEnTextoPlano123');"
ID_PLANO=$(capturar_id 'texto.plano@ejemplo.com')
[ -n "$ID_PLANO" ] && CUENTAS+=("$ID_PLANO texto.plano@ejemplo.com")

# --------------------------------------------------------------
echo ""
echo "--- 4. Dos hashes de la MISMA contrasena son distintos (salt aleatorio)"
CORREO_DOS="evidencia.bcrypt.dos.$(date +%H%M%S)@ejemplo.com"
curl -s -o /dev/null -X POST "$U" -H "Content-Type: application/json" \
  -d "{\"name\":\"Usuario Bcrypt Dos\",\"email\":\"${CORREO_DOS}\",\"password\":\"${CLAVE}\"}"
ID_DOS=$(capturar_id "$CORREO_DOS")
if [ -n "$ID_DOS" ]; then
  CUENTAS+=("$ID_DOS $CORREO_DOS")
else
  echo "    FALLO DEL GUION: no se pudo crear la segunda cuenta; esta medida no vale."
  FALLOS=$((FALLOS + 1))
fi
app -c "
SELECT email AS correo, left(password_hash, 29) AS prefijo_y_salt
FROM users
WHERE email LIKE 'evidencia.bcrypt%'
ORDER BY created_at;"

trap - INT TERM
limpieza

echo ""
echo "==============================================================="
echo " Esperado:"
echo "   2 -> prefijo \$2b\$12\$ , largo 60 , check=t , posicion=0"
echo "   3 -> ERROR: viola la restriccion users_password_hash_is_bcrypt"
echo "   4 -> los dos salt son DISTINTOS pese a ser la misma contrasena"
echo "   Limpieza -> 2 cuentas borradas; cuentas_que_quedan = 0"
echo "==============================================================="
echo ""
if [ "$FALLOS" -gt 0 ]; then
  echo " RESULTADO DEL GUION: ${FALLOS} medida(s) no se pudieron hacer"
  echo " (ver FALLO DEL GUION). Esta salida NO vale como evidencia."
  exit 1
fi
echo " RESULTADO DEL GUION: todas las medidas se hicieron."
