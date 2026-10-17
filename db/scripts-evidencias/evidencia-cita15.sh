#!/usr/bin/env bash
# ---------------------------------------------------------------
#  CitaSegura - Evidencia de CITA-15 (configuracion segura de .env)
#  Uso:  bash evidencia-cita15.sh | tee salida-cita15.txt
#  Requiere: pnpm, psql, node, .env.local, y el servidor de desarrollo
#  PARADO (ver mas abajo).
#
#  Los cuatro criterios de la tarjeta, en este orden:
#    1. Los archivos de entorno estan fuera del control de versiones,
#       y nunca estuvieron en el historial.
#    3. .env.example existe, se puede versionar, y declara los mismos
#       nombres que la aplicacion lee.
#    2. Ningun secreto llega al navegador: se busca el VALOR, no solo
#       el prefijo NEXT_PUBLIC_, en el JavaScript del build y en el
#       HTML que sirven /login, /registro e /inicio.
#    4. La aplicacion se niega a arrancar si falta una variable
#       obligatoria.
#
#  ESTE ES EL GUION CON MAS RIESGO DE FILTRAR LA CONTRASENA, porque la
#  maneja a proposito. Reglas que sigue:
#    - La cadena de conexion y la contrasena se leen de .env.local a
#      variables del shell y NUNCA se imprimen. Solo se imprime cuantas
#      veces aparecen, que debe ser 0.
#    - A grep se le pasan por un descriptor de fichero (-f <(...)), no
#      como argumento: asi tampoco aparecen en la lista de procesos.
#    - Toda salida de Next.js pasa por ocultar(), que tapa cualquier
#      URL postgresql:// por si acaso, y se cuenta cuantas tapo.
#
#  .env.local SE MODIFICA DURANTE EL BLOQUE 4, siempre sobre copia:
#  se saca su hash, se guarda un respaldo fuera del repositorio, se
#  restaura al terminar (tambien si el guion se interrumpe) y se
#  comprueba que el hash coincide. Por eso el servidor de desarrollo
#  tiene que estar parado: next dev vigila .env.local y recargaria
#  cada version intermedia. El guion arranca su PROPIO servidor de
#  produccion (next start) en el puerto 3015 y lo para al terminar.
#
#  Registra UNA cuenta propia (para ver /inicio con sesion) y la borra
#  al final como 'postgres', por id capturado Y correo exacto. La
#  contrasena de postgres se toma de DB_PASSWORD o, si no existe, de
#  PGPASSWORD.
# ---------------------------------------------------------------

PSQL="/c/Program Files/PostgreSQL/18/bin/psql.exe"
PUERTO=3015
WEB="http://localhost:${PUERTO}"
H="Content-Type: application/json"
CLAVE="ClaveEvidencia1!"
SUFIJO=$(date +%H%M%S)
CORREO="prueba.cita15.${SUFIJO}@ejemplo.com"
DIR=$(cd "$(dirname "$0")" && pwd)
RAIZ=$(cd "$DIR/../.." && pwd)
NEXT="$RAIZ/node_modules/next/dist/bin/next"
cd "$RAIZ" || exit 1

ADMIN_PASS="${DB_PASSWORD:-$PGPASSWORD}"
if [ -z "$ADMIN_PASS" ]; then
  echo "Falta la contrasena de postgres: define DB_PASSWORD o PGPASSWORD."
  exit 1
fi

# Los dos secretos que se buscan. Se leen y no se muestran nunca.
SECRETO_URL=$(sed -n 's|^DATABASE_URL=||p' .env.local | tr -d '\r')
SECRETO_PASS=$(printf '%s' "$SECRETO_URL" | sed -n 's|^postgres[a-z]*://[^:]*:\([^@]*\)@.*|\1|p')
if [ -z "$SECRETO_URL" ] || [ -z "$SECRETO_PASS" ]; then
  echo "No se pudo leer DATABASE_URL (con contrasena) de .env.local."
  exit 1
fi

if curl -s -o /dev/null --max-time 3 "http://localhost:3001/"; then
  echo "Hay un servidor en localhost:3001. Paralo antes de ejecutar este"
  echo "guion: el bloque 4 modifica .env.local (sobre copia, y lo restaura),"
  echo "y next dev recargaria cada version intermedia."
  exit 1
fi
if curl -s -o /dev/null --max-time 3 "$WEB/"; then
  echo "El puerto ${PUERTO} esta ocupado; el guion arranca alli su servidor."
  exit 1
fi

TMP=$(mktemp -d)
JAR="$TMP/sesion.jar"
SERVIDOR_PID=""

admin() { PGPASSWORD="$ADMIN_PASS" "$PSQL" -h 127.0.0.1 -U postgres -d citasegura "$@" 2>&1; }

# cuenta SECRETO FICHEROS...: cuantas veces aparece el valor, sin
# imprimirlo. -F literal, -o una linea por aparicion.
cuenta() {
  local secreto="$1"; shift
  [ $# -eq 0 ] && { echo 0; return; }
  grep -o -F -f <(printf '%s\n' "$secreto") -- "$@" 2>/dev/null | wc -l
}

# Tapa cualquier cadena de conexion en la salida de Next.js.
TAPADAS=0
ocultar() { sed -E 's#postgres(ql)?://[^[:space:]"]*#<URL OCULTA>#g'; }
anotar_tapadas() { TAPADAS=$((TAPADAS + $(grep -c -E 'postgres(ql)?://' "$1"))); }

arrancar() {  # arranca next start en segundo plano y espera a que responda
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

# Respaldo de .env.local para el bloque 4.
HASH_ANTES=$(sha256sum .env.local | cut -d' ' -f1)
cp -p .env.local "$TMP/env.local.respaldo"
restaurar_env() {
  [ -f "$TMP/env.local.respaldo" ] && cp -p "$TMP/env.local.respaldo" .env.local
}

LIMPIADO=0
limpieza() {
  [ "$LIMPIADO" = 1 ] && return
  LIMPIADO=1
  parar
  restaurar_env
  echo ""
  echo "==============================================================="
  echo " LIMPIEZA"
  echo "==============================================================="
  local hash_despues
  hash_despues=$(sha256sum .env.local | cut -d' ' -f1)
  echo "  .env.local  hash antes:   ${HASH_ANTES:0:12}...  (primeros 12 de 64)"
  echo "              hash despues: ${hash_despues:0:12}..."
  if [ "$HASH_ANTES" = "$hash_despues" ]; then
    echo "              RESULTADO: identico byte a byte"
  else
    echo "              RESULTADO: DISTINTO. El respaldo esta en $TMP/env.local.respaldo"
    return
  fi
  if [ -n "$UID_N" ]; then
    echo "  Cuenta de prueba (como postgres, por id y correo exacto):"
    admin -c "DELETE FROM users WHERE id = '${UID_N}' AND email = '${CORREO}'
              RETURNING email;" | sed 's/^/    /'
    admin -c "SELECT (SELECT count(*) FROM users    WHERE id      = '${UID_N}') AS cuentas,
                     (SELECT count(*) FROM sessions WHERE user_id = '${UID_N}') AS sesiones;" \
      | sed 's/^/    /'
  fi
  rm -rf "$TMP"
  echo "  Copias temporales borradas: $([ -d "$TMP" ] && echo NO || echo si)"
  echo "  Archivos .env* en la raiz del repositorio: $(ls -a | grep -E '^\.env' | tr '\n' ' ')"
  local queda
  queda=$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 "$WEB/login")
  echo "  Servidor del guion en el puerto ${PUERTO}: $([ "$queda" = 000 ] && echo parado || echo "SIGUE RESPONDIENDO ($queda)")"
}
# EXIT tambien: si el guion se corta por cualquier motivo, .env.local
# se restaura igual. limpieza() solo actua una vez.
trap 'limpieza; exit 130' INT TERM
trap limpieza EXIT

[ -t 1 ] && clear
echo "==============================================================="
echo " CITA-15  Configuracion segura de .env"
echo " Fecha: $(date '+%Y-%m-%d %H:%M:%S')"
echo " Commit: $(git log -1 --format='%h %s')"
echo "==============================================================="

# ===============================================================
echo ""
echo "==============================================================="
echo " CRITERIO 1. Los archivos de entorno estan fuera de git"
echo "---------------------------------------------------------------"
echo " Esperado: todos los .env* ignorados por la regla .env*, salvo"
echo "   .env.example (regla !.env.example); ningun .env versionado"
echo "   salvo el ejemplo; 0 commits con archivos de entorno; la"
echo "   contrasena actual 0 veces en el historial y en lo versionado."
echo "==============================================================="
echo ""
echo "--- 1.1 git check-ignore -v"
for f in .env .env.local .env.development .env.development.local \
         .env.production .env.production.local .env.test; do
  regla=$(git check-ignore -v "$f" | cut -f1)
  printf '  %-24s -> %s\n' "$f" "${regla:-NO IGNORADO}"
done
if git check-ignore -q .env.example; then
  printf '  %-24s -> %s\n' ".env.example" "IGNORADO"
else
  printf '  %-24s -> no ignorado (%s)\n' ".env.example" "$(git check-ignore -v --no-index .env.example | cut -f1)"
fi

echo "  git status --ignored: $(git status --porcelain --ignored .env.local .env.example | tr '\n' ' ')"
echo "  (!! = ignorado, ?? = sin versionar pero NO ignorado)"

echo ""
echo "--- 1.2 Archivos de entorno versionados (git ls-files)"
VERSIONADOS=$(git ls-files | grep -E '(^|/)\.env' )
echo "${VERSIONADOS:-  (ninguno)}" | sed 's/^\([^ ]\)/  \1/'

echo ""
echo "--- 1.3 Historial completo, todas las ramas"
echo "  git log --all --full-history -- .env .env.local .env.development"
echo "          .env.development.local .env.production .env.production.local .env.test"
N_COMMITS=$(git log --all --full-history --format=%h -- .env .env.local \
  .env.development .env.development.local .env.production .env.production.local \
  .env.test | wc -l)
echo "  commits que tocan alguno: ${N_COMMITS}"
echo "  la contrasena actual en el historial (git log --all -p): $(git log --all -p | cuenta "$SECRETO_PASS" /dev/stdin)"
echo "  la contrasena actual en los archivos versionados hoy:    $(git ls-files -z | xargs -0 cat 2>/dev/null | cuenta "$SECRETO_PASS" /dev/stdin)"

# ===============================================================
echo ""
echo "==============================================================="
echo " CRITERIO 3. Archivo de ejemplo con los nombres y sin valores"
echo "---------------------------------------------------------------"
echo " Esperado: .env.example existe, no esta ignorado y git lo"
echo "   versiona (o lo versionara en el proximo commit); los nombres"
echo "   que declara son EXACTAMENTE los que lee la aplicacion; su"
echo "   valor es un marcador evidente y la contrasena real aparece 0"
echo "   veces en el."
echo "==============================================================="
echo ""
echo "--- 3.1 Estado en git"
if git ls-files --error-unmatch .env.example > /dev/null 2>&1; then
  echo "  versionado: si (git ls-files lo lista)"
else
  echo "  versionado: todavia no (pendiente de commit)"
  echo "  git add --dry-run .env.example -> $(git add --dry-run .env.example 2>&1)"
fi

echo ""
echo "--- 3.2 Nombres: declarados frente a leidos"
nombres_de() { sed -nE 's/^([A-Za-z_][A-Za-z0-9_]*)=.*/\1/p' "$1" | sort -u; }
nombres_de .env.example > "$TMP/ejemplo"
nombres_de .env.local   > "$TMP/local"
# Lo que la aplicacion lee: las claves del esquema de src/lib/env.ts...
sed -n '/const esquemaEntorno = z.object({/,/^});/p' src/lib/env.ts \
  | sed -nE 's/^  ([A-Z_][A-Z0-9_]*): z.*/\1/p' | sort -u > "$TMP/esquema"
# ...y cualquier process.env.X del codigo, salvo las que pone el propio
# Node.js o Next.js y no se configuran en .env: NODE_ENV y NEXT_RUNTIME.
grep -rhoE 'process\.env\.[A-Z_][A-Z0-9_]*' src \
  | sed 's/process\.env\.//' | grep -vxE 'NODE_ENV|NEXT_RUNTIME' | sort -u > "$TMP/codigo"
echo "  declaradas en .env.example:          $(tr '\n' ' ' < "$TMP/ejemplo")"
echo "  claves del esquema (src/lib/env.ts): $(tr '\n' ' ' < "$TMP/esquema")"
echo "  process.env.X fuera del esquema:     $(tr '\n' ' ' < "$TMP/codigo")(excluidas NODE_ENV y NEXT_RUNTIME)"
echo "  nombres en .env.local:               $(tr '\n' ' ' < "$TMP/local")"
sort -u "$TMP/esquema" "$TMP/codigo" > "$TMP/leidas"
if cmp -s "$TMP/ejemplo" "$TMP/leidas" && cmp -s "$TMP/ejemplo" "$TMP/local"; then
  echo "  RESULTADO: los tres conjuntos coinciden"
else
  echo "  RESULTADO: NO coinciden"
fi

echo ""
echo "--- 3.3 Valores del ejemplo"
sed -nE 's/^([A-Za-z_][A-Za-z0-9_]*)=.*/  \1=.../p' .env.example
echo "  contiene el marcador CAMBIAR_POR_LA_CONTRASENA:  $(grep -c 'CAMBIAR_POR_LA_CONTRASENA' .env.example)"
echo "  la contrasena real en .env.example:              $(cuenta "$SECRETO_PASS" .env.example)"

# ===============================================================
echo ""
echo "==============================================================="
echo " CRITERIO 2. Ningun secreto llega al navegador"
echo "---------------------------------------------------------------"
echo " Esperado: build correcto; 0 variables NEXT_PUBLIC_; la URL de"
echo "   conexion y la contrasena 0 veces en .next/static y 0 en el"
echo "   HTML de /login, /registro e /inicio (esta ultima con sesion,"
echo "   HTTP 200)."
echo "==============================================================="
echo ""
echo "--- 2.1 pnpm build"
pnpm build > "$TMP/build.log" 2>&1
CODIGO_BUILD=$?
anotar_tapadas "$TMP/build.log"
sed 's/\x1b\[[0-9;]*m//g' "$TMP/build.log" | ocultar \
  | grep -E 'Environments|Compiled|Generating static pages.*\(|rror|arning' | sed 's/^/  /'
echo "  codigo de salida: ${CODIGO_BUILD}"
if [ "$CODIGO_BUILD" != 0 ]; then
  echo "  El build fallo: no se puede seguir con este criterio."
  limpieza; exit 1
fi

echo ""
echo "--- 2.2 Variables con el prefijo NEXT_PUBLIC_"
echo "  declaradas en .env.local:     $(grep -cE '^NEXT_PUBLIC_' .env.local)"
echo "  declaradas en .env.example:   $(grep -cE '^NEXT_PUBLIC_' .env.example)"
echo "  leidas en src/ (process.env): $(grep -rhoE 'process\.env\.NEXT_PUBLIC_[A-Z0-9_]*' src | wc -l)"

echo ""
echo "--- 2.3 El VALOR en el JavaScript que se descarga el navegador"
mapfile -t ESTATICOS < <(find .next/static -name '*.js')
echo "  ficheros .js revisados en .next/static: ${#ESTATICOS[@]}"
echo "  URL de conexion:  $(cuenta "$SECRETO_URL"  "${ESTATICOS[@]}")"
echo "  contrasena:       $(cuenta "$SECRETO_PASS" "${ESTATICOS[@]}")"

echo ""
echo "--- 2.4 El VALOR en el HTML servido"
echo "  (un Server Component podria pasar un secreto como prop a un"
echo "   Client Component; viajaria serializado dentro del HTML)"
if ! arrancar; then
  echo "  El servidor del guion no respondio en el puerto ${PUERTO}."
  limpieza; exit 1
fi
curl -s -o /dev/null -w "  registro de cuenta de prueba -> HTTP %{http_code}\n" \
  -X POST "$WEB/api/auth/register" -H "$H" \
  -d "{\"name\":\"Prueba Cita15\",\"email\":\"${CORREO}\",\"password\":\"${CLAVE}\"}"
UID_N=$(admin -t -A -c "SELECT id FROM users WHERE email = '${CORREO}';")
echo "    id capturado: ${UID_N:-NINGUNO}"
curl -s -o /dev/null -c "$JAR" -w "  login -> HTTP %{http_code}\n" \
  -X POST "$WEB/api/auth/login" -H "$H" -d "{\"email\":\"${CORREO}\",\"password\":\"${CLAVE}\"}"
for ruta in /login /registro /inicio; do
  fichero="$TMP/pagina$(echo "$ruta" | tr '/' '_')"
  codigo=$(curl -s -b "$JAR" -o "$fichero" -w '%{http_code}' "$WEB$ruta")
  printf '  %-9s HTTP %s  %6s bytes   URL: %s   contrasena: %s\n' "$ruta" "$codigo" \
    "$(wc -c < "$fichero")" "$(cuenta "$SECRETO_URL" "$fichero")" "$(cuenta "$SECRETO_PASS" "$fichero")"
done
echo "  control: /inicio lleva el panel (no una redireccion): $(grep -c 'Mis citas' "$TMP/pagina_inicio")"
parar
anotar_tapadas "$TMP/servidor.log"

echo ""
echo "--- 2.5 Fuera del navegador: el build del servidor"
echo "  (informativo: el servidor SI puede tener el secreto, pero lo lee"
echo "   al arrancar; no deberia quedar escrito en el build)"
mapfile -t DEL_SERVIDOR < <(find .next/server -type f)
echo "  ficheros revisados en .next/server: ${#DEL_SERVIDOR[@]}"
echo "  URL de conexion:  $(cuenta "$SECRETO_URL"  "${DEL_SERVIDOR[@]}")"
echo "  contrasena:       $(cuenta "$SECRETO_PASS" "${DEL_SERVIDOR[@]}")"

# ===============================================================
echo ""
echo "==============================================================="
echo " CRITERIO 4. Sin una variable obligatoria, no arranca"
echo "---------------------------------------------------------------"
echo " Esperado: en los tres casos next start termina solo con"
echo "   codigo 1, sin atender ninguna peticion, y el mensaje nombra"
echo "   DATABASE_URL y el problema sin mostrar ningun valor. Al"
echo "   restaurar .env.local, arranca y responde 200."
echo "==============================================================="

intento() {  # intento ETIQUETA: arranca con el .env.local actual y mide
  echo ""
  echo "--- $1"
  timeout 60 node "$NEXT" start -p "$PUERTO" > "$TMP/arranque.log" 2>&1
  local salida=$?
  anotar_tapadas "$TMP/arranque.log"
  echo "  codigo de salida: ${salida}$([ "$salida" = 124 ] && echo '  (SEGUIA VIVO a los 60 s: lo corto timeout)')"
  echo "  peticion a /login despues: HTTP $(curl -s -o /dev/null -w '%{http_code}' --max-time 3 "$WEB/login")"
  echo "  mensaje:"
  sed 's/\x1b\[[0-9;]*m//g' "$TMP/arranque.log" | ocultar \
    | grep -vE 'Local:|Network:|^\s*$' | sed 's/^/    /'
}

grep -v '^DATABASE_URL=' "$TMP/env.local.respaldo" > .env.local
intento "4.1 .env.local sin la linea DATABASE_URL (variable AUSENTE)"

cp .env.example .env.local
intento "4.2 .env.local copiado de .env.example sin editar (marcador)"

printf 'DATABASE_URL=postgresql://postgres:sinvalorreal@localhost:5432/citasegura\n' > .env.local
intento "4.3 DATABASE_URL con el superusuario postgres"

restaurar_env
echo ""
echo "--- 4.4 Control: .env.local restaurado"
if arrancar; then
  echo "  arranca y /login responde HTTP $(curl -s -o /dev/null -w '%{http_code}' "$WEB/login")"
else
  echo "  NO ARRANCO con el .env.local original"
fi
parar
anotar_tapadas "$TMP/servidor.log"

echo ""
echo "--- Cadenas de conexion tapadas por ocultar() en toda la salida de Next.js: ${TAPADAS}"

# --------------------------------------------------------------
trap - INT TERM EXIT
limpieza

echo ""
echo "==============================================================="
echo " Resumen de lo esperado:"
echo "   1 -> todos ignorados salvo .env.example; ninguno versionado"
echo "        salvo el ejemplo; 0 commits; contrasena 0 y 0"
echo "   3 -> no ignorado y versionable; los tres conjuntos de nombres"
echo "        coinciden; marcador 1, contrasena 0"
echo "   2 -> build 0; NEXT_PUBLIC_ 0, 0 y 0; URL y contrasena 0 en"
echo "        .next/static y en las tres paginas (las tres HTTP 200)"
echo "   4 -> 4.1 a 4.3 codigo 1, HTTP 000 y el problema nombrado sin"
echo "        valores; 4.4 HTTP 200"
echo "   Cadenas tapadas: 0 (Next.js nunca imprimio una URL de conexion)"
echo "   Limpieza -> hash identico; cuenta borrada; cuentas y sesiones 0;"
echo "        temporales borradas; servidor parado"
echo "==============================================================="
