#!/usr/bin/env bash
# ---------------------------------------------------------------
#  CitaSegura - Evidencia de CITA-12 (API de citas parametrizada)
#  Uso:  bash evidencia-cita12.sh
#  Requiere: app corriendo en localhost:3001, psql y node disponibles
#
#  Todas las pruebas van por HTTP contra la API real, como lo haria
#  un cliente (o un atacante con curl). No se toca la base salvo en
#  la limpieza final.
#
#  Registra DOS cuentas propias (A y B): B existe para tener una cita
#  AJENA que A intente listar y cancelar. Al terminar, ambas se borran
#  como 'postgres', y sus citas y sesiones caen en cascada. La
#  contrasena de postgres se toma de la variable DB_PASSWORD.
# ---------------------------------------------------------------

PSQL="/c/Program Files/PostgreSQL/18/bin/psql.exe"
BASE="http://localhost:3001/api"
H="Content-Type: application/json"
CLAVE="ClaveEvidencia1!"
SUFIJO=$(date +%H%M%S)
CORREO_A="prueba.cita12.a.${SUFIJO}@ejemplo.com"
CORREO_B="prueba.cita12.b.${SUFIJO}@ejemplo.com"

# Se comprueba ANTES de empezar: sin DB_PASSWORD la limpieza fallaria
# al final y dejaria las cuentas de prueba en la base.
if [ -z "$DB_PASSWORD" ]; then
  echo "Falta la variable de entorno DB_PASSWORD (contrasena de postgres)."
  exit 1
fi

if [ "$(curl -s -o /dev/null -w '%{http_code}' "$BASE/auth/me")" != "401" ]; then
  echo "La aplicacion no responde en localhost:3001."
  echo "Arrancala con: pnpm dev --webpack --port 3001"
  exit 1
fi

# Cookies de cada cuenta y cuerpos de respuesta, fuera del repositorio.
TMP=$(mktemp -d)
JAR_A="$TMP/a.jar"
JAR_B="$TMP/b.jar"

# Mantenimiento: conexion como superusuario, SOLO para la limpieza.
# citasegura_app no tiene DELETE sobre users ni sobre appointments
# (ver db/roles.sql y db/appointments.sql): borrar no es una operacion
# de la aplicacion, y no se le concede un permiso solo para que este
# script pueda limpiar lo que crea.
admin() { PGPASSWORD="$DB_PASSWORD" "$PSQL" -h 127.0.0.1 -U postgres -d citasegura -c "$1" 2>&1; }

# Limpieza: se ejecuta al final y TAMBIEN si el script se interrumpe
# (Ctrl+C), para que nunca queden cuentas de prueba en la base.
LIMPIADO=0
limpieza() {
  [ "$LIMPIADO" = 1 ] && return
  LIMPIADO=1
  echo ""
  echo "==============================================================="
  echo " 5. LIMPIEZA (como postgres: es mantenimiento, no la aplicacion)"
  echo "==============================================================="
  # SE BORRA POR LOS IDS capturados al registrar, nunca por un patron de
  # correo: un LIKE 'prueba.cita12.%' se llevaria por delante cualquier
  # cuenta real que empezara igual. Ademas se exige el correo exacto,
  # asi que cada id solo puede borrar la cuenta que este script creo.
  local ids=()
  [ -n "$UID_A" ] && ids+=("'${UID_A}'")
  [ -n "$UID_B" ] && ids+=("'${UID_B}'")
  if [ ${#ids[@]} -eq 0 ]; then
    echo ""
    echo "  No se capturo ningun id: no hay cuentas de prueba que borrar."
    rm -rf "$TMP"
    return
  fi
  local lista
  lista=$(IFS=,; echo "${ids[*]}")
  echo ""
  echo "  Se borran las cuentas por su id; sus citas y sesiones caen en cascada"
  admin "DELETE FROM users
         WHERE id IN (${lista})
           AND email IN ('${CORREO_A}', '${CORREO_B}')
         RETURNING id, email;" | sed 's/^/  /'
  echo "  Comprobacion: no queda nada de las cuentas de prueba"
  admin "SELECT (SELECT count(*) FROM users        WHERE id      IN (${lista})) AS cuentas,
                (SELECT count(*) FROM appointments WHERE user_id IN (${lista})) AS citas,
                (SELECT count(*) FROM sessions     WHERE user_id IN (${lista})) AS sesiones;" \
    | sed 's/^/  /'
  rm -rf "$TMP"
}
trap 'limpieza; exit 130' INT TERM

# Lee un campo del ultimo cuerpo JSON recibido. Con node y no con sed:
# un motivo puede contener comillas, y un sed sobre JSON se rompe.
campo() {
  node -e '
    const datos = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
    const valor = process.argv[2].split(".").reduce((o, k) => o?.[k], datos);
    console.log(typeof valor === "object" ? JSON.stringify(valor) : (valor ?? ""));
  ' "$TMP/cuerpo" "$1"
}

# peticion ETIQUETA METODO RUTA JAR [CONTENT-TYPE] [CUERPO]
# Imprime el codigo HTTP y el cuerpo; deja ambos en CODIGO y CUERPO.
peticion() {
  local etiqueta=$1 metodo=$2 ruta=$3 jar=$4 tipo=${5:-} datos=${6:-}
  local args=(-s -o "$TMP/cuerpo" -w '%{http_code}' -X "$metodo")
  [ -n "$jar" ]   && args+=(-b "$jar" -c "$jar")
  [ -n "$tipo" ]  && args+=(-H "Content-Type: $tipo")
  [ -n "$datos" ] && args+=(--data-binary "$datos")
  CODIGO=$(curl "${args[@]}" "$BASE$ruta")
  CUERPO=$(cat "$TMP/cuerpo")
  local mostrar=$CUERPO
  [ ${#mostrar} -gt 200 ] && mostrar="${mostrar:0:200}..."
  echo ""
  echo "  $etiqueta"
  echo "  ---------------------------------------------------------"
  echo "  $metodo $ruta -> HTTP $CODIGO"
  echo "  $mostrar"
}

# Fechas con ZONA HORARIA explicita (-05:00, Colombia), que es lo que
# exige el esquema. Se calculan al ejecutar para que siempre sean
# futuras (o pasadas) respecto al dia de la prueba.
FUTURA_1=$(date -d '+3 days' +%Y-%m-%dT10:00:00-05:00)
FUTURA_2=$(date -d '+1 days' +%Y-%m-%dT15:30:00-05:00)
FUTURA_3=$(date -d '+5 days' +%Y-%m-%dT09:00:00-05:00)
PASADA=$(date -d '-1 days' +%Y-%m-%dT10:00:00-05:00)
SIN_ZONA=$(date -d '+3 days' +%Y-%m-%dT10:00:00)
MOTIVO_500=$(printf '%*s' 500 '' | tr ' ' 'x')
MOTIVO_501=$(printf '%*s' 501 '' | tr ' ' 'x')
UUID_INVENTADO=$(node -e 'console.log(crypto.randomUUID())')

# Solo si la salida es una terminal: redirigida a un fichero, clear
# metería secuencias de escape en la evidencia.
[ -t 1 ] && clear
echo "==============================================================="
echo " CITA-12  API de citas parametrizada"
echo " Todas las pruebas van por HTTP contra localhost:3001"
echo " Fecha: $(date '+%Y-%m-%d %H:%M:%S')"
echo "==============================================================="

# registrar CORREO VARIABLE: registra la cuenta y deja su id en VARIABLE.
# El id se captura JUSTO DESPUES de registrar: es lo que usa la limpieza
# para borrar, y cuanto antes se conozca, menos queda sin identificar si
# el script se interrumpe.
registrar() {
  curl -s -o /dev/null -w "    registro de $1 -> HTTP %{http_code}\n" \
    -X POST "$BASE/auth/register" -H "$H" \
    -d "{\"name\":\"Prueba Cita12\",\"email\":\"$1\",\"password\":\"${CLAVE}\"}"
  printf -v "$2" '%s' "$(PGPASSWORD="$DB_PASSWORD" "$PSQL" -h 127.0.0.1 \
    -U postgres -d citasegura -t -A \
    -c "SELECT id FROM users WHERE email = '$1';")"
  echo "      id capturado: ${!2:-NINGUNO}"
}

# --------------------------------------------------------------
echo ""
echo "--- Preparacion: dos cuentas de prueba (A y B)"
registrar "$CORREO_A" UID_A
registrar "$CORREO_B" UID_B
curl -s -o /dev/null -c "$JAR_A" -w "    login A -> HTTP %{http_code}\n" \
  -X POST "$BASE/auth/login" -H "$H" \
  -d "{\"email\":\"${CORREO_A}\",\"password\":\"${CLAVE}\"}"
curl -s -o /dev/null -c "$JAR_B" -w "    login B -> HTTP %{http_code}\n" \
  -X POST "$BASE/auth/login" -H "$H" \
  -d "{\"email\":\"${CORREO_B}\",\"password\":\"${CLAVE}\"}"

if [ -z "$UID_A" ] || [ -z "$UID_B" ]; then
  echo ""
  echo "  No se pudieron crear las dos cuentas de prueba. Se aborta."
  limpieza
  exit 1
fi

# --------------------------------------------------------------
echo ""
echo "==============================================================="
echo " 1. SIN SESION, 401; CON SESION, CREAR CITAS VALIDAS"
echo "==============================================================="

peticion "1.1  Listar sin sesion" \
  GET /citas ""

peticion "1.2  Crear sin sesion, con un cuerpo valido" \
  POST /citas "" application/json \
  "{\"scheduledAt\":\"${FUTURA_1}\",\"reason\":\"Sin sesion\"}"

peticion "1.3  Crear sin sesion y con un cuerpo basura: 401, no 415 (la sesion va primero)" \
  POST /citas "" text/plain "basura"

peticion "1.4  Cancelar sin sesion" \
  POST "/citas/${UUID_INVENTADO}/cancelar" ""

peticion "1.5  A crea una cita valida (la hora viaja con zona -05:00 y se guarda en UTC)" \
  POST /citas "$JAR_A" application/json \
  "{\"scheduledAt\":\"${FUTURA_1}\",\"reason\":\"Renovacion de documento\"}"
CITA_A1=$(campo cita.id)

peticion "1.6  A crea otra con el motivo rodeado de espacios: se guarda recortado" \
  POST /citas "$JAR_A" application/json \
  "{\"scheduledAt\":\"${FUTURA_2}\",\"reason\":\"   Consulta tributaria   \"}"
echo "  motivo guardado: [$(campo cita.reason)]"

peticion "1.7  A crea una con un motivo de EXACTAMENTE 500 caracteres (el limite del CHECK)" \
  POST /citas "$JAR_A" application/json \
  "{\"scheduledAt\":\"${FUTURA_3}\",\"reason\":\"${MOTIVO_500}\"}"
echo "  longitud del motivo guardado: $(campo cita.reason | tr -d '\n\r' | wc -c)"

peticion "1.8  B crea su propia cita (sera la cita AJENA para A)" \
  POST /citas "$JAR_B" application/json \
  "{\"scheduledAt\":\"${FUTURA_1}\",\"reason\":\"Cita de B\"}"
CITA_B=$(campo cita.id)

# --------------------------------------------------------------
echo ""
echo "==============================================================="
echo " 2. PETICIONES RECHAZADAS POR LA VALIDACION DEL SERVIDOR"
echo "==============================================================="

peticion "2.1  Mass assignment: userId colado en el cuerpo (el dueño sale de la sesion)" \
  POST /citas "$JAR_A" application/json \
  "{\"scheduledAt\":\"${FUTURA_1}\",\"reason\":\"x\",\"userId\":\"${UID_B}\"}"

peticion "2.2  Mass assignment: status colado en el cuerpo (nacer ya cancelada)" \
  POST /citas "$JAR_A" application/json \
  "{\"scheduledAt\":\"${FUTURA_1}\",\"reason\":\"x\",\"status\":\"cancelada\"}"

peticion "2.3  Fecha en el pasado" \
  POST /citas "$JAR_A" application/json \
  "{\"scheduledAt\":\"${PASADA}\",\"reason\":\"x\"}"

peticion "2.4  Fecha sin zona horaria (ambigua)" \
  POST /citas "$JAR_A" application/json \
  "{\"scheduledAt\":\"${SIN_ZONA}\",\"reason\":\"x\"}"

peticion "2.5  Motivo de 501 caracteres" \
  POST /citas "$JAR_A" application/json \
  "{\"scheduledAt\":\"${FUTURA_1}\",\"reason\":\"${MOTIVO_501}\"}"

peticion "2.6  Motivo en blanco (solo espacios)" \
  POST /citas "$JAR_A" application/json \
  "{\"scheduledAt\":\"${FUTURA_1}\",\"reason\":\"     \"}"

peticion "2.7  Envio tipo formulario (no JSON)" \
  POST /citas "$JAR_A" application/x-www-form-urlencoded \
  "scheduledAt=${FUTURA_1}&reason=formulario"

peticion "2.8  JSON mal formado" \
  POST /citas "$JAR_A" application/json \
  "{esto no es json"

peticion "2.9  Los rechazos no dejaron rastro: A sigue teniendo solo sus 3 citas" \
  GET /citas "$JAR_A"
echo "  citas de A: $(campo citas | node -e 'console.log(JSON.parse(require("fs").readFileSync(0,"utf8")).length)')"

# --------------------------------------------------------------
echo ""
echo "==============================================================="
echo " 3. INYECCION SQL Y LISTADO FILTRADO POR DUEÑO"
echo "==============================================================="

peticion "3.1  Inyeccion SQL en el motivo: se guarda como texto, no se ejecuta" \
  POST /citas "$JAR_A" application/json \
  "{\"scheduledAt\":\"${FUTURA_3}\",\"reason\":\"x'); DELETE FROM appointments; --\"}"
echo "  motivo guardado: [$(campo cita.reason)]"

peticion "3.2  La tabla sigue intacta: B conserva su cita" \
  GET /citas "$JAR_B"

peticion "3.3  Listado de A: solo sus citas, ordenadas por fecha" \
  GET /citas "$JAR_A"
echo "  citas de A, en el orden en que llegan:"
campo citas | node -e '
  for (const c of JSON.parse(require("fs").readFileSync(0, "utf8")))
    console.log(`    ${c.scheduledAt}  ${c.status.padEnd(10)}  ${c.id}`);
'
echo "  ¿aparece la cita de B (${CITA_B})?   $(grep -c "$CITA_B" "$TMP/cuerpo") coincidencias"
echo "  ¿aparece algun user_id / userId?   $(grep -ciE 'user_?id' "$TMP/cuerpo") coincidencias"

# --------------------------------------------------------------
echo ""
echo "==============================================================="
echo " 4. CANCELAR, Y LOS TRES INTENTOS QUE DEBEN DAR EL MISMO 404"
echo "==============================================================="

peticion "4.1  A cancela su propia cita" \
  POST "/citas/${CITA_A1}/cancelar" "$JAR_A"

peticion "4.2  A la cancela otra vez" \
  POST "/citas/${CITA_A1}/cancelar" "$JAR_A"

peticion "4.3  A intenta cancelar la cita de B (existe, pero es AJENA)" \
  POST "/citas/${CITA_B}/cancelar" "$JAR_A"
R1="$CODIGO $CUERPO"

peticion "4.4  A intenta cancelar un UUID que NO EXISTE" \
  POST "/citas/${UUID_INVENTADO}/cancelar" "$JAR_A"
R2="$CODIGO $CUERPO"

peticion "4.5  A intenta cancelar con un id basura (1 OR 1=1)" \
  POST "/citas/1%20OR%201=1/cancelar" "$JAR_A"
R3="$CODIGO $CUERPO"

echo ""
if [ "$R1" = "$R2" ] && [ "$R2" = "$R3" ]; then
  echo "  RESULTADO: las tres respuestas son IDENTICAS (codigo y cuerpo, byte a byte)"
else
  echo "  RESULTADO: LAS RESPUESTAS DIFIEREN -- el endpoint revela informacion"
fi

peticion "4.6  La cita de B no se toco: sigue programada" \
  GET /citas "$JAR_B"

# --------------------------------------------------------------
trap - INT TERM
limpieza

echo ""
echo "==============================================================="
echo " Esperado:"
echo "   1.1 a 1.4 -> 401 'No autenticado.', incluso con cuerpo basura"
echo "   1.5 a 1.8 -> 201; motivo recortado en 1.6 y de 500 en 1.7"
echo "   2.1 y 2.2 -> 400: claves no declaradas, se rechaza el cuerpo"
echo "   2.3 a 2.6 -> 400 con el mensaje del campo que falla"
echo "   2.7       -> 415     2.8 -> 400"
echo "   2.9       -> A sigue con 3 citas: los rechazos no dejan rastro"
echo "   3.1       -> 201 y el motivo guardado tal cual, como texto"
echo "   3.2       -> B conserva su cita: el DELETE no se ejecuto"
echo "   3.3       -> solo citas de A, en orden ascendente de fecha,"
echo "                0 coincidencias de la cita de B y de user_id"
echo "   4.1 -> 200     4.2 -> 409"
echo "   4.3 a 4.5 -> 404 'Cita no encontrada.', las tres IDENTICAS"
echo "   4.6       -> la cita de B sigue programada"
echo "   5         -> 2 cuentas borradas; cuentas, citas y sesiones = 0"
echo "==============================================================="
