#!/usr/bin/env bash
# ---------------------------------------------------------------
#  CitaSegura - Evidencia de CITA-13 (control de acceso y anti-IDOR)
#  Uso:  bash evidencia-cita13.sh
#  Requiere: app corriendo en localhost:3001, psql, node y .env.local
#
#  CITA-12 ya probo el 404 identico, el 401 sin sesion y el listado
#  filtrado por dueño. Este script NO lo repite: verifica lo que alli
#  quedo sin mirar y busca lo que falla.
#
#    1. No hay ningun endpoint que devuelva una cita por su id.
#    2. Cancelar una cita ajena no la cambia, comprobado EN LA BASE.
#    3. Ajena e inexistente tardan lo mismo (sin canal de tiempo).
#    4. Los identificadores no son secuenciales.
#    5. El hallazgo: INSERT de admin antes y despues de acotar el
#       permiso en db/roles.sql.
#
#  Registra DOS cuentas propias (A y B) y las borra al final como
#  'postgres', por id capturado Y correo exacto. La contrasena de
#  postgres se toma de DB_PASSWORD o, si no existe, de PGPASSWORD.
#  El bloque 5 se conecta como citasegura_app con la DATABASE_URL de
#  .env.local, que NUNCA se imprime.
# ---------------------------------------------------------------

PSQL="/c/Program Files/PostgreSQL/18/bin/psql.exe"
BASE="http://localhost:3001/api"
H="Content-Type: application/json"
CLAVE="ClaveEvidencia1!"
SUFIJO=$(date +%H%M%S)
CORREO_A="prueba.cita13.a.${SUFIJO}@ejemplo.com"
CORREO_B="prueba.cita13.b.${SUFIJO}@ejemplo.com"
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
JAR_B="$TMP/b.jar"

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
  [ -n "$UID_B" ] && ids+=("'${UID_B}'")
  if [ ${#ids[@]} -eq 0 ]; then
    echo "  No se capturo ningun id: no hay cuentas de prueba que borrar."
    rm -rf "$TMP"
    return
  fi
  local lista
  lista=$(IFS=,; echo "${ids[*]}")
  admin -c "DELETE FROM users
             WHERE id IN (${lista})
               AND email IN ('${CORREO_A}', '${CORREO_B}')
            RETURNING id, email;" | sed 's/^/  /'
  admin -c "SELECT (SELECT count(*) FROM users        WHERE id      IN (${lista})) AS cuentas,
                   (SELECT count(*) FROM appointments WHERE user_id IN (${lista})) AS citas,
                   (SELECT count(*) FROM sessions     WHERE user_id IN (${lista})) AS sesiones;" \
    | sed 's/^/  /'
  rm -rf "$TMP"
}
trap 'limpieza; exit 130' INT TERM

# Lee un campo del ultimo cuerpo JSON recibido.
campo() {
  node -e '
    const datos = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
    const valor = process.argv[2].split(".").reduce((o, k) => o?.[k], datos);
    console.log(typeof valor === "object" ? JSON.stringify(valor) : (valor ?? ""));
  ' "$TMP/cuerpo" "$1"
}

registrar() {
  curl -s -o /dev/null -w "    registro de $1 -> HTTP %{http_code}\n" \
    -X POST "$BASE/auth/register" -H "$H" \
    -d "{\"name\":\"Prueba Cita13\",\"email\":\"$1\",\"password\":\"${CLAVE}\"}"
  printf -v "$2" '%s' "$(admin -t -A -c "SELECT id FROM users WHERE email = '$1';")"
  echo "      id capturado: ${!2:-NINGUNO}"
}

crear_cita() {  # crear_cita JAR DIAS MOTIVO -> deja el id en CITA
  curl -s -o "$TMP/cuerpo" -X POST "$BASE/citas" -b "$1" -H "$H" \
    -d "{\"scheduledAt\":\"$(date -d "+$2 days" +%Y-%m-%dT10:00:00-05:00)\",\"reason\":\"$3\"}"
  CITA=$(campo cita.id)
}

UUID_INVENTADO=$(node -e 'console.log(crypto.randomUUID())')

[ -t 1 ] && clear
echo "==============================================================="
echo " CITA-13  Control de acceso y anti-IDOR"
echo " Fecha: $(date '+%Y-%m-%d %H:%M:%S')"
echo "==============================================================="

echo ""
echo "--- Preparacion: dos cuentas (A y B); B tiene la cita AJENA"
registrar "$CORREO_A" UID_A
registrar "$CORREO_B" UID_B
curl -s -o /dev/null -c "$JAR_A" -w "    login A -> HTTP %{http_code}\n" \
  -X POST "$BASE/auth/login" -H "$H" -d "{\"email\":\"${CORREO_A}\",\"password\":\"${CLAVE}\"}"
curl -s -o /dev/null -c "$JAR_B" -w "    login B -> HTTP %{http_code}\n" \
  -X POST "$BASE/auth/login" -H "$H" -d "{\"email\":\"${CORREO_B}\",\"password\":\"${CLAVE}\"}"
if [ -z "$UID_A" ] || [ -z "$UID_B" ]; then
  echo "  No se pudieron crear las dos cuentas de prueba. Se aborta."
  limpieza
  exit 1
fi
crear_cita "$JAR_B" 4 "Cita privada de B"
CITA_B=$CITA
echo "    cita de B: $CITA_B"

# --------------------------------------------------------------
echo ""
echo "==============================================================="
echo " 1. NINGUN ENDPOINT DEVUELVE UNA CITA POR SU IDENTIFICADOR"
echo "==============================================================="
echo "  A pide la cita de B por su id, y un id que no existe."
echo "  Si existiera GET /api/citas/[id], aqui estaria el IDOR."
echo ""
for par in "ajena:${CITA_B}" "inexistente:${UUID_INVENTADO}"; do
  etiqueta=${par%%:*}; id=${par#*:}
  for metodo in GET PATCH DELETE; do
    r=$(curl -s -b "$JAR_A" -o "$TMP/r-$etiqueta-$metodo" -X "$metodo" \
          -w '%{http_code} %{content_type}' "$BASE/citas/$id")
    printf '  %-6s /citas/<%s>%*s -> HTTP %s\n' "$metodo" "$etiqueta" $((12 - ${#etiqueta})) '' "$r"
  done
done
r=$(curl -s -b "$JAR_A" -o /dev/null -w '%{http_code}' "$BASE/citas/${CITA_B}/cancelar")
printf '  %-6s /citas/<ajena>/cancelar -> HTTP %s  (cancelar solo admite POST)\n' GET "$r"
echo ""
echo "  ¿la respuesta a la ajena contiene algun dato que solo esta en la base?"
echo "    su motivo:                      $(grep -c 'Cita privada de B' "$TMP/r-ajena-GET") coincidencias"
echo "    campos de cita (scheduledAt...): $(grep -cE 'scheduledAt|\"reason\"|\"status\"' "$TMP/r-ajena-GET") coincidencias"

# La pagina 404 de Next NO es identica byte a byte ni entre dos
# peticiones a la MISMA url: en modo desarrollo lleva una marca de
# cache (?v=<milisegundos>) y un token aleatorio por peticion
# (__next_r). Ademas repite la ruta pedida, asi que el id aparece en
# la respuesta: es lo que escribio quien hizo la peticion, no un dato
# leido de la base. Se normalizan esas tres cosas y se compara el resto.
normalizar() {
  sed -e "s/$2/<ID-PEDIDO>/g" \
      -e 's/?v=[0-9]*/?v=<MARCA>/g' \
      -e 's/__next_r="[^"]*"/__next_r="<TOKEN>"/g' "$1"
}
normalizar "$TMP/r-ajena-GET"       "$CITA_B"         > "$TMP/n-ajena"
normalizar "$TMP/r-inexistente-GET" "$UUID_INVENTADO" > "$TMP/n-inexistente"
if cmp -s "$TMP/n-ajena" "$TMP/n-inexistente"; then
  echo "  RESULTADO: ajena e inexistente reciben la MISMA pagina 404 (salvo la"
  echo "             ruta pedida y los dos valores por peticion de Next):"
  echo "             la ruta no existe, para ningun id"
else
  echo "  RESULTADO: LAS RESPUESTAS DIFIEREN -- revisar"
fi

# --------------------------------------------------------------
echo ""
echo "==============================================================="
echo " 2. CANCELAR LA CITA AJENA NO CAMBIA NADA, VISTO EN LA BASE"
echo "==============================================================="
# La huella es el md5 de la fila completa: si cambiara cualquier
# columna (estado, fecha, motivo, dueño), cambiaria la huella.
huella() {
  admin -t -A -F ' | ' -c "SELECT status, md5(a::text) FROM appointments a WHERE id = '${CITA_B}';"
}
ANTES=$(huella)
echo "  en la base, ANTES:   $ANTES"
curl -s -b "$JAR_A" -o "$TMP/cuerpo" -X POST \
  -w "  A cancela la cita de B -> HTTP %{http_code}  " "$BASE/citas/${CITA_B}/cancelar"
cat "$TMP/cuerpo"; echo ""
DESPUES=$(huella)
echo "  en la base, DESPUES: $DESPUES"
if [ -n "$ANTES" ] && [ "$ANTES" = "$DESPUES" ]; then
  echo "  RESULTADO: la fila de B esta INTACTA (mismo estado, misma huella)"
else
  echo "  RESULTADO: LA FILA CAMBIO -- el control de acceso fallo"
fi

# --------------------------------------------------------------
echo ""
echo "==============================================================="
echo " 3. AJENA E INEXISTENTE TARDAN LO MISMO"
echo "==============================================================="
# Mismo camino de codigo en los dos casos: UPDATE con 0 filas y
# SELECT de propiedad con 0 filas. Si la ajena tardara mas, el tiempo
# delataria que la cita existe. Se alternan las peticiones para que
# el ruido del equipo afecte por igual a ambas, y una peticion previa
# sin contar evita medir la compilacion del modo desarrollo.
curl -s -o /dev/null -b "$JAR_A" -X POST "$BASE/citas/${UUID_INVENTADO}/cancelar"
echo "              ajena (de B)   inexistente"
for i in 1 2 3; do
  T1=$(curl -s -o /dev/null -b "$JAR_A" -X POST -w '%{time_total}' "$BASE/citas/${CITA_B}/cancelar")
  T2=$(curl -s -o /dev/null -b "$JAR_A" -X POST -w '%{time_total}' "$BASE/citas/${UUID_INVENTADO}/cancelar")
  echo "$i $T1 $T2" | awk '{ printf "  intento %d   %8.1f ms    %8.1f ms\n", $1, $2*1000, $3*1000 }'
done

# --------------------------------------------------------------
echo ""
echo "==============================================================="
echo " 4. LOS IDENTIFICADORES NO SON SECUENCIALES"
echo "==============================================================="
echo "  Cinco citas creadas seguidas por A, en este orden:"
for n in 1 2 3 4 5; do
  crear_cita "$JAR_A" "$((n + 5))" "Cita seguida $n"
  # El caracter 15 (indice 14) es la version del UUID: 4 = aleatorio.
  echo "    $n  $CITA   (version ${CITA:14:1})"
done
echo "  UUID v4: 122 bits aleatorios por id. Conocer uno no permite"
echo "  deducir el siguiente, a diferencia de un id 1, 2, 3..."

# --------------------------------------------------------------
echo ""
echo "==============================================================="
echo " 5. HALLAZGO: la aplicacion podia crear una cuenta admin"
echo "==============================================================="
echo ""
echo "  ANTES del cambio en db/roles.sql: salida real capturada en"
echo "  scripts-evidencias/salida-cita13-antes.txt"
echo "  ---------------------------------------------------------"
sed -n '/^--- 2\./,/^--- 4\./p' "$DIR/salida-cita13-antes.txt" | sed '$d' | sed 's/^/  | /'
echo ""
echo "  AHORA, con INSERT acotado a (name, email, password_hash):"
echo "  ---------------------------------------------------------"
app -c "SELECT 'tabla completa' AS alcance,
               has_table_privilege('citasegura_app', 'users', 'INSERT') AS insert_concedido
        UNION ALL
        SELECT 'columna ' || attname,
               has_column_privilege('citasegura_app', 'users', attname, 'INSERT')
          FROM pg_attribute
         WHERE attrelid = 'users'::regclass AND attnum > 0 AND NOT attisdropped;" | sed 's/^/  /'
HASH_FALSO='$2b$12$'$(printf '%*s' 53 '' | tr ' ' 'x')
echo "  El mismo ataque, como citasegura_app:"
app -c "INSERT INTO users (name, email, password_hash, role)
        VALUES ('Hallazgo CITA-13', 'hallazgo.cita13.${SUFIJO}@ejemplo.com',
                '${HASH_FALSO}', 'admin')
        RETURNING id, email, role;" | sed 's/^/  /'
echo "  Cuentas admin en la base: $(admin -t -A -c "SELECT count(*) FROM users WHERE role = 'admin';")"

# --------------------------------------------------------------
trap - INT TERM
limpieza

echo ""
echo "==============================================================="
echo " Esperado:"
echo "   1 -> GET, PATCH y DELETE /citas/<id>: 404 para ajena e"
echo "        inexistente, la MISMA pagina y 0 datos de la cita;"
echo "        GET .../cancelar: 405"
echo "   2 -> A recibe 404 y la fila de B sigue 'programada' con la"
echo "        MISMA huella antes y despues"
echo "   3 -> tiempos de ajena e inexistente en el mismo rango"
echo "   4 -> cinco UUID version 4 sin relacion entre si"
echo "   5 -> antes: INSERT concedido en todas las columnas y la cuenta"
echo "        admin creada; ahora: INSERT solo en name, email y"
echo "        password_hash, 'permiso denegado' y 0 cuentas admin"
echo "   Limpieza -> 2 cuentas borradas; cuentas, citas y sesiones = 0"
echo "==============================================================="
