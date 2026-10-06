#!/usr/bin/env bash
# ---------------------------------------------------------------
#  CitaSegura - Evidencia de CITA-10 (bloqueo por intentos fallidos)
#  Uso:  bash evidencia-cita10.sh
#  Requiere: app corriendo en localhost:3001 y psql disponible
#
#  Pide la contrasena de citasegura_app UNA sola vez al inicio.
# ---------------------------------------------------------------

PSQL="/c/Program Files/PostgreSQL/18/bin/psql.exe"
BASE="http://localhost:3001/api/auth"
H="Content-Type: application/json"
CLAVE="ClaveEvidencia1!"
CORREO="evidencia.bloqueo.$(date +%H%M%S)@ejemplo.com"

read -rsp "Contrasena de citasegura_app: " PGPASSWORD
export PGPASSWORD
echo ""

db() { "$PSQL" -h 127.0.0.1 -U citasegura_app -d citasegura -t -A -F' | ' -c "$1"; }

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

clear
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
  | grep -iE '^HTTP|^set-cookie' | cut -c1-90
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
echo ""
echo "--- 7. Limpieza"
db "DELETE FROM users WHERE email LIKE 'evidencia.%@ejemplo.com' RETURNING email;"

unset PGPASSWORD

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
echo "==============================================================="
