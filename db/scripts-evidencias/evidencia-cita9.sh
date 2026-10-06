#!/usr/bin/env bash
# ---------------------------------------------------------------
#  CitaSegura - Evidencia de CITA-9 (login y sesiones propias)
#  Uso:  bash evidencia-cita9.sh
#  Requiere: app corriendo en localhost:3001 y psql disponible
# ---------------------------------------------------------------

PSQL="/c/Program Files/PostgreSQL/18/bin/psql.exe"
CONN=(-h 127.0.0.1 -U citasegura_app -d citasegura)
BASE="http://localhost:3001/api/auth"
H="Content-Type: application/json"
CLAVE="ClaveEvidencia1!"
CORREO="evidencia.sesion.$(date +%H%M%S)@ejemplo.com"
JAR="jar-evidencia.txt"

clear
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

# --------------------------------------------------------------
echo ""
echo "--- 1. LOGIN correcto: cabecera Set-Cookie y flags"
curl -s -i -c "$JAR" -X POST "$BASE/login" -H "$H" \
  -d "{\"email\":\"${CORREO}\",\"password\":\"${CLAVE}\"}" \
  | grep -iE '^HTTP|^set-cookie|^\{'

TOKEN=$(grep citasegura_session "$JAR" | awk '{print $7}')
echo ""
echo "    Token recibido en la cookie: $TOKEN"
echo "    Longitud: ${#TOKEN} caracteres"

# --------------------------------------------------------------
echo ""
echo "--- 2. En la tabla 'sessions' el token esta HASHEADO (SHA-256)"
SHA=$(printf '%s' "$TOKEN" | sha256sum | awk '{print $1}')
echo "    SHA-256 calculado FUERA de la base: $SHA"
"$PSQL" "${CONN[@]}" -x -c "
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
cp "$JAR" "jar-antes-del-logout.txt"
echo ""
echo "  a) cierre de sesion"
curl -s -i -b "$JAR" -X POST "$BASE/logout" | grep -iE '^HTTP|^set-cookie|^\{'
echo ""
echo "  b) se reenvia la cookie ANTIGUA (token aun valido, sesion revocada)"
curl -s -b "jar-antes-del-logout.txt" -w '\n  >> HTTP %{http_code}\n' "$BASE/me"
echo ""
echo "  c) filas que quedan en 'sessions' para esta cuenta"
"$PSQL" "${CONN[@]}" -c "
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

rm -f "$JAR" "jar-antes-del-logout.txt"

echo ""
echo "==============================================================="
echo " Esperado:"
echo "   1 -> 200 con HttpOnly, SameSite=lax y Max-Age"
echo "   2 -> largo 64, coincide=t, en_claro=f"
echo "   3 -> a) 200   b) y c) 401 con el MISMO mensaje"
echo "   4 -> b) 401 pese a token valido   c) 0 sesiones"
echo "   5 -> EXISTE y NO EXISTE similares; sin bcrypt mucho menor"
echo "==============================================================="
