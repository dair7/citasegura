#!/usr/bin/env bash
# ---------------------------------------------------------------
#  CitaSegura - Evidencia de CITA-10 (bloqueo por intentos fallidos)
#  Uso:  bash evidencia-cita10.sh
#  Requiere: app corriendo en localhost:3001, psql y .env.local
#
#  Las consultas se hacen como citasegura_app con la DATABASE_URL de
#  .env.local, que NUNCA se imprime. La limpieza final se hace como
#  'postgres', por id capturado Y correo exacto; su contrasena se toma
#  de DB_PASSWORD o, si no existe, de PGPASSWORD.
#
#  SECRETOS: donde se imprime una cabecera Set-Cookie, el valor del
#  token se sustituye por <OCULTO>.
#
#  Si alguna consulta no se puede hacer, el error queda en la propia
#  salida (no solo en la pantalla) y el guion termina con codigo 1.
# ---------------------------------------------------------------

PSQL="/c/Program Files/PostgreSQL/18/bin/psql.exe"
BASE="http://localhost:3001/api/auth"
H="Content-Type: application/json"
CLAVE="ClaveEvidencia1!"
CORREO="evidencia.bloqueo.$(date +%H%M%S)@ejemplo.com"
DIR=$(cd "$(dirname "$0")" && pwd)
RAIZ=$(cd "$DIR/../.." && pwd)

# Se comprueba ANTES de empezar: sin la contrasena de postgres la
# limpieza fallaria al final y dejaria la cuenta de prueba en la base.
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

if [ "$(curl -s -o /dev/null -w '%{http_code}' "$BASE/me")" != "401" ]; then
  echo "La aplicacion no responde en localhost:3001."
  echo "Arrancala con: pnpm dev --webpack --port 3001"
  exit 1
fi

# El descriptor 3 es siempre la salida del guion, aunque quien llama
# descarte la suya (los UPDATE de preparacion van a /dev/null): por ahi
# se avisa de un fallo.
exec 3>&1
FALLOS=0

# El rol REAL de la aplicacion: lo que se demuestra es lo que ella puede hacer.
psql_app()   { PGPASSWORD= "$PSQL" "$APP_URL" -w "$@"; }
# Mantenimiento: conexion como superusuario, SOLO para capturar el id y
# para la limpieza. citasegura_app no tiene DELETE sobre users (ver
# db/roles.sql): borrar cuentas no es una operacion de la aplicacion, y
# no se le concede un permiso solo para que este script pueda limpiar
# lo que crea.
psql_admin() { PGPASSWORD="$ADMIN_PASS" "$PSQL" -h 127.0.0.1 -U postgres -d citasegura -w "$@"; }

# comprobar CODIGO_ESPERADO orden...
# Ejecuta la orden con la salida de errores unida a la normal, para que
# un fallo de psql quede en el fichero guardado con tee y no solo en la
# pantalla. Si el codigo no es el esperado, lo dice en la salida y lo
# cuenta, para que el guion termine con codigo 1.
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

db()    { comprobar 0 psql_app   -t -A -F' | ' -c "$1"; }
admin() { comprobar 0 psql_admin -t -A -F' | ' -c "$1"; }

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

# El mismo filtro que los guiones de CITA-16: el valor de la cookie no
# llega a la salida. Sin el, el corte a 90 caracteres del paso 4 dejaba
# ver el token entero, y esa sesion sigue viva hasta la limpieza.
ocultar_cookie() { sed -E 's/^([Ss]et-[Cc]ookie: [^=]+=)[^;]+/\1<OCULTO>/'; }

estado() {
  printf "    estado -> "
  db "SELECT 'intentos=' || failed_attempts,
             CASE WHEN locked_until IS NULL THEN 'sin bloqueo'
                  WHEN locked_until > now() THEN 'BLOQUEADA hasta ' || to_char(locked_until,'HH24:MI:SS')
                  ELSE 'bloqueo vencido' END
        FROM users WHERE email = '${CORREO}';"
}

intento() {
  local clave="$1" etiqueta="$2"
  local r
  r=$(curl -s -o /dev/null -w '%{http_code} %{time_total}' \
      -X POST "$BASE/login" -H "$H" \
      -d "{\"email\":\"${CORREO}\",\"password\":\"${clave}\"}")
  echo "  ${etiqueta} -> HTTP ${r}s"
  estado
}

LIMPIADO=0
limpieza() {
  [ "$LIMPIADO" = 1 ] && return
  LIMPIADO=1
  echo ""
  echo "--- 7. Limpieza (como postgres: es mantenimiento, no la aplicacion)"
  if [ -z "$UID_PRUEBA" ]; then
    echo "    No se capturo ningun id: no hay cuenta de prueba que borrar."
    return
  fi
  # Por el id capturado Y el correo exacto, nunca por un patron: antes
  # se borraba con LIKE 'evidencia.%@ejemplo.com', que se llevaba
  # cualquier otra cuenta con ese prefijo.
  admin "DELETE FROM users WHERE id = '${UID_PRUEBA}' AND email = '${CORREO}' RETURNING email;"
  printf "    cuentas que quedan con ese id -> "
  admin "SELECT count(*) FROM users WHERE id = '${UID_PRUEBA}';"
}
trap 'limpieza; exit 130' INT TERM

# Solo si la salida es una terminal: redirigida a un fichero, clear
# meteria secuencias de escape en la evidencia.
[ -t 1 ] && clear
echo "==============================================================="
echo " CITA-10  Bloqueo de cuenta por intentos fallidos"
echo " Politica: 5 fallos consecutivos -> 15 minutos de bloqueo"
echo " Fecha: $(date '+%Y-%m-%d %H:%M:%S')"
echo "==============================================================="

echo ""
echo "--- 0. Cuenta de prueba"
curl -s -o /dev/null -w '>> registro HTTP %{http_code}\n' \
  -X POST "$BASE/register" -H "$H" \
  -d "{\"name\":\"Usuario Bloqueo\",\"email\":\"${CORREO}\",\"password\":\"${CLAVE}\"}"
UID_PRUEBA=$(capturar_id "$CORREO")
if [ -z "$UID_PRUEBA" ]; then
  echo "    FALLO DEL GUION: no se pudo crear la cuenta de prueba o capturar su id."
  echo "    Se aborta. Si el registro dio 201, la cuenta queda en la base: $CORREO"
  exit 1
fi
estado

# --------------------------------------------------------------
echo ""
echo "--- 1. El contador sube con cada fallo; al quinto se bloquea"
for i in 1 2 3 4 5; do
  intento "ClaveMala${i}X!" "fallo $i"
done

# --------------------------------------------------------------
echo ""
echo "--- 2. Con la cuenta bloqueada, la contrasena CORRECTA es rechazada"
echo "    (se envia la clave verdadera y se cuentan las cabeceras Set-Cookie)"
curl -s -i -X POST "$BASE/login" -H "$H" \
  -d "{\"email\":\"${CORREO}\",\"password\":\"${CLAVE}\"}" \
  | grep -icE '^set-cookie' | xargs -I{} echo "    cabeceras Set-Cookie recibidas: {}"
curl -s -X POST "$BASE/login" -H "$H" \
  -d "{\"email\":\"${CORREO}\",\"password\":\"${CLAVE}\"}" \
  -w '\n    >> HTTP %{http_code}\n'

# --------------------------------------------------------------
echo ""
echo "--- 3. Insistir durante el bloqueo NO lo alarga"
for i in 1 2 3; do
  intento "OtraClaveMala${i}!" "golpe extra $i"
done

# --------------------------------------------------------------
echo ""
echo "--- 4. Vencido el bloqueo se entra, y el login correcto reinicia"
echo "    (se adelanta locked_until al pasado para simular los 15 min)"
db "UPDATE users SET locked_until = now() - interval '1 second' WHERE email = '${CORREO}';" > /dev/null
estado
echo ""
echo "  login con la contrasena CORRECTA:"
curl -s -i -X POST "$BASE/login" -H "$H" \
  -d "{\"email\":\"${CORREO}\",\"password\":\"${CLAVE}\"}" \
  | grep -iE '^HTTP|^set-cookie' | ocultar_cookie | cut -c1-90
estado

# --------------------------------------------------------------
echo ""
echo "--- 5. Tras un bloqueo vencido, un fallo abre ventana NUEVA (1, no 6)"
db "UPDATE users SET failed_attempts = 5, locked_until = now() - interval '1 minute' WHERE email = '${CORREO}';" > /dev/null
echo "    preparado con intentos=5 y bloqueo ya vencido:"
estado
intento "ClaveMalaNueva!" "un fallo"

# --------------------------------------------------------------
echo ""
echo "--- 6. El bloqueo no delata si la cuenta existe (tiempos)"
db "UPDATE users SET failed_attempts = 5, locked_until = now() + interval '15 minutes' WHERE email = '${CORREO}';" > /dev/null
echo "    cuenta dejada BLOQUEADA para la medicion"
echo ""
for i in 1 2 3; do
  A=$(curl -s -o /dev/null -w '%{time_total}' -X POST "$BASE/login" -H "$H" \
      -d "{\"email\":\"${CORREO}\",\"password\":\"${CLAVE}\"}")
  B=$(curl -s -o /dev/null -w '%{time_total}' -X POST "$BASE/login" -H "$H" \
      -d "{\"email\":\"no.existe.$i@ejemplo.com\",\"password\":\"${CLAVE}\"}")
  C=$(curl -s -o /dev/null -w '%{time_total}' -X POST "$BASE/login" -H "$H" \
      -d '{"email":"no-es-correo","password":"x"}')
  echo "  medicion $i -> BLOQUEADA: ${A}s | NO EXISTE: ${B}s | sin bcrypt: ${C}s"
done

# --------------------------------------------------------------
trap - INT TERM
limpieza

echo ""
echo "==============================================================="
echo " Esperado:"
echo "   1 -> contador 1..5; al 5 aparece el bloqueo. Las 5 respuestas"
echo "        son IDENTICAS: el cliente nunca sabe cuantas le quedan"
echo "   2 -> 401 con la clave correcta y 0 cabeceras Set-Cookie"
echo "   3 -> locked_until NO cambia y el contador sigue en 5"
echo "   4 -> 200 con cookie; estado queda en intentos=0 sin bloqueo"
echo "   5 -> intentos=1, no 6"
echo "   6 -> BLOQUEADA y NO EXISTE similares; sin bcrypt mucho menor"
echo "   7 -> 1 cuenta borrada (la de este guion); quedan 0"
echo "==============================================================="
echo ""
if [ "$FALLOS" -gt 0 ]; then
  echo " RESULTADO DEL GUION: ${FALLOS} medida(s) no se pudieron hacer"
  echo " (ver FALLO DEL GUION). Esta salida NO vale como evidencia."
  exit 1
fi
echo " RESULTADO DEL GUION: todas las medidas se hicieron."
