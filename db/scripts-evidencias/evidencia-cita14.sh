#!/usr/bin/env bash
# ---------------------------------------------------------------
#  CitaSegura - Evidencia de CITA-14 (validacion y sanitizacion en
#  el servidor)
#  Uso:  bash evidencia-cita14.sh | tee salida-cita14.txt
#  Requiere: app corriendo en localhost:3001, psql, node y .env.local
#
#  CITA-12 ya probo con curl las claves userId y status, la fecha
#  pasada, el motivo de 501 caracteres, el motivo en blanco y que los
#  rechazos no dejan filas (salida-cita12.txt, 2.1 a 2.10). Este
#  script NO lo repite:
#
#    1. La validacion no depende del navegador: lo que CITA-12 no
#       probo, y que las claves sobrantes reciben respuestas
#       IDENTICAS, sin eco de lo enviado.
#    2. Fecha en el pasado en las dos capas: el esquema en la API y
#       el CHECK de la tabla, este ultimo saltandose el esquema.
#    3. El texto se guarda literal y se escapa al mostrarse.
#
#  Registra DOS cuentas propias: A para los bloques 1 a 3, y N, con
#  un nombre que es codigo HTML, para el bloque 3. Se borran al final
#  como 'postgres', por id capturado Y correo exacto. La contrasena
#  de postgres se toma de DB_PASSWORD o, si no existe, de PGPASSWORD.
#  El bloque 2 se conecta como citasegura_app con la DATABASE_URL de
#  .env.local, que NUNCA se imprime.
# ---------------------------------------------------------------

PSQL="/c/Program Files/PostgreSQL/18/bin/psql.exe"
WEB="http://localhost:3001"
BASE="$WEB/api"
H="Content-Type: application/json"
CLAVE="ClaveEvidencia1!"
SUFIJO=$(date +%H%M%S)
CORREO_A="prueba.cita14.a.${SUFIJO}@ejemplo.com"
CORREO_N="prueba.cita14.n.${SUFIJO}@ejemplo.com"
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

if [ "$(curl -s -o /dev/null -w '%{http_code}' "$BASE/auth/me")" != "401" ]; then
  echo "La aplicacion no responde en localhost:3001."
  echo "Arrancala con: pnpm dev --webpack --port 3001"
  exit 1
fi

TMP=$(mktemp -d)
JAR_A="$TMP/a.jar"
JAR_N="$TMP/n.jar"

# Superusuario: solo para LEER lo que la API no muestra y para limpiar.
admin()  { PGPASSWORD="$ADMIN_PASS" "$PSQL" -h 127.0.0.1 -U postgres -d citasegura "$@" 2>&1; }
# El rol REAL de la aplicacion: lo que se demuestra es lo que ella puede hacer.
app()    { PGPASSWORD= "$PSQL" "$APP_URL" -w "$@" 2>&1; }

LIMPIADO=0
limpieza() {
  [ "$LIMPIADO" = 1 ] && return
  LIMPIADO=1
  echo ""
  echo "==============================================================="
  echo " LIMPIEZA (como postgres: es mantenimiento, no la aplicacion)"
  echo "==============================================================="
  # Por los ids capturados Y el correo exacto, nunca por un patron.
  local ids=()
  [ -n "$UID_A" ] && ids+=("'${UID_A}'")
  [ -n "$UID_N" ] && ids+=("'${UID_N}'")
  if [ ${#ids[@]} -eq 0 ]; then
    echo "  No se capturo ningun id: no hay cuentas de prueba que borrar."
    rm -rf "$TMP"
    return
  fi
  local lista
  lista=$(IFS=,; echo "${ids[*]}")
  admin -c "DELETE FROM users
             WHERE id IN (${lista})
               AND email IN ('${CORREO_A}', '${CORREO_N}')
            RETURNING id, email;" | sed 's/^/  /'
  admin -c "SELECT (SELECT count(*) FROM users        WHERE id      IN (${lista})) AS cuentas,
                   (SELECT count(*) FROM appointments WHERE user_id IN (${lista})) AS citas,
                   (SELECT count(*) FROM sessions     WHERE user_id IN (${lista})) AS sesiones;" \
    | sed 's/^/  /'
  rm -rf "$TMP"
}
trap 'limpieza; exit 130' INT TERM

registrar() {  # registrar CORREO NOMBRE VARIABLE
  curl -s -o /dev/null -w "    registro de $1 -> HTTP %{http_code}\n" \
    -X POST "$BASE/auth/register" -H "$H" \
    -d "{\"name\":\"$2\",\"email\":\"$1\",\"password\":\"${CLAVE}\"}"
  printf -v "$3" '%s' "$(admin -t -A -c "SELECT id FROM users WHERE email = '$1';")"
  echo "      id capturado: ${!3:-NINGUNO}"
}

entrar() {  # entrar CORREO JAR
  curl -s -o /dev/null -c "$2" -w "    login de $1 -> HTTP %{http_code}\n" \
    -X POST "$BASE/auth/login" -H "$H" -d "{\"email\":\"$1\",\"password\":\"${CLAVE}\"}"
}

# crear ETIQUETA CUERPO FICHERO: POST /api/citas con la sesion de A.
# Imprime el codigo y el cuerpo, y deja el cuerpo en FICHERO.
crear() {
  local codigo
  codigo=$(curl -s -o "$3" -w '%{http_code}' -X POST "$BASE/citas" \
             -b "$JAR_A" -H "$H" --data-binary "$2")
  printf '  %-28s -> HTTP %s  %s\n' "$1" "$codigo" "$(cat "$3")"
}

citas_de_a() { admin -t -A -c "SELECT count(*) FROM appointments WHERE user_id = '${UID_A}';"; }

# Fechas con ZONA HORARIA explicita (-05:00, Colombia), que es lo que
# exige el esquema.
FUTURA=$(date -d '+3 days' +%Y-%m-%dT10:00:00-05:00)
AYER=$(date -d '-1 days' +%Y-%m-%dT10:00:00-05:00)

[ -t 1 ] && clear
echo "==============================================================="
echo " CITA-14  Validacion y sanitizacion en el servidor"
echo " Fecha: $(date '+%Y-%m-%d %H:%M:%S')"
echo "==============================================================="

echo ""
echo "--- Preparacion: cuenta A (bloques 1 a 3) y cuenta N (bloque 3)"
registrar "$CORREO_A" "Prueba Cita14" UID_A
registrar "$CORREO_N" "<script>alert(1)</script>" UID_N
entrar "$CORREO_A" "$JAR_A"
entrar "$CORREO_N" "$JAR_N"
if [ -z "$UID_A" ] || [ -z "$UID_N" ]; then
  echo "  No se pudieron crear las dos cuentas de prueba. Se aborta."
  limpieza
  exit 1
fi

# --------------------------------------------------------------
echo ""
echo "==============================================================="
echo " 1. LA VALIDACION NO DEPENDE DEL NAVEGADOR"
echo "==============================================================="
echo "  curl directo a POST /api/citas, sin formulario, con la sesion"
echo "  valida de A. Ya probado en CITA-12 y no repetido: userId,"
echo "  status, 501 caracteres, motivo en blanco (salida-cita12.txt)."
echo ""
ANTES=$(citas_de_a)
crear "falta el motivo" \
  "{\"scheduledAt\":\"${FUTURA}\"}" "$TMP/r-falta"
crear "motivo con tipo numero" \
  "{\"scheduledAt\":\"${FUTURA}\",\"reason\":12345}" "$TMP/r-tipo"

echo ""
echo "  Tres claves no declaradas, con valores de sonda reconocibles:"
echo "    status -> columna real de appointments"
echo "    role   -> columna real de users, no de appointments"
echo "    xyz    -> inventada, no existe en ninguna tabla"
crear "clave status" \
  "{\"scheduledAt\":\"${FUTURA}\",\"reason\":\"x\",\"status\":\"sonda-status-${SUFIJO}\"}" "$TMP/k-status"
crear "clave role" \
  "{\"scheduledAt\":\"${FUTURA}\",\"reason\":\"x\",\"role\":\"sonda-role-${SUFIJO}\"}" "$TMP/k-role"
crear "clave xyz" \
  "{\"scheduledAt\":\"${FUTURA}\",\"reason\":\"x\",\"xyz\":\"sonda-xyz-${SUFIJO}\"}" "$TMP/k-xyz"
echo ""
if cmp -s "$TMP/k-status" "$TMP/k-role" && cmp -s "$TMP/k-role" "$TMP/k-xyz"; then
  echo "  RESULTADO: las tres respuestas son IDENTICAS byte a byte"
else
  echo "  RESULTADO: LAS RESPUESTAS DIFIEREN -- revisar"
fi
# Se busca la clave y su valor en las tres respuestas, sin distinguir
# mayusculas: si alguna apareciera, el error le diria al atacante que
# clave se rechazo.
ECO=$(cat "$TMP"/k-* | grep -o -i -E 'status|role|xyz|sonda' | wc -l)
echo "  claves o valores enviados presentes en las respuestas: $ECO"

DESPUES=$(citas_de_a)
echo ""
echo "  Citas de A en la base: antes ${ANTES}, despues ${DESPUES}"
if [ -n "$ANTES" ] && [ "$ANTES" = "$DESPUES" ]; then
  echo "  RESULTADO: ningun rechazo dejo fila"
else
  echo "  RESULTADO: EL NUMERO DE FILAS CAMBIO -- algun rechazo se guardo"
fi

# --------------------------------------------------------------
echo ""
echo "==============================================================="
echo " 2. FECHA EN EL PASADO, EN LAS DOS CAPAS"
echo "==============================================================="
echo "  Fecha de ayer: ${AYER}"
echo ""
echo "  a) Por la API: la frena el esquema"
crear "cita con fecha de ayer" \
  "{\"scheduledAt\":\"${AYER}\",\"reason\":\"Cita en el pasado por la API\"}" "$TMP/r-ayer"
echo "     citas de A en la base: $(citas_de_a)"
echo ""
echo "  b) Saltandose el esquema: el mismo dato por SQL directo,"
echo "     como citasegura_app (permiso INSERT en las tres columnas)"
app -c "INSERT INTO appointments (user_id, scheduled_at, reason)
        VALUES ('${UID_A}', '${AYER}', 'Cita en el pasado por SQL')
        RETURNING id;" | sed 's/^/     /'
echo "     citas de A en la base: $(citas_de_a)"

# --------------------------------------------------------------
echo ""
echo "==============================================================="
echo " 3. EL TEXTO SE GUARDA LITERAL Y SE ESCAPA AL MOSTRARSE"
echo "==============================================================="
M1='<script>alert(1)</script>'
M2='<img src=x onerror=alert(1)>'
echo ""
echo "  3.1 Dos citas con HTML en el motivo"
crear "motivo <script>" \
  "{\"scheduledAt\":\"${FUTURA}\",\"reason\":\"${M1}\"}" "$TMP/c1"
crear "motivo <img onerror>" \
  "{\"scheduledAt\":\"${FUTURA}\",\"reason\":\"${M2}\"}" "$TMP/c2"

echo ""
echo "  3.2 En la base, guardados LITERALES (sin escapar ni filtrar)"
admin -c "SELECT reason,
                 reason IN ('${M1}', '${M2}') AS identico_al_enviado
            FROM appointments
           WHERE user_id = '${UID_A}'
           ORDER BY created_at;" | sed 's/^/  /'

echo "  3.3 En el JSON de GET /api/citas: crudos, que es lo correcto"
curl -s -D "$TMP/cab" -o "$TMP/lista" -b "$JAR_A" "$BASE/citas"
echo "    content-type:           $(grep -i '^content-type:' "$TMP/cab" | cut -d' ' -f2- | tr -d '\r')"
NOSNIFF=$(grep -i '^x-content-type-options:' "$TMP/cab" | cut -d' ' -f2- | tr -d '\r')
echo "    x-content-type-options: ${NOSNIFF:-(ausente)}"
echo "    '${M1}' crudo:      $(grep -o -F "$M1" "$TMP/lista" | wc -l)"
echo "    '${M2}' crudo:   $(grep -o -F "$M2" "$TMP/lista" | wc -l)"
echo "    entidades HTML (&lt;):              $(grep -o -F '&lt;' "$TMP/lista" | wc -l)"

echo ""
echo "  3.4 Nada en src/ inserta HTML sin escapar"
echo "    dangerouslySetInnerHTML: $(grep -r -o -F 'dangerouslySetInnerHTML' "$RAIZ/src" | wc -l) usos"
echo "    innerHTML / outerHTML:   $(grep -r -o -E '(inner|outer)HTML' "$RAIZ/src" | wc -l) usos"

echo ""
echo "  3.5 El nombre de N en el HTML de /inicio (Server Component)"
echo "    nombre guardado: $(admin -t -A -c "SELECT name FROM users WHERE id = '${UID_N}';")"
CODIGO=$(curl -s -o "$TMP/inicio" -w '%{http_code}' -b "$JAR_N" "$WEB/inicio")
echo "    GET /inicio con la sesion de N -> HTTP $CODIGO"
echo "    '<script>alert(1)</script>' crudo:                $(grep -o -F "$M1" "$TMP/inicio" | wc -l)"
echo "    escapado como texto (&lt;script&gt;...):          $(grep -o -F '&lt;script&gt;alert(1)&lt;/script&gt;' "$TMP/inicio" | wc -l)"
# Next incrusta tambien los datos de React en un <script>; ahi el
# nombre va como texto JSON con los < escritos \u003c. Se construye
# el patron con una barra suelta para no escribir la secuencia literal.
B='\'
EN_REACT="${B}u003cscript${B}u003ealert(1)${B}u003c/script${B}u003e"
echo "    escapado en los datos de React (\u003cscript...): $(grep -o -F "$EN_REACT" "$TMP/inicio" | wc -l)"
echo "    donde aparece, tal como llega al navegador:"
grep -o -E '.{0,30}&lt;script&gt;alert\(1\)&lt;/script&gt;.{0,10}' "$TMP/inicio" | head -1 | sed 's/^/      /'

# --------------------------------------------------------------
trap - INT TERM
limpieza

echo ""
echo "==============================================================="
echo " Esperado:"
echo "   1 -> HTTP 400 en las cinco; falta y tipo con el error en"
echo "        'reason'; status, role y xyz con la MISMA respuesta byte"
echo "        a byte, 'errors':{} y 0 claves o valores devueltos;"
echo "        citas de A: 0 antes y 0 despues"
echo "   2 -> a) HTTP 400 del esquema en 'scheduledAt', 0 citas"
echo "        b) ERROR del CHECK appointments_agendada_despues_de_crearse,"
echo "           0 citas"
echo "   3 -> 3.1 HTTP 201 en las dos; 3.2 motivos identicos a lo"
echo "        enviado (t); 3.3 application/json, cada motivo crudo 1"
echo "        vez y 0 entidades; 3.4 0 usos; 3.5 HTTP 200, 0 crudos y"
echo "        el nombre escapado 1 vez como texto y 1 en los datos de React"
echo "   Limpieza -> 2 cuentas borradas; cuentas, citas y sesiones = 0"
echo "==============================================================="
