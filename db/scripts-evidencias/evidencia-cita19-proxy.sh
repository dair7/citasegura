#!/usr/bin/env bash
# ---------------------------------------------------------------
#  CitaSegura - Evidencia de CITA-19: la reescritura en el Proxy
#  Uso:  bash evidencia-cita19-proxy.sh | tee salida-cita19-proxy.txt
#  Requiere: pnpm, node, .env.local, y el servidor de desarrollo PARADO.
#
#  QUE MIDE: si un Proxy de Next.js que reescribe /admin hacia una ruta
#  inexistente consigue que la respuesta sea identica a la de una ruta
#  inventada, en codigo, cuerpo Y cabeceras. Es la alternativa que se
#  probo para cerrar la limitacion 10 y que se descarto.
#
#  EL PROXY DE ESTE GUION REESCRIBE SIEMPRE, sin mirar la sesion. Es el
#  caso mas favorable: un Proxy real tendria ademas que validar la
#  sesion, pero ante un no administrador haria exactamente esta misma
#  reescritura. Si ni asi la respuesta sale identica, el Proxy real
#  tampoco.
#
#  MODIFICA EL ARBOL DE TRABAJO: crea src/proxy.ts, que no existe en el
#  repositorio, y lo borra al terminar, tambien si el guion se
#  interrumpe. Se niega a empezar si ya existe un src/proxy.ts o un
#  src/middleware.ts, para no pisar nada. El .next que deja el build
#  incluye el Proxy: evidencia-cita19.sh vuelve a compilar sin el.
# ---------------------------------------------------------------

PUERTO=3019
WEB="http://localhost:${PUERTO}"
SUFIJO=$(date +%H%M%S)
INVENTADA="/ruta-inventada-${SUFIJO}"
DIR=$(cd "$(dirname "$0")" && pwd)
RAIZ=$(cd "$DIR/../.." && pwd)
NEXT="$RAIZ/node_modules/next/dist/bin/next"
RESOLVE="$RAIZ/node_modules/next/dist/server/lib/router-utils/resolve-routes.js"
cd "$RAIZ" || exit 1

if [ -e src/proxy.ts ] || [ -e src/middleware.ts ]; then
  echo "Ya existe src/proxy.ts o src/middleware.ts: el guion no lo pisa."
  exit 1
fi
if curl -s -o /dev/null --max-time 3 "http://localhost:3001/"; then
  echo "Hay un servidor en localhost:3001. Paralo: el build escribe en .next."
  exit 1
fi
if curl -s -o /dev/null --max-time 3 "$WEB/"; then
  echo "El puerto ${PUERTO} esta ocupado."
  exit 1
fi

TMP=$(mktemp -d)
SERVIDOR_PID=""
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
  rm -rf "$TMP"
  echo ""
  echo "==============================================================="
  echo " LIMPIEZA"
  echo "==============================================================="
  echo "  src/proxy.ts borrado: $([ -e src/proxy.ts ] && echo NO || echo si)"
  echo "  git status de src/proxy.ts: '$(git status --porcelain src/proxy.ts)' (vacio = como en el repositorio)"
  local queda
  queda=$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 "$WEB/login")
  echo "  Servidor del guion en el puerto ${PUERTO}: $([ "$queda" = 000 ] && echo parado || echo "SIGUE RESPONDIENDO ($queda)")"
}
trap 'limpieza; exit 130' INT TERM
trap limpieza EXIT

# localizar ARCHIVO PATRON: deja en LINEA el numero de la unica linea del
# archivo que contiene PATRON (texto literal, no expresion regular).
# POR QUE NO UN NUMERO FIJO: los numeros de linea cambian con cada
# version de Next.js. Con un numero escrito a mano, al actualizar, el
# guion imprimia otras lineas sin avisar, y la salida parecia correcta
# sin serlo. Si el patron no aparece, o aparece mas de una vez, LINEA
# queda vacia, se dice en la salida y el guion termina con codigo 1.
FALLOS=0
localizar() {
  local archivo="$1" patron="$2" coincidencias n
  LINEA=""
  coincidencias=$(grep -n -F -- "$patron" "$archivo" 2>&1)
  n=$(printf '%s' "$coincidencias" | grep -c '^[0-9]')
  if [ "$n" = 1 ]; then
    LINEA=${coincidencias%%:*}
  else
    echo "  ${archivo#$RAIZ/}"
    echo "    FALLO DEL GUION: el patron aparece ${n} veces (se esperaba 1); esta medida no vale."
    echo "    patron: ${patron}"
    FALLOS=$((FALLOS + 1))
  fi
}

[ -t 1 ] && clear
echo "==============================================================="
echo " CITA-19  Reescritura de /admin en el Proxy (descartada)"
echo " Fecha: $(date '+%Y-%m-%d %H:%M:%S')"
echo " Commit: $(git log -1 --format='%h %s')"
echo " Next.js: $(node -p 'require("next/package.json").version')"
echo "==============================================================="

echo ""
echo "==============================================================="
echo " 1. EL PROXY QUE SE PRUEBA"
echo "---------------------------------------------------------------"
echo " Esperado: build con codigo 0 y el Proxy registrado."
echo "==============================================================="
cat > src/proxy.ts <<'FIN'
import { NextResponse, type NextRequest } from "next/server";

// Experimento de evidencia-cita19-proxy.sh: reescribe SIEMPRE.
export function proxy(request: NextRequest) {
  return NextResponse.rewrite(new URL("/__no-existe", request.url));
}

export const config = {
  matcher: "/admin",
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
  | grep -E 'Compiled|rror|/admin|Proxy' | sed 's/^/  /'
echo "  codigo de salida: ${CODIGO_BUILD}"
[ "$CODIGO_BUILD" != 0 ] && exit 1

node "$NEXT" start -p "$PUERTO" > "$TMP/servidor.log" 2>&1 &
SERVIDOR_PID=$!
for _ in $(seq 1 30); do curl -s -o /dev/null --max-time 2 "$WEB/login" && break; sleep 1; done

echo ""
echo "==============================================================="
echo " 2. ANONIMO -> /admin (reescrita), frente a una ruta inventada"
echo "---------------------------------------------------------------"
echo " Esperado, segun la medicion del 19 de octubre: codigo 404 en las"
echo "   dos y cuerpo IDENTICO byte a byte; cabeceras identicas salvo"
echo "   una, x-middleware-rewrite, que solo lleva /admin."
echo "==============================================================="
echo ""
for par in "admin:/admin" "inv:${INVENTADA}"; do
  IFS=: read -r nombre ruta <<< "$par"
  curl -s -D "$TMP/$nombre.h" -o "$TMP/$nombre.b" "$WEB$ruta"
  printf '  GET %-30s HTTP %s  %5s bytes\n' "$ruta" "$(head -1 "$TMP/$nombre.h" | cut -d' ' -f2)" "$(wc -c < "$TMP/$nombre.b")"
  tr -d '\r' < "$TMP/$nombre.h" | grep -vi '^date:' > "$TMP/$nombre.hs"
done
cmp -s "$TMP/admin.b" "$TMP/inv.b" && echo "  cuerpo:     IDENTICO byte a byte" \
  || echo "  cuerpo:     DISTINTO ($(cmp "$TMP/admin.b" "$TMP/inv.b" | sed 's/.*differ: //'))"
if cmp -s "$TMP/admin.hs" "$TMP/inv.hs"; then
  echo "  cabeceras:  IDENTICAS (sin Date)"
else
  echo "  cabeceras:  DISTINTAS (sin Date). < solo en /admin, > solo en la inventada:"
  diff "$TMP/admin.hs" "$TMP/inv.hs" | grep '^[<>]' | sed 's/^/    /'
fi
echo ""
echo "  Cabeceras completas de /admin reescrita (sin Date):"
sed 's/^/    /' "$TMP/admin.hs"

echo ""
echo "==============================================================="
echo " 3. DE DONDE SALE LA CABECERA"
echo "---------------------------------------------------------------"
echo " Esperado: Next.js copia el destino de la reescritura a las"
echo "   cabeceras de la RESPUESTA sin ninguna condicion que se pueda"
echo "   configurar."
echo "==============================================================="
echo ""
# El bloque va desde la condicion que mira si el Proxy reescribio hasta
# la linea que copia el destino a las cabeceras de la respuesta. Se
# localizan las dos; si no estan, o no forman un bloque corto en ese
# orden, no se imprime nada que pueda pasar por el codigo correcto.
localizar "$RESOLVE" "if (middlewareHeaders['x-middleware-rewrite']) {"
L_IF=$LINEA
localizar "$RESOLVE" "resHeaders['x-middleware-rewrite'] = destination;"
L_ASIG=$LINEA
if [ -n "$L_IF" ] && [ -n "$L_ASIG" ]; then
  if [ "$L_ASIG" -gt "$L_IF" ] && [ $((L_ASIG - L_IF)) -le 5 ]; then
    echo "  ${RESOLVE#$RAIZ/}, lineas ${L_IF} a ${L_ASIG}:"
    sed -n "${L_IF},${L_ASIG}p" "$RESOLVE" | sed 's/^ */    /'
  else
    echo "  ${RESOLVE#$RAIZ/}"
    echo "    FALLO DEL GUION: la condicion (linea ${L_IF}) y la asignacion (linea ${L_ASIG})"
    echo "    no forman un bloque de como mucho 5 lineas en ese orden; esta medida no vale."
    FALLOS=$((FALLOS + 1))
  fi
fi

trap - INT TERM EXIT
limpieza
echo ""
if [ "$FALLOS" -gt 0 ]; then
  echo " RESULTADO DEL GUION: ${FALLOS} medida(s) no se pudieron hacer"
  echo " (ver FALLO DEL GUION). Esta salida NO vale como evidencia."
  exit 1
fi
echo " RESULTADO DEL GUION: todas las medidas se hicieron."
