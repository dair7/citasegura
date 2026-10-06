#!/usr/bin/env bash
# ---------------------------------------------------------------
#  CitaSegura - Evidencia de CITA-8 (hashing con bcrypt)
#  Uso:  bash evidencia-cita8.sh
#  Requiere: app corriendo en localhost:3001 y psql disponible
# ---------------------------------------------------------------

PSQL="/c/Program Files/PostgreSQL/18/bin/psql.exe"
CONN=(-h 127.0.0.1 -U citasegura_app -d citasegura)
U="http://localhost:3001/api/auth/register"
CLAVE="ClaveEvidencia1!"
CORREO="evidencia.bcrypt.$(date +%H%M%S)@ejemplo.com"

clear
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

# --------------------------------------------------------------
echo ""
echo "--- 2. Que quedo guardado en la base de datos"
"$PSQL" "${CONN[@]}" -x -c "
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
"$PSQL" "${CONN[@]}" -c "
INSERT INTO users (name, email, password_hash)
VALUES ('Fulano', 'texto.plano@ejemplo.com', 'MiClaveEnTextoPlano123');"

# --------------------------------------------------------------
echo ""
echo "--- 4. Dos hashes de la MISMA contrasena son distintos (salt aleatorio)"
curl -s -o /dev/null -X POST "$U" -H "Content-Type: application/json" \
  -d "{\"name\":\"Usuario Bcrypt Dos\",\"email\":\"evidencia.bcrypt.dos.$(date +%H%M%S)@ejemplo.com\",\"password\":\"${CLAVE}\"}"
"$PSQL" "${CONN[@]}" -c "
SELECT email AS correo, left(password_hash, 29) AS prefijo_y_salt
FROM users
WHERE email LIKE 'evidencia.bcrypt%'
ORDER BY created_at;"

echo ""
echo "==============================================================="
echo " Esperado:"
echo "   2 -> prefijo \$2b\$12\$ , largo 60 , check=t , posicion=0"
echo "   3 -> ERROR: viola la restriccion users_password_hash_is_bcrypt"
echo "   4 -> los dos salt son DISTINTOS pese a ser la misma contrasena"
echo "==============================================================="
