#!/usr/bin/env bash
# ---------------------------------------------------------------
#  CitaSegura - Evidencia de CITA-9 (login y sesiones propias)
#  Uso:  bash evidencia-cita9.sh
#  Requiere: app corriendo en localhost:3001, psql y .env.local
#
#  Las consultas se hacen como citasegura_app con la DATABASE_URL de
#  .env.local, que NUNCA se imprime. La cuenta de prueba se borra al
#  final como 'postgres', por id capturado Y correo exacto; su
#  contrasena se toma de DB_PASSWORD o, si no existe, de PGPASSWORD.
#
#  SECRETOS: el token de sesion vive solo en los ficheros de cookies
#  del directorio temporal, que se borra al final. Donde se imprime,
#  su valor se sustituye por <OCULTO>.
#
#  Si alguna consulta no se puede hacer, el error queda en la propia
#  salida (no solo en la pantalla) y el guion termina con codigo 1.
# ---------------------------------------------------------------

PSQL="/c/Program Files/PostgreSQL/18/bin/psql.exe"
BASE="http://localhost:3001/api/auth"
H="Content-Type: application/json"
CLAVE="ClaveEvidencia1!"
CORREO="evidencia.sesion.$(date +%H%M%S)@ejemplo.com"
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

if [ "$(curl -s -o /dev/null -w '%{http_code}' "$BASE/me")" != "401" ]; then
  echo "La aplicacion no responde en localhost:3001."
  echo "Arrancala con: pnpm dev --webpack --port 3001"
  exit 1
fi

# Las cookies, fuera del arbol de trabajo: llevan el token en claro.
TMP=$(mktemp -d)
JAR="$TMP/jar-evidencia.txt"
JAR_ANTES="$TMP/jar-antes-del-logout.txt"

# El descriptor 3 es siempre la salida del guion, aunque quien llama
# descarte la suya: por ahi se avisa de un fallo.
exec 3>&1
FALLOS=0

# El rol REAL de la aplicacion: lo que se demuestra es lo que ella puede hacer.
psql_app()   { PGPASSWORD= "$PSQL" "$APP_URL" -w "$@"; }
# Superusuario: solo para capturar el id y para limpiar.
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

# El mismo filtro que los guiones de CITA-16: el valor de la cookie no
# llega a la salida; los flags, que son lo que se prueba, si. Solo se
# tapa un valor no vacio: el del logout llega vacio, y eso es evidencia.
ocultar_cookie() { sed -E 's/^([Ss]et-[Cc]ookie: [^=]+=)[^;]+/\1<OCULTO>/'; }

LIMPIADO=0
limpieza() {
  [ "$LIMPIADO" = 1 ] && return
  LIMPIADO=1
  echo ""
  echo "--- Limpieza (como postgres: es mantenimiento, no la aplicacion)"
  if [ -z "$UID_PRUEBA" ]; then
    echo "    No se capturo ningun id: no hay cuenta de prueba que borrar."
  else
    # Por el id capturado Y el correo exacto, nunca por un patron. Sus
    # sesiones caen con ella (ON DELETE CASCADE).
    comprobar 0 psql_admin -c "DELETE FROM users
               WHERE id = '${UID_PRUEBA}' AND email = '${CORREO}'
              RETURNING id, email;"
    comprobar 0 psql_admin -c "SELECT
               (SELECT count(*) FROM users    WHERE id      = '${UID_PRUEBA}') AS cuentas,
               (SELECT count(*) FROM sessions WHERE user_id = '${UID_PRUEBA}') AS sesiones;"
  fi
  rm -rf "$TMP"
}
trap 'limpieza; exit 130' INT TERM

# Solo si la salida es una terminal: redirigida a un fichero, clear
# meteria secuencias de escape en la evidencia.
[ -t 1 ] && clear
echo "==============================================================="
echo " CITA-9  Logica de login y sesiones propias"
echo " Fecha: $(date '+%Y-%m-%d %H:%M:%S')"
echo "==============================================================="

# --------------------------------------------------------------
echo ""
echo "--- 0. Cuenta de prueba para esta evidencia"
curl -s -o /dev/null -w '>> registro HTTP %{http_code}\n' \
  -X POST "$BASE/register" -H "$H" \
  -d "{\"name\":\"Usuario Sesion\",\"email\":\"${CORREO}\",\"password\":\"${CLAVE}\"}"
UID_PRUEBA=$(capturar_id "$CORREO")
if [ -z "$UID_PRUEBA" ]; then
  echo "    FALLO DEL GUION: no se pudo crear la cuenta de prueba o capturar su id."
  echo "    Se aborta. Si el registro dio 201, la cuenta queda en la base: $CORREO"
  limpieza
  exit 1
fi

# --------------------------------------------------------------
echo ""
echo "--- 1. LOGIN correcto: cabecera Set-Cookie y flags"
curl -s -i -c "$JAR" -X POST "$BASE/login" -H "$H" \
  -d "{\"email\":\"${CORREO}\",\"password\":\"${CLAVE}\"}" \
  | grep -iE '^HTTP|^set-cookie|^\{' | ocultar_cookie

TOKEN=$(grep citasegura_session "$JAR" | awk '{print $7}')
echo ""
echo "    Token recibido en la cookie: <OCULTO>"
echo "    Longitud: ${#TOKEN} caracteres"

# --------------------------------------------------------------
echo ""
echo "--- 2. En la tabla 'sessions' el token esta HASHEADO (SHA-256)"
SHA=$(printf '%s' "$TOKEN" | sha256sum | awk '{print $1}')
echo "    SHA-256 calculado FUERA de la base: $SHA"
app -x -c "
SELECT
  s.id                        AS id_guardado_en_la_base,
  length(s.id)                AS largo,
  (s.id = '${SHA}')           AS coincide_con_el_sha256_del_token,
  (s.id = '${TOKEN}')         AS contiene_el_token_en_claro,
  u.email                     AS propietario,
  s.expires_at                AS caduca_en
FROM sessions s JOIN users u ON u.id = s.user_id
WHERE u.email = '${CORREO}';"

# --------------------------------------------------------------
echo ""
echo "--- 3. RUTA PROTEGIDA: solo se entra con cookie valida"
echo ""
echo "  a) con la cookie valida"
curl -s -b "$JAR" -w '\n  >> HTTP %{http_code}\n' "$BASE/me"
echo ""
echo "  b) sin cookie"
curl -s -w '\n  >> HTTP %{http_code}\n' "$BASE/me"
echo ""
echo "  c) con un token inventado de la misma longitud"
curl -s -H "Cookie: citasegura_session=$(head -c 32 /dev/urandom | base64 | tr -d '=+/' | head -c ${#TOKEN})" \
  -w '\n  >> HTTP %{http_code}\n' "$BASE/me"

# --------------------------------------------------------------
echo ""
echo "--- 4. LOGOUT: revoca en el SERVIDOR, no solo en el navegador"
cp "$JAR" "$JAR_ANTES"
echo ""
echo "  a) cierre de sesion"
curl -s -i -b "$JAR" -X POST "$BASE/logout" | grep -iE '^HTTP|^set-cookie|^\{' | ocultar_cookie
echo ""
echo "  b) se reenvia la cookie ANTIGUA (token aun valido, sesion revocada)"
curl -s -b "$JAR_ANTES" -w '\n  >> HTTP %{http_code}\n' "$BASE/me"
echo ""
echo "  c) filas que quedan en 'sessions' para esta cuenta"
app -c "
SELECT count(*) AS sesiones_de_la_cuenta
FROM sessions s JOIN users u ON u.id = s.user_id
WHERE u.email = '${CORREO}';"

# --------------------------------------------------------------
echo ""
echo "--- 5. ANTI-ENUMERACION POR TIEMPO en el login"
echo "    (cuenta que existe vs correo inexistente vs sin llegar a bcrypt)"
echo ""
for i in 1 2 3; do
  A=$(curl -s -o /dev/null -w '%{time_total}' -X POST "$BASE/login" -H "$H" \
      -d "{\"email\":\"${CORREO}\",\"password\":\"ClaveIncorrecta9#\"}")
  B=$(curl -s -o /dev/null -w '%{time_total}' -X POST "$BASE/login" -H "$H" \
      -d "{\"email\":\"no.existe.$i@ejemplo.com\",\"password\":\"ClaveIncorrecta9#\"}")
  C=$(curl -s -o /dev/null -w '%{time_total}' -X POST "$BASE/login" -H "$H" \
      -d '{"email":"no-es-correo","password":"x"}')
  echo "  medicion $i -> EXISTE: ${A}s | NO EXISTE: ${B}s | sin bcrypt (Zod): ${C}s"
done

trap - INT TERM
limpieza

echo ""
echo "==============================================================="
echo " Esperado:"
echo "   1 -> 200 con HttpOnly, SameSite=lax y Max-Age"
echo "   2 -> largo 64, coincide=t, en_claro=f"
echo "   3 -> a) 200   b) y c) 401 con el MISMO mensaje"
echo "   4 -> b) 401 pese a token valido   c) 0 sesiones"
echo "   5 -> EXISTE y NO EXISTE similares; sin bcrypt mucho menor"
echo "   Limpieza -> 1 cuenta borrada; cuentas y sesiones = 0"
echo "==============================================================="
echo ""
if [ "$FALLOS" -gt 0 ]; then
  echo " RESULTADO DEL GUION: ${FALLOS} medida(s) no se pudieron hacer"
  echo " (ver FALLO DEL GUION). Esta salida NO vale como evidencia."
  exit 1
fi
echo " RESULTADO DEL GUION: todas las medidas se hicieron."
