#!/usr/bin/env bash
# ---------------------------------------------------------------
#  CitaSegura - Evidencia de CITA-16: quitar las cabeceras x-nextjs-*
#  Uso:  bash evidencia-cita16-proxy.sh | tee salida-cita16-proxy.txt
#  Requiere: pnpm, psql, node, .env.local, y el servidor de desarrollo
#  PARADO: el guion hace su propio build, que escribe en .next, y
#  arranca next start en el puerto 3016.
#
#  QUE MIDE: si un Proxy de Next.js consigue quitar de la respuesta las
#  cabeceras que siguen llevando el nombre del framework despues de
#  desactivar X-Powered-By: x-nextjs-cache, x-nextjs-prerender,
#  x-nextjs-stale-time y el Vary con next-router-*. Es UN intento, el
#  directo: borrarlas de la respuesta que devuelve el Proxy. Se mide
#  el resultado, sea cual sea, en las mismas siete rutas que
#  evidencia-cita16-cabeceras.sh.
#
#  MODIFICA EL ARBOL DE TRABAJO: crea src/proxy.ts, que no existe en el
#  repositorio, y lo borra al terminar, tambien si el guion se
#  interrumpe. Se niega a empezar si ya existe un src/proxy.ts o un
#  src/middleware.ts, para no pisar nada. El .next que deja el build
#  incluye el Proxy hasta el siguiente build.
#
#  Cuentas: N (normal) y A (promovida a admin como postgres), borradas
#  al final por id y correo exacto. Los tokens de sesion solo viven en
#  los ficheros de cookies del directorio temporal; un Set-Cookie, si
#  apareciera, se imprime con el valor <OCULTO>.
# ---------------------------------------------------------------

PSQL="/c/Program Files/PostgreSQL/18/bin/psql.exe"
PUERTO=3016
WEB="http://localhost:${PUERTO}"
H="Content-Type: application/json"
CLAVE="ClaveEvidencia1!"
SUFIJO=$(date +%H%M%S)
CORREO_N="prueba.cita16p.n.${SUFIJO}@ejemplo.com"
CORREO_A="prueba.cita16p.a.${SUFIJO}@ejemplo.com"
DIR=$(cd "$(dirname "$0")" && pwd)
RAIZ=$(cd "$DIR/../.." && pwd)
NEXT="$RAIZ/node_modules/next/dist/bin/next"
NDIST="node_modules/next/dist"
cd "$RAIZ" || exit 1

ADMIN_PASS="${DB_PASSWORD:-$PGPASSWORD}"
if [ -z "$ADMIN_PASS" ]; then
  echo "Falta la contrasena de postgres: define DB_PASSWORD o PGPASSWORD."
  exit 1
fi
if [ -e src/proxy.ts ] || [ -e src/middleware.ts ]; then
  echo "Ya existe src/proxy.ts o src/middleware.ts: el guion no lo pisa."
  exit 1
fi
if curl -s -o /dev/null --max-time 3 "http://localhost:3001/"; then
  echo "Hay un servidor en localhost:3001. Paralo: el build escribe en .next."
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
  rm -f src/proxy.ts
  echo ""
  echo "==============================================================="
  echo " LIMPIEZA"
  echo "==============================================================="
  echo "  src/proxy.ts borrado: $([ -e src/proxy.ts ] && echo NO || echo si)"
  echo "  git status de src/proxy.ts: '$(git status --porcelain src/proxy.ts)' (vacio = como en el repositorio)"
  local ids=()
  [ -n "$UID_N" ] && ids+=("'${UID_N}'")
  [ -n "$UID_A" ] && ids+=("'${UID_A}'")
  if [ ${#ids[@]} -gt 0 ]; then
    local lista
    lista=$(IFS=,; echo "${ids[*]}")
    echo "  Cuentas de prueba (como postgres), por id y correo exacto:"
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

# Las mismas siete rutas que evidencia-cita16-cabeceras.sh.
RUTAS=(
  "raiz|/|"
  "login|/login|"
  "inicio_n|/inicio|N"
  "admin_a|/admin|A"
  "admin_anon|/admin|"
  "api_n|/api/citas|N"
  "api_anon|/api/citas|"
)
OBJETIVO=(x-nextjs-cache x-nextjs-prerender x-nextjs-stale-time Vary)

medir() {
  local args=(-s -I)
  case "$3" in
    N) args+=(-b "$JAR_N") ;;
    A) args+=(-b "$JAR_A") ;;
  esac
  curl "${args[@]}" "$WEB$2" | tr -d '\r' \
    | sed -E 's/^([Ss]et-[Cc]ookie: [^=]+=)[^;]*/\1<OCULTO>/' > "$TMP/$1.h"
}

# linea ARCHIVO N: imprime la linea N de un archivo de Next.js con su numero.
linea() { printf '    %s:%s\n      %s\n' "$1" "$2" "$(sed -n "${2}p" "$1" | sed 's/^ *//')"; }

[ -t 1 ] && clear
echo "==============================================================="
echo " CITA-16  Quitar las cabeceras x-nextjs-* con un Proxy (un intento)"
echo " Fecha: $(date '+%Y-%m-%d %H:%M:%S')"
echo " Commit: $(git log -1 --format='%h %s')"
echo " Cambios sin commit en next.config.ts: $(git status --porcelain next.config.ts | wc -l)"
echo " Next.js: $(node -p 'require("next/package.json").version')"
echo "==============================================================="

# ===============================================================
echo ""
echo "==============================================================="
echo " 1. EL PROXY QUE SE PRUEBA, Y LA PREPARACION"
echo "---------------------------------------------------------------"
echo " Esperado: build con codigo 0 y el Proxy registrado; registros"
echo "   201; A promovida a admin; los dos login 200."
echo "==============================================================="
cat > src/proxy.ts <<'FIN'
import { NextResponse } from "next/server";

// Experimento de evidencia-cita16-proxy.sh: intenta borrar de la
// respuesta las cabeceras que delatan el framework.
export function proxy() {
  const respuesta = NextResponse.next();
  for (const nombre of [
    "x-nextjs-cache",
    "x-nextjs-prerender",
    "x-nextjs-stale-time",
    "vary",
  ]) {
    respuesta.headers.delete(nombre);
  }
  return respuesta;
}

export const config = {
  matcher: "/:path*",
};
FIN
echo ""
echo "--- src/proxy.ts (temporal)"
sed 's/^/  | /' src/proxy.ts
echo ""
echo "--- pnpm build"
pnpm build > "$TMP/build.log" 2>&1
CODIGO_BUILD=$?
sed 's/\x1b\[[0-9;]*m//g' "$TMP/build.log" | sed -E 's#postgres(ql)?://[^[:space:]"]*#<URL OCULTA>#g' \
  | grep -E 'Compiled|rror|Proxy' | sed 's/^/  /'
echo "  codigo de salida: ${CODIGO_BUILD}"
[ "$CODIGO_BUILD" != 0 ] && { echo "  El build fallo."; exit 1; }

echo ""
echo "--- next start en el puerto ${PUERTO}"
if ! arrancar; then echo "  El servidor no respondio."; exit 1; fi
echo "  responde /login: HTTP $(curl -s -o /dev/null -w '%{http_code}' "$WEB/login")"

echo ""
echo "--- Cuentas de prueba y sesiones"
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
printf '  login N -> HTTP %s\n' "$(curl -s -o /dev/null -c "$JAR_N" -w '%{http_code}' \
  -X POST "$WEB/api/auth/login" -H "$H" -d "{\"email\":\"${CORREO_N}\",\"password\":\"${CLAVE}\"}")"
printf '  login A -> HTTP %s\n' "$(curl -s -o /dev/null -c "$JAR_A" -w '%{http_code}' \
  -X POST "$WEB/api/auth/login" -H "$H" -d "{\"email\":\"${CORREO_A}\",\"password\":\"${CLAVE}\"}")"

# ===============================================================
echo ""
echo "==============================================================="
echo " 2. RESPUESTA COMPLETA DE curl -I EN CADA RUTA, CON EL PROXY"
echo "---------------------------------------------------------------"
echo " Esperado (prevision, sin medir): las cabeceras NO desaparecen."
echo "   El Proxy se ejecuta ANTES de que Next.js renderice la pagina o"
echo "   ejecute la ruta de la API, y esas cabeceras las pone despues"
echo "   el propio renderizado; en la respuesta que devuelve el Proxy"
echo "   todavia no existen, asi que borrarlas alli no tiene efecto."
echo "   Mismos codigos que sin Proxy: 200 200 200 200 404 200 401."
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
echo " 3. RESUMEN: LAS CABECERAS QUE SE INTENTO QUITAR"
echo "---------------------------------------------------------------"
echo " Esperado: las mismas que en salida-cita16-cabeceras.txt, sin"
echo "   Proxy: x-nextjs-cache HIT, x-nextjs-prerender 1 y"
echo "   x-nextjs-stale-time 300 en / y /login; el Vary con"
echo "   next-router-* en las siete. \"-\" = no viene en la respuesta."
echo "==============================================================="
for c in "${OBJETIVO[@]}"; do
  echo ""
  echo "--- ${c}"
  for r in "${RUTAS[@]}"; do
    IFS='|' read -r etiqueta ruta quien <<< "$r"
    valor=$(grep -i "^${c}:" "$TMP/$etiqueta.h" | cut -d: -f2- | sed 's/^ //' | paste -sd'|' | sed 's/|/  +  /g')
    printf '  %-28s %s\n' "${ruta} (${quien:-sin sesion})" "${valor:--}"
  done
done

# ===============================================================
echo ""
echo "==============================================================="
echo " 4. DE DONDE SALEN LAS CABECERAS (codigo de Next.js)"
echo "---------------------------------------------------------------"
echo " Esperado: se fijan en la respuesta durante el renderizado de la"
echo "   pagina o de la ruta, sin ninguna opcion de configuracion que"
echo "   las desactive."
echo "==============================================================="
echo ""
echo "  Paginas: Vary, x-nextjs-cache y x-nextjs-prerender"
linea "$NDIST/build/templates/app-page-runtime.js" 459
linea "$NDIST/build/templates/app-page-runtime.js" 1056
linea "$NDIST/build/templates/app-page-runtime.js" 1060
echo "  Paginas: x-nextjs-stale-time, que el renderizador deja en las"
echo "  cabeceras que acompañan a la pagina"
linea "$NDIST/server/app-render/app-render.js" 1864
echo "  Rutas de la API: vary"
linea "$NDIST/server/base-server.js" 1225
echo "  Los nombres de las cabeceras"
linea "$NDIST/client/components/app-router-headers.js" 112
linea "$NDIST/client/components/app-router-headers.js" 116

# --------------------------------------------------------------
trap - INT TERM EXIT
limpieza

echo ""
echo "==============================================================="
echo " Resumen de lo esperado:"
echo "   1 -> build 0 con Proxy; registros 201; A admin; logins 200"
echo "   2 y 3 -> las cabeceras siguen: el Proxy no las quita"
echo "   4 -> las pone el renderizado, despues del Proxy"
echo "   Limpieza -> src/proxy.ts borrado; cuentas y sesiones 0;"
echo "        servidor parado"
echo "==============================================================="
