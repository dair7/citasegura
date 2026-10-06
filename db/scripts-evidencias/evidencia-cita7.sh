#!/usr/bin/env bash
# ---------------------------------------------------------------
#  CitaSegura - Evidencia de CITA-7 (endpoints de registro)
#  Uso:  bash evidencia-cita7.sh
#  Requiere la aplicacion corriendo en http://localhost:3001
# ---------------------------------------------------------------

U="http://localhost:3001/api/auth/register"
H="Content-Type: application/json"

# Correo unico por ejecucion, para que la prueba 6 sea un duplicado real
CORREO="evidencia.$(date +%H%M%S)@ejemplo.com"

clear
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

echo ""
echo "==============================================================="
echo " Esperado:  1 y 6 -> 201 con el MISMO mensaje  (anti-enumeracion)"
echo "            2, 3, 4 -> 400      5 -> 415"
echo "==============================================================="
