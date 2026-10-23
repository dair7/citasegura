#!/usr/bin/env bash
# ---------------------------------------------------------------
#  CitaSegura - Evidencia de CITA-7 (endpoints de registro)
#  Uso:  bash evidencia-cita7.sh
#  Requiere la aplicacion corriendo en http://localhost:3001 y psql
#
#  Las pruebas van solo por la API. La cuenta que crea la prueba 1 se
#  borra al final, despues de la prueba 6, como 'postgres', por id
#  capturado Y correo exacto; su contrasena se toma de DB_PASSWORD o,
#  si no existe, de PGPASSWORD.
#
#  Si la limpieza no se puede hacer, queda dicho en la propia salida y
#  el guion termina con codigo 1.
# ---------------------------------------------------------------

PSQL="/c/Program Files/PostgreSQL/18/bin/psql.exe"
U="http://localhost:3001/api/auth/register"
H="Content-Type: application/json"

# Correo unico por ejecucion, para que la prueba 6 sea un duplicado real
CORREO="evidencia.$(date +%H%M%S)@ejemplo.com"

ADMIN_PASS="${DB_PASSWORD:-$PGPASSWORD}"
if [ -z "$ADMIN_PASS" ]; then
  echo "Falta la contrasena de postgres: define DB_PASSWORD o PGPASSWORD."
  exit 1
fi

if [ "$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:3001/api/auth/me")" != "401" ]; then
  echo "La aplicacion no responde en localhost:3001."
  echo "Arrancala con: pnpm dev --webpack --port 3001"
  exit 1
fi

# El descriptor 3 es siempre la salida del guion: por ahi se avisa de
# un fallo.
exec 3>&1
FALLOS=0

# Superusuario: solo para capturar el id y para limpiar.
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

LIMPIADO=0
limpieza() {
  [ "$LIMPIADO" = 1 ] && return
  LIMPIADO=1
  echo ""
  echo "--- Limpieza (como postgres: es mantenimiento, no la aplicacion)"
  if [ -z "$UID_PRUEBA" ]; then
    echo "    No se capturo ningun id: no hay cuenta de prueba que borrar."
    return
  fi
  # Por el id capturado Y el correo exacto, nunca por un patron.
  comprobar 0 psql_admin -c "DELETE FROM users
             WHERE id = '${UID_PRUEBA}' AND email = '${CORREO}'
            RETURNING id, email;"
  comprobar 0 psql_admin -c "SELECT count(*) AS cuentas_que_quedan
             FROM users WHERE id = '${UID_PRUEBA}';"
}
trap 'limpieza; exit 130' INT TERM

# Solo si la salida es una terminal: redirigida a un fichero, clear
# meteria secuencias de escape en la evidencia.
[ -t 1 ] && clear
echo "==============================================================="
echo " CITA-7  Endpoints de registro  -  POST /api/auth/register"
echo " Fecha: $(date '+%Y-%m-%d %H:%M:%S')"
echo "==============================================================="

prueba() {
  echo ""
  echo "--- $1"
  shift
  curl -s -w '\n>> HTTP %{http_code}   (%{time_total}s)\n' "$@"
}

prueba "1. REGISTRO VALIDO  (nombre con espacios, correo en mayusculas)" \
  -X POST "$U" -H "$H" \
  -d "{\"name\":\"  Usuario Evidencia  \",\"email\":\"  ${CORREO^^} \",\"password\":\"ClaveEvidencia1!\"}"
# La API guarda el correo normalizado, asi que se busca en minusculas.
# Solo se imprime algo si no se pudo capturar el id.
UID_PRUEBA=$(capturar_id "$CORREO")
if [ -z "$UID_PRUEBA" ]; then
  echo "    FALLO DEL GUION: no se pudo capturar el id de la cuenta de la prueba 1;"
  echo "    si el registro dio 201, la cuenta queda en la base: $CORREO"
  FALLOS=$((FALLOS + 1))
fi

prueba "2. ATAQUE  correo con formato invalido" \
  -X POST "$U" -H "$H" \
  -d '{"name":"Atacante","email":"no-es-un-correo","password":"ClaveEvidencia1!"}'

prueba "3. ATAQUE  contrasena debil" \
  -X POST "$U" -H "$H" \
  -d '{"name":"Atacante","email":"debil@ejemplo.com","password":"123"}'

prueba "4. ATAQUE  mass assignment  (role=admin)" \
  -X POST "$U" -H "$H" \
  -d '{"name":"Atacante","email":"escalada@ejemplo.com","password":"ClaveEvidencia1!","role":"admin"}'

prueba "5. ATAQUE  envio tipo formulario desde otro sitio  (CSRF)" \
  -X POST "$U" -H 'Content-Type: application/x-www-form-urlencoded' \
  -d 'name=Atacante&email=csrf@ejemplo.com&password=ClaveEvidencia1!'

prueba "6. ANTI-ENUMERACION  el mismo correo por segunda vez" \
  -X POST "$U" -H "$H" \
  -d "{\"name\":\"Otro Nombre\",\"email\":\"${CORREO}\",\"password\":\"OtraClaveDistinta9#\"}"

trap - INT TERM
limpieza

echo ""
echo "==============================================================="
echo " Esperado:  1 y 6 -> 201 con el MISMO mensaje  (anti-enumeracion)"
echo "            2, 3, 4 -> 400      5 -> 415"
echo "            Limpieza -> 1 cuenta borrada; cuentas_que_quedan = 0"
echo "==============================================================="
echo ""
if [ "$FALLOS" -gt 0 ]; then
  echo " RESULTADO DEL GUION: ${FALLOS} medida(s) no se pudieron hacer"
  echo " (ver FALLO DEL GUION). Esta salida NO vale como evidencia."
  exit 1
fi
echo " RESULTADO DEL GUION: todas las medidas se hicieron."
