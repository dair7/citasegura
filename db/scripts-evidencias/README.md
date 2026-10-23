# Guiones de evidencia

`db/` guarda el esquema de la base y también las evidencias de toda la fase,
incluidas las que no tocan la base, como la configuración del entorno
(CITA-15) o el esquema de registro sin servidor (`evidencia-cita7-esquema.mts`).
No se mueven porque sus rutas están en salidas capturadas y en commits ya
subidos, y CITA-16 vuelve a ejecutarlos.

Cada guion ejecuta contra la aplicación y la base reales las pruebas de una
tarjeta. Lo que queda de esa ejecución no es igual en los dos sprints:

- **Sprints 2 y 3 (CITA-18, 12, 13, 14, 15, 19 y 16).** Cada guion tiene su salida
  guardada en esta carpeta, y los bloques de `db/EVIDENCIAS-FASE2.md` citan
  literalmente fragmentos de ese archivo. Se pueden cotejar.
- **Sprint 1 (CITA-7 a CITA-10).** Se ejecutaron en el equipo anterior sin
  guardar la salida: sus resultados están transcritos en los bloques 2 a 4,
  sin un archivo con el que cotejarlos. Desde el 22 de octubre, los cuatro
  tienen salida guardada (`salida-cita7.txt` a `salida-cita10.txt`),
  generada en el equipo nuevo después de arreglar los guiones (ver «Los
  guiones del Sprint 1 (CITA-7 a CITA-10) hoy»). Es una ejecución nueva, no
  la que transcriben los bloques 2 a 4, y ningún bloque la cita todavía. Lo
  mismo pasa con `salida-cita7-esquema.txt` (16 de octubre).

| Guion | Tarjeta | Qué demuestra | Salida guardada | Evidencias |
|---|---|---|---|---|
| `evidencia-cita7.sh` | CITA-7 Endpoint de registro | Registro válido normalizado; rechazo de correo inválido, contraseña débil, *mass assignment* (`role`) y envío de formulario de otro sitio (415); el correo duplicado responde igual que uno nuevo (anti-enumeración) | `salida-cita7.txt` | Bloque 2 |
| `evidencia-cita7-esquema.mts` **(node, no bash)** | CITA-7 Endpoint de registro | El esquema `registerSchema` sin servidor, regla por regla: cada requisito de la contraseña por separado, el tope de 72 bytes de bcrypt, la normalización del correo, la clave sobrante `role` y un cuerpo que no es un objeto | `salida-cita7-esquema.txt` | Complementa el bloque 2 |
| `evidencia-cita8.sh` | CITA-8 bcrypt | La contraseña se guarda como hash `$2b$12$`; la base rechaza un texto plano por `CHECK`; dos hashes de la misma contraseña tienen sal distinta | `salida-cita8.txt` | Bloque 2 (2.2 y 2.3) |
| `evidencia-cita9.sh` | CITA-9 Login y sesiones | Flags de la cookie; token guardado como SHA-256; ruta protegida con cookie válida, ausente e inventada; el logout revoca en el servidor; anti-enumeración por tiempo | `salida-cita9.txt` | Bloque 3 |
| `evidencia-cita10.sh` | CITA-10 Bloqueo por intentos | Bloqueo al quinto fallo; la contraseña correcta no entra durante el bloqueo; insistir no lo alarga; vencido se entra y se reinicia; el bloqueo no delata la cuenta por tiempo | `salida-cita10.txt` | Bloque 4 |
| `evidencia-cita18.sh` | CITA-18 Esquema de citas | `CHECK` de estado, fecha y motivo; privilegios por columna; doce operaciones que la base rechaza aunque el código las intente, y las tres que permite | `salida-cita18.txt`, `salida-cita18-ddp.txt`, `salida-cita18-reejecucion.txt` | Bloque 5 (la reejecución, todavía ninguno) |
| `evidencia-cita12.sh` | CITA-12 API de citas | Sesión exigida (401); listado filtrado por dueño; el mismo 404 para cita inexistente, ajena o con id mal formado; validación del cuerpo; los rechazos no dejan filas | `salida-cita12.txt` | Bloque 9; la citan también los bloques 6 y 7 |
| `evidencia-cita13.sh` | CITA-13 Control de acceso y anti-IDOR | Ningún endpoint devuelve una cita por id; cancelar una cita ajena no la cambia (md5 de la fila); ajena e inexistente no se distinguen por tiempo; UUID v4; el hallazgo del `INSERT` sobre `users`, antes y después | `salida-cita13.txt`, `salida-cita13-antes.txt` | Bloque 6 |
| `evidencia-cita14.sh` | CITA-14 Validación y sanitización | La validación no depende del navegador y las claves sobrantes no sirven para sondear; fecha pasada frenada en dos capas; el texto se guarda literal y se escapa al mostrarse | `salida-cita14.txt` | Bloque 7 |
| `evidencia-cita15.sh` | CITA-15 Configuración de `.env` | Archivos de entorno fuera de git y del historial; `.env.example` con los mismos nombres que lee la aplicación; ningún secreto en el JavaScript ni en el HTML que llega al navegador; sin una variable obligatoria la aplicación no arranca | `salida-cita15.txt` | Bloque 8 |
| `evidencia-cita19.sh` | CITA-19 Vista de administrador | El rol solo se asigna como `postgres`; el administrador ve las dos listas y en su HTML no hay hash ni campos de bloqueo; ninguna ruta de administrador escribe; sin rol, el mismo código 404 que una ruta inventada y ningún dato, pero cuerpo y cabeceras distintos; con cookie y sin ella, mismo contenido en otro orden; degradar una cuenta le quita el acceso en la petición siguiente | `salida-cita19.txt` | Bloque 10 |
| `evidencia-cita19-proxy.sh` | CITA-19 Vista de administrador | La alternativa descartada: un Proxy que reescribe `/admin` deja el cuerpo idéntico, pero Next.js añade siempre `x-middleware-rewrite`. Imprime el código de Next.js que la añade **buscándolo por su texto**, no por número de línea, y termina con código 1 si no lo encuentra (ver «Los guiones del Proxy, sin números de línea fijos») | `salida-cita19-proxy.txt` (16.3.6), `salida-cita19-proxy-reejecucion.txt` (16.4.2) | Bloque 10 (10.7); la reejecución, 11.14 y 11.15 |
| `evidencia-cita16-cabeceras.sh` **(con argumento `antes` o `despues`)** | CITA-16 Re-test: cabeceras de seguridad | Con `curl -I` en siete rutas, incluidas una 404 y una 401: antes del cambio, ninguna cabecera de seguridad y `X-Powered-By` en las páginas; después, sin `X-Powered-By` y con `nosniff`, `X-Frame-Options`, `Referrer-Policy`, `Permissions-Policy` y `Strict-Transport-Security` en todas; sin CSP. HSTS se envía pero no es verificable sobre HTTP | `salida-cita16-cabeceras-antes.txt`, `salida-cita16-cabeceras.txt` | Bloque 11 |
| `evidencia-cita16-proxy.sh` | CITA-16 Re-test: cabeceras de seguridad | Un intento de quitar `x-nextjs-cache`, `x-nextjs-prerender`, `x-nextjs-stale-time` y el `Vary` con `next-router-*` con un Proxy: no desaparece ninguna. Imprime las líneas de Next.js que las añaden **buscándolas por su texto**, no por número de línea, y termina con código 1 si alguna no aparece o aparece más de una vez (ver «Los guiones del Proxy, sin números de línea fijos») | `salida-cita16-proxy.txt` (16.3.6), `salida-cita16-proxy-reejecucion.txt` (16.4.2) | Bloque 11 (11.7); la reejecución, 11.13 y 11.15 |

Las filas del Sprint 1 van por número de tarjeta; las del Sprint 2, en el
orden de ejecución del sprint por dependencias, el mismo de `CLAUDE.md` y
`ESTADO-PROYECTO.md`: primero el esquema (CITA-18), luego la API que lo usa
(CITA-12) y después los controles sobre esa API. Las del Sprint 3 van
después, en el orden en que se ejecutaron: CITA-19 y luego CITA-16.

## Cómo se ejecutan

Desde Git Bash, en la raíz del proyecto, guardando la salida desde la primera
ejecución:

```bash
bash db/scripts-evidencias/evidencia-cita14.sh | tee db/scripts-evidencias/salida-cita14.txt
```

**La excepción es `evidencia-cita7-esquema.mts`: es TypeScript y se ejecuta
con `node`, no con `bash`.** Pasado a `bash`, falla en la primera línea. Necesita
node 22.6 o posterior, que ejecuta TypeScript sin compilarlo, y no necesita ni
la aplicación ni la base:

```bash
node db/scripts-evidencias/evidencia-cita7-esquema.mts | tee db/scripts-evidencias/salida-cita7-esquema.txt
```

**`evidencia-cita16-cabeceras.sh` necesita un argumento**, `antes` o
`despues`. Solo cambia el «Esperado» que se declara y la etiqueta de la
cabecera; la medida es la misma, para que las dos salidas se comparen línea
a línea. Sin argumento, imprime cómo se usa y sale sin medir:

```bash
bash db/scripts-evidencias/evidencia-cita16-cabeceras.sh despues | tee db/scripts-evidencias/salida-cita16-cabeceras.txt
```

Node avisa por la salida de errores de que `package.json` no declara
`"type": "module"`. Es solo un aviso de rendimiento y no llega al archivo de
salida, que solo recoge la salida estándar.

Lo que hace falta tener levantado:

- **PostgreSQL 18** con el servicio `postgresql-x64-18` en marcha y la base
  montada (ver «Montar la base desde cero» en `ESTADO-PROYECTO.md`). `psql` no
  está en el PATH: los guiones lo llaman por su ruta completa.
- **La aplicación en `localhost:3001`** (`pnpm dev --webpack --port 3001`),
  para todos salvo tres:
  - `evidencia-cita7-esquema.mts` no necesita ni la aplicación ni la base.
  - `evidencia-cita18.sh` habla solo con la base (usa `node` solo para
    calcular el hash bcrypt de su cuenta de prueba).
  - `evidencia-cita15.sh` exige lo contrario: el servidor de desarrollo
    **parado**. Modifica `.env.local` (sobre copia, y lo restaura comprobando
    el hash) y arranca su propio `next start` en el puerto 3015.
  - Los dos de CITA-19 también lo exigen **parado**: hacen su propio build de
    producción, que escribe en `.next`, y arrancan `next start` en el puerto
    3019. Comparan respuestas byte a byte, y eso solo vale en producción.
    `evidencia-cita19-proxy.sh` crea además un `src/proxy.ts` temporal y lo
    borra al terminar (se niega a empezar si ya existe uno); el `.next` que
    deja incluye ese Proxy hasta el siguiente build.
  - Los dos de CITA-16, igual: servidor de desarrollo **parado**, build de
    producción propio y `next start` en el puerto 3016. Las cabeceras se
    miden en producción porque en desarrollo Next.js añade a las respuestas
    cosas que en producción no están. `evidencia-cita16-proxy.sh` crea y
    borra un `src/proxy.ts` temporal, como el de CITA-19, y su `.next`
    también se queda con ese Proxy: **hay que volver a construir antes de
    cualquier `next start`**.
- **`.env.local`** con `DATABASE_URL`: los guiones de CITA-8, 9, 10, 13, 14,
  15 y 18 leen de ahí la cadena de `citasegura_app` y nunca la imprimen.
  Ninguno pide ya una contraseña por teclado.
- **La contraseña de `postgres`** en `PGPASSWORD` (`DB_PASSWORD` en el equipo
  anterior; los guiones aceptan las dos y prefieren `DB_PASSWORD`). La usan
  solo para leer lo que la API no muestra, para capturar el id de sus cuentas
  de prueba y para borrarlas al terminar.

Cada guion crea sus propias cuentas (`prueba.citaN.*@ejemplo.com` en los
Sprints 2 y 3; `evidencia.*@ejemplo.com` en el Sprint 1) y las borra al final
por id capturado y correo exacto, nunca por un patrón. No dependen de datos
previos.

### Los guiones del Sprint 1 (CITA-7 a CITA-10) hoy

Se escribieron en el equipo anterior, que guardaba las credenciales de otra
forma. El 16 de octubre se evaluaron sin ejecutarlos, y el 22 de octubre se
ejecutaron uno a uno en el equipo nuevo, tal cual, con la salida fuera de
esta carpeta:

| Guion | ¿Arrancaba? | Dónde y por qué fallaba |
|---|---|---|
| `evidencia-cita7.sh` | Sí, entero | — (pero dejaba su cuenta en la base) |
| `evidencia-cita7-esquema.mts` | Sí | — (salida idéntica a la guardada salvo fecha y commit) |
| `evidencia-cita8.sh` | A medias | Pasos 2, 3 y 4: conecta con `psql -U citasegura_app` sin contraseña propia y `PGPASSWORD` tiene la de `postgres`: `FATAL: la autentificación password falló para el usuario «citasegura_app»` |
| `evidencia-cita9.sh` | A medias | Pasos 2 y 4c, por la misma causa |
| `evidencia-cita10.sh` | No | Comprobación inicial: `Falta la variable de entorno DB_PASSWORD`, el nombre de la variable en el equipo anterior |

Lo que se arregló el 22 de octubre, **sin cambiar lo que prueban**: las
consultas, las peticiones y el «Esperado» de cada prueba son los mismos (solo
se añadió una línea para la limpieza). Solo cambió cómo se autentican, cómo
informan de un fallo y cómo limpian.

- **Autenticación (CITA-8, 9 y 10).** Adoptan el mecanismo de los guiones del
  Sprint 2: la cadena de `citasegura_app` se lee de la `DATABASE_URL` de
  `.env.local`, y la contraseña de `postgres` de `DB_PASSWORD` o, si no
  existe, de `PGPASSWORD`. Ya no piden nada por teclado.
- **Un fallo ya no pasa por evidencia válida (CITA-8 y 9).** Era el defecto
  más grave: el error de `psql` iba solo a la salida de errores, que `tee`
  no guarda, y el guion terminaba con código 0. El archivo guardado quedaba
  con las secciones vacías y sin rastro del fallo: parecía una evidencia y no
  lo era. Ahora cada llamada a `psql` pasa por una función `comprobar` que
  une la salida de errores a la normal, compara el código de salida con el
  esperado (1 donde el rechazo **es** el resultado, como el texto plano de
  CITA-8) y, si no coincide, escribe `FALLO DEL GUION` en la propia salida.
  Al final, `RESULTADO DEL GUION` dice si todas las medidas se hicieron, y el
  guion termina con código 1 si alguna falló. Se comprobó forzando un fallo de
  autenticación: el error y el aviso quedaron en el archivo y el código fue 1.
- **Limpieza acotada.** CITA-10 borraba con `LIKE 'evidencia.%@ejemplo.com'`,
  que se llevaba cualquier cuenta con ese prefijo, incluidas las de otros
  guiones. CITA-7, 8 y 9 no borraban nada. Los cuatro capturan ahora el id
  de sus cuentas (solo se acepta si tiene forma de UUID, para que un mensaje
  de error no pase por un id) y las borran por id y correo exacto, como el
  Sprint 2. Si no se puede capturar el id, el guion avisa de qué cuenta quedó
  en la base: CITA-8, 9 y 10 abortan; CITA-7 sigue con las demás pruebas, que
  no dependen de esa cuenta, y termina con código 1. En CITA-7 la limpieza va
  al final, después de la prueba 6, que necesita la cuenta para registrar el
  mismo correo por segunda vez.
- **El token de sesión no llega a la salida (CITA-9 y 10).** CITA-9 imprimía
  el token en claro, y CITA-10 también: cortaba el `Set-Cookie` a 90
  caracteres, y el token entero cabe en ese corte. Se tapa con el mismo
  filtro `<OCULTO>` de los guiones de CITA-16, pero solo si el valor no está
  vacío: la cookie del logout llega vacía, y eso es parte de lo que se
  prueba. Las cookies de CITA-9 se escriben ahora en un directorio temporal,
  no en la raíz del proyecto.
- **`clear` (CITA-7, 8, 9 y 10).** Solo se ejecuta si la salida es una terminal
  (`[ -t 1 ] && clear`), como en los guiones del Sprint 2. Con `tee` metía
  códigos de control al principio del archivo.

Con eso se ejecutaron otra vez el 22 de octubre: las pruebas dan lo esperado,
la limpieza deja la base como estaba y la salida está en `salida-cita7.txt`,
`salida-cita8.txt`, `salida-cita9.txt` y `salida-cita10.txt`. Se revisó que
ninguno de los cuatro archivos contiene la contraseña de `citasegura_app`, la
de `postgres`, la cadena de conexión ni un token de sesión. Sí contienen, a
propósito, la contraseña de prueba `ClaveEvidencia1!` (CITA-8), la
contraseña en texto plano que la base rechaza en CITA-8, hashes bcrypt de
cuentas ya borradas y el SHA-256 de una sesión revocada (CITA-9). Estas
salidas no llevan el commit en la cabecera, solo la fecha.

### `evidencia-cita18.sh`, arreglado con el mismo criterio

Es del Sprint 2, pero tenía los mismos defectos que los del Sprint 1. Pedía
la contraseña de `citasegura_app` por teclado, y su limpieza exigía
`DB_PASSWORD`: en este equipo se la saltaba. Además:

- **Colgaba sus pruebas de una cuenta real**, la primera de `users`
  (`SELECT id FROM users LIMIT 1`). La prueba 5.3 cancela las citas
  `programada` de esa cuenta, así que ejecutarlo cancelaba citas reales. Ahora
  crea su propia cuenta `prueba.cita18.*@ejemplo.com` como `citasegura_app`,
  con un hash bcrypt real de coste 12 de una contraseña aleatoria que no se
  guarda en ningún sitio, y captura su id con `RETURNING`. El texto SQL de
  las pruebas no cambió; solo la cuenta de la que cuelgan.
- **Limpiaba por motivo**, con `reason IN ('Consulta de control', 'Control
  general')`, el mismo defecto que el `LIKE` de CITA-10: se habría llevado
  cualquier cita real con ese motivo. Ahora borra como `postgres` las citas
  de su cuenta y la cuenta, por id capturado y correo exacto.
- La autenticación, el aviso de fallo y el `clear`, como los otros tres. Aquí
  casi todas las pruebas esperan un rechazo (código 1 en la sección 4), así
  que una prueba que no diera error también saldría como `FALLO DEL GUION`.

La salida del 8 de octubre (`salida-cita18.txt`) muestra que esa limpieza
**falló**: `psql` no pudo autenticarse como `postgres`, y la cita de prueba
siguió en la base, colgada de `test@gmail.com`, hasta que se borró a mano el
13 de octubre (bloque 5, «Limpieza de las citas de evidencia»). La ejecución del 22 de octubre está en
`salida-cita18-reejecucion.txt` (ver «Los nombres con sufijo»). Se comprobó
que deja intactas las citas reales: el md5 de la tabla es el mismo antes y
después.

### Los guiones del Proxy, sin números de línea fijos (23 de octubre)

`evidencia-cita16-proxy.sh` (bloque 4) y `evidencia-cita19-proxy.sh` (bloque
3) imprimen dónde añade Next.js las cabeceras que miden. Lo hacían con
números de línea escritos a mano, los de Next.js 16.3.6. Al actualizar a
16.4.2 seguían terminando con código 0, pero imprimían otras líneas: el mismo
defecto que el de los guiones del Sprint 1, una salida que parece correcta y
no lo es.

Ahora cada uno busca en `node_modules/next/dist/` la línea por su texto
(`grep -n -F`, texto literal), el mismo que la identificaba, e imprime el
archivo, el número de línea encontrado y la línea entera. Si el texto no
aparece, o aparece más de una vez, no imprime ninguna línea de código:
escribe `FALLO DEL GUION` con el número de apariciones y el texto buscado.
Al final, `RESULTADO DEL GUION` dice si todas las medidas se hicieron, y el
guion termina con código 1 si alguna falló, como con la función `comprobar`
de los demás. El de CITA-19 busca los dos extremos de su bloque de cuatro
líneas (la condición y la asignación de `x-middleware-rewrite`), y también
falla si no forman un bloque corto en ese orden. Lo que prueban no cambió, y
los dos imprimen la versión de Next.js en la cabecera, porque los números
dependen de ella.

Se comprobó que fallan de verdad con copias temporales de los dos guiones,
con un texto inventado y, en el de CITA-16, otro que aparece ocho veces: las
dos copias terminaron con código 1 y lo dijeron en su salida (evidencia
11.15).

## Los nombres con sufijo

Se dejan con su nombre porque así los citan las evidencias. El sufijo dice
qué capturan:

- **`salida-cita13-antes.txt`**: la salida del hallazgo de CITA-13
  **antes** de corregirlo. `citasegura_app` todavía tenía `INSERT` sobre todas
  las columnas de `users` y el ataque de crear una cuenta `admin` por SQL
  funcionaba. Se capturó a propósito antes de cambiar `db/roles.sql`, para que
  el hallazgo quede demostrado con una salida real y no solo descrito.
  `salida-cita13.txt` es la ejecución completa después del arreglo.
- **`salida-cita18-ddp.txt`**: la salida de `\ddp` de psql, los
  **privilegios por defecto** del esquema `public`, capturada aparte el 13 de
  octubre como `postgres`. No la produce `evidencia-cita18.sh`: completó la
  evidencia 5.3, que el 8 de octubre se había quedado sin salida registrada.
  Es una foto de ese momento: CITA-13 redujo después esos privilegios a solo
  `SELECT` (evidencia 6.7).
- **`salida-cita18-reejecucion.txt`**: la ejecución del 22 de octubre de
  `evidencia-cita18.sh`, ya arreglado. **No sustituye a `salida-cita18.txt`**,
  que el bloque 5 cita literalmente y está capturada en Notion. Comparadas
  después de normalizar fechas, horas e identificadores, las 17 medidas dan lo
  mismo. Las diferencias son tres: los textos propios de psql salen en inglés
  (`Table`, `(17 rows)`, `DETAIL`) porque este equipo tiene
  `LANG=en_US.UTF-8`, como en las salidas desde CITA-14; la limpieza ahora
  funciona; y la cabecera ya no lleva el aviso de la contraseña ni los
  códigos de `clear`.
- **`salida-cita19-proxy.txt`**: la medida de la alternativa que se descartó
  para la limitación 10, un Proxy que reescribe `/admin`. La produce su
  propio guion, `evidencia-cita19-proxy.sh`, porque modifica el árbol de
  trabajo y no debe mezclarse con la ejecución principal de CITA-19.
- **`salida-cita16-cabeceras-antes.txt`**: las cabeceras **antes** de
  cambiar `next.config.ts`, capturadas a propósito antes del cambio, como
  `salida-cita13-antes.txt`. No se repite: es el estado de partida.
  `salida-cita16-cabeceras.txt` es la misma medida después del cambio.
- **`salida-cita16-proxy.txt`**: el intento de quitar las cabeceras
  `x-nextjs-*` con un Proxy. Va en su propio guion por la misma razón que el
  Proxy de CITA-19: modifica el árbol de trabajo.
