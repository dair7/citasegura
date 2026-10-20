#!/usr/bin/env bash
# ---------------------------------------------------------------
#  CitaSegura - Evidencia de CITA-19 (vista de administrador)
#  Uso:  bash evidencia-cita19.sh | tee salida-cita19.txt
#  Requiere: pnpm, psql, node, .env.local, y el servidor de desarrollo
#  PARADO: el guion hace su propio build de produccion, que escribe en
#  .next, y arranca next start en el puerto 3019. Lo para al terminar.
#
#  POR QUE PRODUCCION Y NO DESARROLLO: la prueba central compara byte a
#  byte el 404 de /admin con el de una ruta que no existe. En modo
#  desarrollo Next.js añade a las respuestas cosas que en produccion no
#  estan, y una comparacion alli no demostraria nada sobre el sistema
#  que se entrega.
#
#  Registra DOS cuentas por la API: N (se queda como usuario normal) y
#  A (se promueve a administrador como postgres, que es el unico camino:
#  criterio 6). N agenda una cita por la API para que la vista tenga
#  algo propio que mostrar. Al terminar se borran las dos como postgres,
#  por id capturado Y correo exacto; sus citas y sesiones caen en
#  cascada. La contrasena de postgres se toma de DB_PASSWORD o, si no
#  existe, de PGPASSWORD.
#
#  SECRETOS: el hash bcrypt de la cuenta N se lee como postgres a una
#  variable para buscarlo en el HTML, y NUNCA se imprime: solo se
#  imprime cuantas veces aparece. Se le pasa a grep por un descriptor
#  de fichero, no como argumento.
# ---------------------------------------------------------------

PSQL="/c/Program Files/PostgreSQL/18/bin/psql.exe"
PUERTO=3019
WEB="http://localhost:${PUERTO}"
H="Content-Type: application/json"
CLAVE="ClaveEvidencia1!"
SUFIJO=$(date +%H%M%S)
CORREO_N="prueba.cita19.n.${SUFIJO}@ejemplo.com"
CORREO_A="prueba.cita19.a.${SUFIJO}@ejemplo.com"
MOTIVO="Control CITA-19 ${SUFIJO}"
FUTURA=$(date -d '+4 days' +%Y-%m-%dT11:00:00-05:00)
INVENTADA="/ruta-inventada-${SUFIJO}"
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

# cuenta SECRETO FICHERO: cuantas veces aparece, sin imprimirlo.
cuenta() { grep -o -F -f <(printf '%s\n' "$1") -- "$2" 2>/dev/null | wc -l; }

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
    admin -c "SELECT (SELECT count(*) FROM users        WHERE id      IN (${lista})) AS cuentas,
                     (SELECT count(*) FROM appointments WHERE user_id IN (${lista})) AS citas,
                     (SELECT count(*) FROM sessions     WHERE user_id IN (${lista})) AS sesiones,
                     (SELECT count(*) FROM appointments WHERE reason = '${MOTIVO}') AS cita_de_control;" \
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

# pedir NOMBRE RUTA [JAR]: guarda cuerpo y cabeceras en $TMP/NOMBRE.*
pedir() {
  local nombre=$1 ruta=$2 jar=${3:-}
  local args=(-s -D "$TMP/$nombre.h" -o "$TMP/$nombre.b" -w '%{http_code}')
  [ -n "$jar" ] && args+=(-b "$jar")
  curl "${args[@]}" "$WEB$ruta"
}

# comparar ETIQUETA A B: codigo, cuerpo y cabeceras de dos respuestas.
# Las cabeceras se comparan sin Date, que cambia de un segundo a otro
# y no dice nada de la ruta.
comparar() {
  local a=$1 b=$2
  printf '  %-34s HTTP %s  %5s bytes\n' "GET /admin" "$(head -1 "$TMP/$a.h" | cut -d' ' -f2)" "$(wc -c < "$TMP/$a.b")"
  printf '  %-34s HTTP %s  %5s bytes\n' "GET $INVENTADA" "$(head -1 "$TMP/$b.h" | cut -d' ' -f2)" "$(wc -c < "$TMP/$b.b")"
  if cmp -s "$TMP/$a.b" "$TMP/$b.b"; then
    echo "  cuerpo:     IDENTICO byte a byte"
  else
    echo "  cuerpo:     DISTINTO ($(cmp "$TMP/$a.b" "$TMP/$b.b" | sed 's/.*differ: //'))"
  fi
  tr -d '\r' < "$TMP/$a.h" | grep -vi '^date:' > "$TMP/$a.hs"
  tr -d '\r' < "$TMP/$b.h" | grep -vi '^date:' > "$TMP/$b.hs"
  if cmp -s "$TMP/$a.hs" "$TMP/$b.hs"; then
    echo "  cabeceras:  IDENTICAS (sin Date)"
  else
    echo "  cabeceras:  DISTINTAS (sin Date). < solo en /admin, > solo en la inventada:"
    diff "$TMP/$a.hs" "$TMP/$b.hs" | grep '^[<>]' | cut -c1-150 | sed 's/^/    /'
  fi
  echo "  Que delata la ruta dentro del cuerpo (apariciones):"
  printf '    %-52s %3s  %3s\n' "" "/admin" "inventada"
  for marca in 'id="__next_error__"' '\"c\":[\"\",\"admin\"]' '\"c\":[\"\",\"_not-found\"]' \
               'NEXT_HTTP_ERROR_FALLBACK;404' 'This page could not be found.'; do
    printf '    %-52s %3s  %3s\n' "$marca" "$(cuenta "$marca" "$TMP/$a.b")" "$(cuenta "$marca" "$TMP/$b.b")"
  done
}

# reordenado A B: si dos respuestas que no son identicas tienen el
# mismo contenido en otro orden. Compara tres cosas: el tamaño, el HTML
# sin los <script>, y los trozos de la carga util RSC (lo que Next.js
# empuja con self.__next_f.push) ordenados alfabeticamente.
trozos() {
  node -e '
    const s = require("fs").readFileSync(process.argv[1], "utf8");
    const re = /self\.__next_f\.push\(\[1,("(?:[^"\\]|\\.)*")\]\)/g;
    let carga = "";
    for (const m of s.matchAll(re)) carga += JSON.parse(m[1]);
    console.log(carga.split("\n").sort().join("\n"));
  ' "$1"
}
sin_scripts() {
  node -e '
    const s = require("fs").readFileSync(process.argv[1], "utf8");
    process.stdout.write(s.replace(/<script[^>]*>[\s\S]*?<\/script>/g, ""));
  ' "$1"
}
reordenado() {
  local a=$1 b=$2
  echo "      mismo tamaño:                       $([ "$(wc -c < "$TMP/$a.b")" = "$(wc -c < "$TMP/$b.b")" ] && echo si || echo NO)"
  echo "      mismo HTML fuera de los <script>:   $(cmp -s <(sin_scripts "$TMP/$a.b") <(sin_scripts "$TMP/$b.b") && echo si || echo NO)"
  echo "      mismos trozos RSC, sin mirar orden: $(cmp -s <(trozos "$TMP/$a.b") <(trozos "$TMP/$b.b") && echo si || echo NO)"
}

[ -t 1 ] && clear
echo "==============================================================="
echo " CITA-19  Vista de administrador"
echo " Fecha: $(date '+%Y-%m-%d %H:%M:%S')"
echo " Commit: $(git log -1 --format='%h %s')"
echo " Cambios sin commit en src/: $(git status --porcelain src | wc -l) archivos"
echo " Servidor: build de produccion, next start en el puerto ${PUERTO}"
echo "==============================================================="

# ===============================================================
echo ""
echo "==============================================================="
echo " 0. PREPARACION"
echo "---------------------------------------------------------------"
echo " Esperado: build con codigo 0 y /admin como ruta dinamica (f);"
echo "   las dos cuentas registradas por la API (201); A promovida a"
echo "   admin como postgres; N agenda una cita (201); los dos login 200."
echo "==============================================================="
echo ""
echo "--- 0.1 pnpm build"
pnpm build > "$TMP/build.log" 2>&1
CODIGO_BUILD=$?
sed 's/\x1b\[[0-9;]*m//g' "$TMP/build.log" | sed -E 's#postgres(ql)?://[^[:space:]"]*#<URL OCULTA>#g' \
  | grep -E 'Compiled|rror|/admin|Proxy' | sed 's/^/  /'
echo "  codigo de salida: ${CODIGO_BUILD}"
[ "$CODIGO_BUILD" != 0 ] && { echo "  El build fallo."; exit 1; }
echo "  Proxy (middleware) en src/: $(ls src/proxy.ts src/middleware.ts 2>/dev/null | wc -l) archivos"

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

echo ""
echo "--- 0.4 A se promueve a administrador COMO POSTGRES (criterio 6)"
echo "  La aplicacion no tiene ninguna forma de hacerlo: citasegura_app no"
echo "  puede escribir la columna role (evidencias 1.4, 6.6 y 6.7)."
admin -c "UPDATE users SET role = 'admin'
           WHERE id = '${UID_A}' AND email = '${CORREO_A}'
          RETURNING email, role;" | sed 's/^/    /'
admin -c "SELECT has_column_privilege('citasegura_app', 'users', 'role', 'INSERT') AS app_insert_role,
                 has_column_privilege('citasegura_app', 'users', 'role', 'UPDATE') AS app_update_role;" \
  | sed 's/^/    /'

echo ""
echo "--- 0.5 Sesiones, y la cita de control de N"
printf '  login N -> HTTP %s\n' "$(curl -s -o /dev/null -c "$JAR_N" -w '%{http_code}' \
  -X POST "$WEB/api/auth/login" -H "$H" -d "{\"email\":\"${CORREO_N}\",\"password\":\"${CLAVE}\"}")"
printf '  login A -> HTTP %s\n' "$(curl -s -o /dev/null -c "$JAR_A" -w '%{http_code}' \
  -X POST "$WEB/api/auth/login" -H "$H" -d "{\"email\":\"${CORREO_A}\",\"password\":\"${CLAVE}\"}")"
printf '  N agenda "%s" -> HTTP %s\n' "$MOTIVO" "$(curl -s -o /dev/null -b "$JAR_N" -w '%{http_code}' \
  -X POST "$WEB/api/citas" -H "$H" -d "{\"scheduledAt\":\"${FUTURA}\",\"reason\":\"${MOTIVO}\"}")"
printf '  control: N con sesion entra en /inicio -> HTTP %s\n' "$(pedir inicio_n /inicio "$JAR_N")"

# El hash de N, a una variable. No se imprime.
HASH_N=$(admin -t -A -c "SELECT password_hash FROM users WHERE id = '${UID_N}';")
echo "  hash de N leido para buscarlo despues: $([ -n "$HASH_N" ] && echo "si (${#HASH_N} caracteres, no se muestra)" || echo NO)"

# ===============================================================
echo ""
echo "==============================================================="
echo " 1. ANONIMO -> /admin, frente a una ruta inventada (criterio 3)"
echo "---------------------------------------------------------------"
echo " Esperado, segun la medicion del 19 de octubre: el CODIGO coincide"
echo "   (404 en las dos). El cuerpo y las cabeceras NO coinciden: /admin"
echo "   sale como un esqueleto __next_error__ generado al vuelo cuya carga"
echo "   util nombra el segmento \"admin\"; la inventada es la pagina 404"
echo "   prerenderizada (x-nextjs-cache: HIT, ETag, Content-Length)."
echo "   Es la limitacion 10. Ningun dato de la vista en la respuesta."
echo "==============================================================="
echo ""
pedir anon_admin /admin > /dev/null
pedir anon_inv "$INVENTADA" > /dev/null
comparar anon_admin anon_inv
echo "  Datos de la vista en la respuesta de /admin:"
echo "    correo de N: $(cuenta "$CORREO_N" "$TMP/anon_admin.b")   motivo de control: $(cuenta "$MOTIVO" "$TMP/anon_admin.b")   \"Todas las citas\": $(cuenta 'Todas las citas' "$TMP/anon_admin.b")"

# ===============================================================
echo ""
echo "==============================================================="
echo " 2. USUARIO NORMAL CON SESION -> /admin, frente a la inventada"
echo "---------------------------------------------------------------"
echo " Esperado: lo mismo que el anonimo, con la misma cookie en las"
echo "   dos peticiones: codigo 404 en las dos; cuerpo y cabeceras"
echo "   distintos por los mismos motivos."
echo "   N en /admin frente al anonimo en /admin, segun la medicion del"
echo "   19 de octubre: cabeceras identicas; cuerpo NO identico byte a"
echo "   byte, pero con el mismo contenido en otro orden (mismo tamaño,"
echo "   mismo HTML, mismos trozos RSC). Con sesion, getSession() consulta"
echo "   la base antes de llegar a notFound(), y el trozo del error sale"
echo "   en otro punto del flujo. Con un token INVENTADO, getSession()"
echo "   tambien consulta la base, asi que se espera el mismo orden que"
echo "   con una cookie valida: /admin no distinguiria cookie valida de"
echo "   invalida, solo cookie enviada de no enviada. /api/auth/me si las"
echo "   distingue (200 y 401), por diseño desde CITA-9."
echo "==============================================================="
echo ""
pedir n_admin /admin "$JAR_N" > /dev/null
pedir n_inv "$INVENTADA" "$JAR_N" > /dev/null
comparar n_admin n_inv
echo "  N en /admin frente al anonimo en /admin:"
if cmp -s "$TMP/n_admin.b" "$TMP/anon_admin.b"; then
  echo "    cuerpo: IDENTICO byte a byte"
else
  echo "    cuerpo: DISTINTO ($(cmp "$TMP/n_admin.b" "$TMP/anon_admin.b" | sed 's/.*differ: //'))"
  reordenado n_admin anon_admin
fi
cmp -s "$TMP/n_admin.hs" "$TMP/anon_admin.hs" && echo "    cabeceras: IDENTICAS (sin Date)" || {
  echo "    cabeceras: DISTINTAS (sin Date):"; diff "$TMP/n_admin.hs" "$TMP/anon_admin.hs" | grep '^[<>]' | sed 's/^/      /'; }
echo "  Repetida la peticion de N: cuerpo $(pedir n_admin2 /admin "$JAR_N" > /dev/null; cmp -s "$TMP/n_admin.b" "$TMP/n_admin2.b" && echo IDENTICO a la primera || echo DISTINTO de la primera)"
echo "  Repetida la del anonimo:   cuerpo $(pedir anon_admin2 /admin > /dev/null; cmp -s "$TMP/anon_admin.b" "$TMP/anon_admin2.b" && echo IDENTICO a la primera || echo DISTINTO de la primera)"
echo "  Control del oraculo de CITA-9: /api/auth/me sin cookie -> HTTP $(curl -s -o /dev/null -w '%{http_code}' "$WEB/api/auth/me"), con la cookie de N -> HTTP $(curl -s -o /dev/null -b "$JAR_N" -w '%{http_code}' "$WEB/api/auth/me")"
# Un token inventado del mismo formato que uno real (32 bytes en
# base64url, 43 caracteres). getSession() tambien consulta la base con
# el, no encuentra la fila y devuelve null.
TOKEN_FALSO=$(node -e 'console.log(require("crypto").randomBytes(32).toString("base64url"))')
pedir falso_admin /admin "citasegura_session=${TOKEN_FALSO}" > /dev/null
echo "  Cookie con un token inventado (${#TOKEN_FALSO} caracteres) -> /admin HTTP $(head -1 "$TMP/falso_admin.h" | cut -d' ' -f2):"
echo "    cuerpo frente al de N (cookie valida): $(cmp -s "$TMP/falso_admin.b" "$TMP/n_admin.b" && echo IDENTICO byte a byte || echo DISTINTO)"
echo "    cuerpo frente al anonimo (sin cookie):  $(cmp -s "$TMP/falso_admin.b" "$TMP/anon_admin.b" && echo IDENTICO byte a byte || echo DISTINTO)"
echo "    /api/auth/me con ese token -> HTTP $(curl -s -o /dev/null -b "citasegura_session=${TOKEN_FALSO}" -w '%{http_code}' "$WEB/api/auth/me")"
echo "  Datos de la vista en la respuesta de N a /admin:"
echo "    correo de A: $(cuenta "$CORREO_A" "$TMP/n_admin.b")   motivo de control: $(cuenta "$MOTIVO" "$TMP/n_admin.b")   \"Usuarios registrados\": $(cuenta 'Usuarios registrados' "$TMP/n_admin.b")"

# ===============================================================
echo ""
echo "==============================================================="
echo " 3. ADMINISTRADOR -> /admin (criterios 1 y 2)"
echo "---------------------------------------------------------------"
echo " Esperado: HTTP 200, y en el HTML las dos pestanas con contenido:"
echo "   \"Todas las citas\" con el motivo de control de N, y \"Usuarios"
echo "   registrados\" con los correos de N y de A."
echo "==============================================================="
echo ""
echo "  GET /admin con la sesion de A -> HTTP $(pedir a_admin /admin "$JAR_A")   $(wc -c < "$TMP/a_admin.b") bytes"
echo "  Pestana Citas:"
echo "    \"Todas las citas\":     $(cuenta 'Todas las citas' "$TMP/a_admin.b")"
echo "    motivo de control:     $(cuenta "$MOTIVO" "$TMP/a_admin.b")"
echo "  Pestana Usuarios:"
echo "    \"Usuarios registrados\": $(cuenta 'Usuarios registrados' "$TMP/a_admin.b")"
echo "    correo de N:           $(cuenta "$CORREO_N" "$TMP/a_admin.b")"
echo "    correo de A:           $(cuenta "$CORREO_A" "$TMP/a_admin.b")"
echo "  (cada dato aparece dos veces si esta en el HTML visible y tambien"
echo "   en la carga util con la que React hidrata la pagina)"

# ===============================================================
echo ""
echo "==============================================================="
echo " 4. LO QUE NO DEBE SALIR DE LA BASE (criterio 2)"
echo "---------------------------------------------------------------"
echo " Esperado: 0 en todo, en el HTML que recibe el administrador."
echo "==============================================================="
echo ""
echo "  prefijo bcrypt \$2b\$:              $(cuenta '$2b$' "$TMP/a_admin.b")"
echo "  hash completo de N:                $(cuenta "$HASH_N" "$TMP/a_admin.b")"
echo "  nombre de campo password_hash:     $(cuenta 'password_hash' "$TMP/a_admin.b")"
echo "  nombre de campo failed_attempts:   $(cuenta 'failed_attempts' "$TMP/a_admin.b")"
echo "  nombre de campo locked_until:      $(cuenta 'locked_until' "$TMP/a_admin.b")"
echo "  id de N (las cuentas no llevan id): $(cuenta "$UID_N" "$TMP/a_admin.b")"
echo ""
# Lineas de comentario: las que, tras "archivo:linea:", empiezan por //,
# /* o *. Se descartan porque los comentarios de la vista NOMBRAN lo que
# no se hace ("Nada de SELECT *") y contarlos daria un falso positivo.
# Se imprime cuantas se descartan, para que se vea que el filtro actua.
COMENTARIO='^[^:]+:[0-9]+:[[:space:]]*(//|/\*|\*)'
VISTA=(src/app/admin src/lib/auth/administrador.ts)
echo "  En el codigo de la vista (${VISTA[*]}), fuera de comentarios:"
echo "    SELECT *:                                       $(grep -rniE 'select[[:space:]]+\*' "${VISTA[@]}" | grep -vE "$COMENTARIO" | wc -l)   (en comentarios, descartadas: $(grep -rniE 'select[[:space:]]+\*' "${VISTA[@]}" | grep -cE "$COMENTARIO"))"
echo "    password_hash, failed_attempts o locked_until:  $(grep -rnE 'password_hash|failed_attempts|locked_until' "${VISTA[@]}" | grep -vE "$COMENTARIO" | wc -l)   (en comentarios, descartadas: $(grep -rnE 'password_hash|failed_attempts|locked_until' "${VISTA[@]}" | grep -cE "$COMENTARIO"))"

# ===============================================================
echo ""
echo "==============================================================="
echo " 5. EL ADMINISTRADOR SOLO CONSULTA (criterio 5)"
echo "---------------------------------------------------------------"
echo " Esperado: 0 rutas de administrador bajo /api; 0 escrituras SQL y"
echo "   0 fetch en el codigo de la vista; POST a /api/admin, 404."
echo "==============================================================="
echo ""
echo "  Rutas bajo src/app/api y sus metodos:"
find src/app/api -name 'route.ts' | sort | while read -r f; do
  printf '    %-42s %s\n' "${f#src/app}" "$(grep -oE 'export async function (GET|POST|PUT|PATCH|DELETE)' "$f" | awk '{print $4}' | tr '\n' ' ')"
done
echo "  Rutas de administrador bajo /api (ruta con \"admin\"):   $(find src/app/api -path '*admin*' | wc -l)"
echo "  Rutas bajo /api que llaman a exigirAdministrador():  $(grep -rl 'exigirAdministrador' src/app/api | wc -l)"
echo "  INSERT/UPDATE/DELETE en el codigo de la vista:         $(grep -rniE '\b(insert|update|delete)\b[[:space:]]+(into|from|[a-z_]+[[:space:]]+set)' src/app/admin src/lib/auth/administrador.ts | wc -l)"
echo "  fetch( en el codigo de la vista:                       $(grep -rn 'fetch(' src/app/admin | wc -l)"
echo "  Llamadas a exigirAdministrador() en todo src/:         $(grep -rn 'exigirAdministrador()' src --include=*.ts --include=*.tsx | grep -v '^\S*:[0-9]*:\s*\(//\|\*\)' | grep -v 'export async function' | wc -l)  ($(grep -rln 'exigirAdministrador()' src --include=*.ts --include=*.tsx | grep -v administrador.ts | tr '\n' ' '))"
printf '  POST /api/admin con la sesion de A -> HTTP %s\n' "$(curl -s -o /dev/null -b "$JAR_A" -w '%{http_code}' -X POST "$WEB/api/admin" -H "$H" -d '{}')"

# ===============================================================
echo ""
echo "==============================================================="
echo " 6. EL ROL SE LEE EN CADA PETICION (criterio 4)"
echo "---------------------------------------------------------------"
echo " Esperado: se le retira el rol a A como postgres, SIN cerrar su"
echo "   sesion; su siguiente GET /admin con la misma cookie da 404,"
echo "   identico byte a byte al de N (otra sesion valida sin rol), sin"
echo "   datos de la vista."
echo "==============================================================="
echo ""
admin -c "UPDATE users SET role = 'user'
           WHERE id = '${UID_A}' AND email = '${CORREO_A}'
          RETURNING email, role;" | sed 's/^/    /'
echo "  sesiones de A en la base: $(admin -t -A -c "SELECT count(*) FROM sessions WHERE user_id = '${UID_A}';")"
echo "  GET /admin con la misma cookie de A -> HTTP $(pedir a2_admin /admin "$JAR_A")"
cmp -s "$TMP/a2_admin.b" "$TMP/n_admin.b" && echo "  cuerpo frente al de N: IDENTICO byte a byte" \
  || echo "  cuerpo frente al de N: DISTINTO ($(cmp "$TMP/a2_admin.b" "$TMP/n_admin.b" | sed 's/.*differ: //'))"
echo "  motivo de control: $(cuenta "$MOTIVO" "$TMP/a2_admin.b")   correo de N: $(cuenta "$CORREO_N" "$TMP/a2_admin.b")"

# --------------------------------------------------------------
trap - INT TERM EXIT
limpieza

echo ""
echo "==============================================================="
echo " Resumen de lo esperado:"
echo "   0 -> build 0, /admin dinamica, 0 proxy; registros 201; A admin;"
echo "        app_insert_role f, app_update_role f; logins 200; cita 201;"
echo "        /inicio 200"
echo "   1 -> 404 y 404; cuerpo y cabeceras DISTINTOS (limitacion 10);"
echo "        el cuerpo de /admin nombra el segmento admin; datos 0"
echo "   2 -> igual que 1; N frente al anonimo: cabeceras identicas, cuerpo"
echo "        reordenado (tamaño, HTML y trozos RSC iguales); cada uno"
echo "        identico a si mismo al repetirlo; /api/auth/me 401 y 200;"
echo "        token inventado: identico al de N, distinto del anonimo,"
echo "        /api/auth/me 401; datos 0"
echo "   3 -> 200; las dos pestanas con su linea de control"
echo "   4 -> todo 0"
echo "   5 -> 0 rutas de admin en /api, 0 escrituras, 0 fetch; una sola"
echo "        llamada a exigirAdministrador(), desde datos.ts; POST 404"
echo "   6 -> rol retirado, sesion viva (1), 404 identico al de N, datos 0"
echo "   Limpieza -> cuentas, citas y sesiones 0; servidor parado"
echo "==============================================================="
