#!/usr/bin/env bash
# ---------------------------------------------------------------
#  CitaSegura - Evidencia de CITA-16: cabeceras de seguridad HTTP
#  Uso:  bash evidencia-cita16-cabeceras.sh antes   | tee salida-cita16-cabeceras-antes.txt
#        bash evidencia-cita16-cabeceras.sh despues | tee salida-cita16-cabeceras.txt
#  Requiere: pnpm, psql, node, .env.local, y el servidor de desarrollo
#  PARADO: el guion hace su propio build de produccion, que escribe en
#  .next, y arranca next start en el puerto 3016. Lo para al terminar.
#
#  El argumento solo elige que "Esperado" se declara y la etiqueta de
#  la cabecera. La medicion es la misma en las dos fases, para que el
#  antes y el despues se puedan comparar linea a linea.
#
#  POR QUE PRODUCCION Y NO DESARROLLO: en modo desarrollo Next.js
#  añade a las respuestas cosas que en produccion no estan, y una
#  medicion alli no diria nada del sistema que se entrega.
#
#  POR QUE curl -I: pide solo las cabeceras (metodo HEAD), que es lo
#  que se mide. Se imprime la respuesta COMPLETA de cada ruta, no solo
#  las cabeceras buscadas, para que se vea tambien lo que sobra.
#
#  Registra DOS cuentas por la API: N (usuario normal, para /inicio y
#  la API) y A (se promueve a administrador como postgres, el unico
#  camino, para /admin). Al terminar se borran como postgres por id
#  capturado Y correo exacto; sus sesiones caen en cascada.
#
#  SECRETOS: los tokens de sesion viven solo en los ficheros de cookies
#  del directorio temporal, que se borra al final. Si alguna respuesta
#  trae Set-Cookie, su valor se sustituye por <OCULTO> antes de
#  imprimirla, y cualquier cadena postgres:// del build, por <URL OCULTA>.
# ---------------------------------------------------------------

FASE=${1:-}
case "$FASE" in
  antes|despues) ;;
  *) echo "Uso: bash $0 antes|despues"; exit 1 ;;
esac

PSQL="/c/Program Files/PostgreSQL/18/bin/psql.exe"
PUERTO=3016
WEB="http://localhost:${PUERTO}"
H="Content-Type: application/json"
CLAVE="ClaveEvidencia1!"
SUFIJO=$(date +%H%M%S)
CORREO_N="prueba.cita16.n.${SUFIJO}@ejemplo.com"
CORREO_A="prueba.cita16.a.${SUFIJO}@ejemplo.com"
DIR=$(cd "$(dirname "$0")" && pwd)
RAIZ=$(cd "$DIR/../.." && pwd)
NEXT="$RAIZ/node_modules/next/dist/bin/next"
cd "$RAIZ" || exit 1

ADMIN_PASS="${DB_PASSWORD:-$PGPASSWORD}"
if [ -z "$ADMIN_PASS" ]; then
  echo "Falta la contrasena de postgres: define DB_PASSWORD o PGPASSWORD."
  exit 1
fi
if curl -s -o /dev/null --max-time 3 "http://localhost:3001/"; then
  echo "Hay un servidor en localhost:3001. Paralo antes de ejecutar este"
  echo "guion: el build de produccion escribe en .next."
  exit 1
fi
if curl -s -o /dev/null --max-time 3 "$WEB/"; then
  echo "El puerto ${PUERTO} esta ocupado; el guion arranca alli su servidor."
  exit 1
fi

TMP=$(mktemp -d)
JAR_N="$TMP/n.jar"
JAR_A="$TMP/a.jar"
SERVIDOR_PID=""

admin() { PGPASSWORD="$ADMIN_PASS" "$PSQL" -h 127.0.0.1 -U postgres -d citasegura "$@" 2>&1; }

arrancar() {
  node "$NEXT" start -p "$PUERTO" > "$TMP/servidor.log" 2>&1 &
  SERVIDOR_PID=$!
  for _ in $(seq 1 30); do
    curl -s -o /dev/null --max-time 2 "$WEB/login" && return 0
    sleep 1
  done
  return 1
}
parar() {
  [ -n "$SERVIDOR_PID" ] && kill "$SERVIDOR_PID" 2>/dev/null && wait "$SERVIDOR_PID" 2>/dev/null
  SERVIDOR_PID=""
}

LIMPIADO=0
limpieza() {
  [ "$LIMPIADO" = 1 ] && return
  LIMPIADO=1
  parar
  echo ""
  echo "==============================================================="
  echo " LIMPIEZA (como postgres: es mantenimiento, no la aplicacion)"
  echo "==============================================================="
  local ids=()
  [ -n "$UID_N" ] && ids+=("'${UID_N}'")
  [ -n "$UID_A" ] && ids+=("'${UID_A}'")
  if [ ${#ids[@]} -gt 0 ]; then
    local lista
    lista=$(IFS=,; echo "${ids[*]}")
    echo "  Cuentas de prueba, por id y correo exacto:"
    admin -c "DELETE FROM users
               WHERE id IN (${lista})
                 AND email IN ('${CORREO_N}', '${CORREO_A}')
              RETURNING email;" | sed 's/^/    /'
    echo "  Comprobacion: no queda rastro"
    admin -c "SELECT (SELECT count(*) FROM users    WHERE id      IN (${lista})) AS cuentas,
                     (SELECT count(*) FROM sessions WHERE user_id IN (${lista})) AS sesiones;" \
      | sed 's/^/    /'
  else
    echo "  No se capturo ningun id: no hay cuentas de prueba que borrar."
  fi
  rm -rf "$TMP"
  echo "  Temporales borrados: $([ -d "$TMP" ] && echo NO || echo si)"
  local queda
  queda=$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 "$WEB/login")
  echo "  Servidor del guion en el puerto ${PUERTO}: $([ "$queda" = 000 ] && echo parado || echo "SIGUE RESPONDIENDO ($queda)")"
}
trap 'limpieza; exit 130' INT TERM
trap limpieza EXIT

# Las rutas medidas: ETIQUETA|RUTA|COOKIES. La misma lista en las dos
# fases. /admin y /api/citas se miden tambien sin sesion porque las
# respuestas de error (404, 401) tienen que llevar las mismas cabeceras.
RUTAS=(
  "raiz|/|"
  "login|/login|"
  "inicio_n|/inicio|N"
  "admin_a|/admin|A"
  "admin_anon|/admin|"
  "api_n|/api/citas|N"
  "api_anon|/api/citas|"
)
CABECERAS=(
  X-Powered-By
  X-Content-Type-Options
  X-Frame-Options
  Referrer-Policy
  Permissions-Policy
  Strict-Transport-Security
  Content-Security-Policy
)

# medir ETIQUETA RUTA COOKIES: curl -I, guardado en $TMP/ETIQUETA.h
medir() {
  local args=(-s -I)
  case "$3" in
    N) args+=(-b "$JAR_N") ;;
    A) args+=(-b "$JAR_A") ;;
  esac
  curl "${args[@]}" "$WEB$2" | tr -d '\r' \
    | sed -E 's/^([Ss]et-[Cc]ookie: [^=]+=)[^;]*/\1<OCULTO>/' > "$TMP/$1.h"
}

[ -t 1 ] && clear
echo "==============================================================="
echo " CITA-16  Cabeceras de seguridad HTTP  (fase: ${FASE})"
echo " Fecha: $(date '+%Y-%m-%d %H:%M:%S')"
echo " Commit: $(git log -1 --format='%h %s')"
echo " Cambios sin commit en next.config.ts: $(git status --porcelain next.config.ts | wc -l)"
echo " Servidor: build de produccion, next start en el puerto ${PUERTO}"
echo "==============================================================="

# ===============================================================
echo ""
echo "==============================================================="
echo " 0. PREPARACION"
echo "---------------------------------------------------------------"
echo " Esperado: build con codigo 0; las dos cuentas registradas por la"
echo "   API (201); A promovida a admin como postgres; los dos login 200."
echo "==============================================================="
echo ""
echo "--- 0.1 pnpm build"
pnpm build > "$TMP/build.log" 2>&1
CODIGO_BUILD=$?
sed 's/\x1b\[[0-9;]*m//g' "$TMP/build.log" | sed -E 's#postgres(ql)?://[^[:space:]"]*#<URL OCULTA>#g' \
  | grep -E 'Compiled|rror|Proxy' | sed 's/^/  /'
echo "  codigo de salida: ${CODIGO_BUILD}"
[ "$CODIGO_BUILD" != 0 ] && { echo "  El build fallo."; exit 1; }

echo ""
echo "--- 0.2 next start en el puerto ${PUERTO}"
if ! arrancar; then echo "  El servidor no respondio."; exit 1; fi
echo "  responde /login: HTTP $(curl -s -o /dev/null -w '%{http_code}' "$WEB/login")"

echo ""
echo "--- 0.3 Cuentas de prueba, registradas por la API"
for par in "N:${CORREO_N}:Prueba Normal" "A:${CORREO_A}:Prueba Admin"; do
  IFS=: read -r letra correo nombre <<< "$par"
  printf '  registro %s (%s) -> HTTP %s\n' "$letra" "$correo" "$(curl -s -o /dev/null -w '%{http_code}' \
    -X POST "$WEB/api/auth/register" -H "$H" \
    -d "{\"name\":\"${nombre}\",\"email\":\"${correo}\",\"password\":\"${CLAVE}\"}")"
done
UID_N=$(admin -t -A -c "SELECT id FROM users WHERE email = '${CORREO_N}';")
UID_A=$(admin -t -A -c "SELECT id FROM users WHERE email = '${CORREO_A}';")
echo "  id N: ${UID_N:-NINGUNO}"
echo "  id A: ${UID_A:-NINGUNO}"
[ -z "$UID_N" ] || [ -z "$UID_A" ] && { echo "  Falta alguna cuenta."; exit 1; }
admin -c "UPDATE users SET role = 'admin'
           WHERE id = '${UID_A}' AND email = '${CORREO_A}'
          RETURNING email, role;" | sed 's/^/    /'

echo ""
echo "--- 0.4 Sesiones"
printf '  login N -> HTTP %s\n' "$(curl -s -o /dev/null -c "$JAR_N" -w '%{http_code}' \
  -X POST "$WEB/api/auth/login" -H "$H" -d "{\"email\":\"${CORREO_N}\",\"password\":\"${CLAVE}\"}")"
printf '  login A -> HTTP %s\n' "$(curl -s -o /dev/null -c "$JAR_A" -w '%{http_code}' \
  -X POST "$WEB/api/auth/login" -H "$H" -d "{\"email\":\"${CORREO_A}\",\"password\":\"${CLAVE}\"}")"

# ===============================================================
echo ""
echo "==============================================================="
echo " 1. RESPUESTA COMPLETA DE curl -I EN CADA RUTA"
echo "---------------------------------------------------------------"
if [ "$FASE" = antes ]; then
echo " Esperado ANTES de CITA-16 (prevision, sin medir): X-Powered-By:"
echo "   Next.js en todas; ninguna de las cabeceras de seguridad."
echo "   Codigos: / 200, /login 200, /inicio con N 200, /admin con A"
echo "   200, /admin sin sesion 404, /api/citas con N 200 y sin sesion"
echo "   401."
else
echo " Esperado DESPUES de CITA-16: los mismos codigos que antes; sin"
echo "   X-Powered-By en ninguna; en todas X-Content-Type-Options,"
echo "   X-Frame-Options, Referrer-Policy, Permissions-Policy y"
echo "   Strict-Transport-Security; ninguna Content-Security-Policy."
fi
echo "==============================================================="
for r in "${RUTAS[@]}"; do
  IFS='|' read -r etiqueta ruta quien <<< "$r"
  medir "$etiqueta" "$ruta" "$quien"
  echo ""
  echo "--- curl -I ${ruta}  (sesion: ${quien:-ninguna})"
  sed '/^$/d; s/^/  /' "$TMP/$etiqueta.h"
done

# ===============================================================
echo ""
echo "==============================================================="
echo " 2. RESUMEN: VALOR DE CADA CABECERA EN CADA RUTA"
echo "---------------------------------------------------------------"
echo " Esperado: lo mismo que en el bloque 1, en forma de tabla."
echo "   \"-\" significa que la cabecera no viene en la respuesta."
echo "==============================================================="
for c in "${CABECERAS[@]}"; do
  echo ""
  echo "--- ${c}"
  for r in "${RUTAS[@]}"; do
    IFS='|' read -r etiqueta ruta quien <<< "$r"
    valor=$(grep -i "^${c}:" "$TMP/$etiqueta.h" | head -1 | cut -d: -f2- | sed 's/^ //')
    printf '  %-28s %s\n' "${ruta} (${quien:-sin sesion})" "${valor:--}"
  done
done

if [ "$FASE" = despues ]; then
echo ""
echo "==============================================================="
echo " 3. STRICT-TRANSPORT-SECURITY: PUESTA, NO VERIFICABLE AQUI"
echo "---------------------------------------------------------------"
echo " La cabecera viaja, pero este entorno sirve por HTTP. El navegador"
echo " solo hace caso de Strict-Transport-Security cuando la recibe por"
echo " HTTPS; por HTTP la ignora (RFC 6797, seccion 8.1). Lo unico que"
echo " demuestra esta evidencia es que la aplicacion la envia, no que"
echo " fuerce HTTPS. Comprobarlo exige desplegar con TLS."
echo "==============================================================="
fi

# --------------------------------------------------------------
trap - INT TERM EXIT
limpieza

echo ""
echo "==============================================================="
echo " Resumen de lo esperado (fase ${FASE}):"
echo "   0 -> build 0; registros 201; A admin; logins 200"
if [ "$FASE" = antes ]; then
echo "   1 y 2 -> X-Powered-By: Next.js en todas; ninguna cabecera de"
echo "        seguridad; codigos 200 200 200 200 404 200 401"
else
echo "   1 y 2 -> sin X-Powered-By; nosniff, DENY, no-referrer,"
echo "        Permissions-Policy y HSTS en todas; sin CSP; codigos"
echo "        200 200 200 200 404 200 401"
echo "   3 -> HSTS enviada; no verificable sin HTTPS"
fi
echo "   Limpieza -> cuentas y sesiones 0; servidor parado"
echo "==============================================================="
