# Guiones de evidencia

`db/` guarda el esquema de la base y también las evidencias de toda la fase,
incluidas las que no tocan la base, como la configuración del entorno
(CITA-15) o el esquema de registro sin servidor (`evidencia-cita7-esquema.mts`).
No se mueven porque sus rutas están en salidas capturadas y en commits ya
subidos, y CITA-16 vuelve a ejecutarlos.

Cada guion ejecuta contra la aplicación y la base reales las pruebas de una
tarjeta. Lo que queda de esa ejecución no es igual en los dos sprints:

- **Sprint 2 (CITA-18, 12, 13, 14 y 15).** Cada guion tiene su salida
  guardada en esta carpeta, y los bloques de `db/EVIDENCIAS-FASE2.md` citan
  literalmente fragmentos de ese archivo. Se pueden cotejar.
- **Sprint 1 (CITA-7 a CITA-10).** Se ejecutaron en el equipo anterior y no
  tienen salida guardada: sus resultados están transcritos en los bloques 2
  a 4, sin un archivo con el que cotejarlos. La salvedad es
  `evidencia-cita7-esquema.mts`, que sí tiene salida guardada
  (`salida-cita7-esquema.txt`, generada el 16 de octubre en el equipo nuevo);
  ningún bloque la cita todavía.

| Guion | Tarjeta | Qué demuestra | Salida guardada | Evidencias |
|---|---|---|---|---|
| `evidencia-cita7.sh` | CITA-7 Endpoint de registro | Registro válido normalizado; rechazo de correo inválido, contraseña débil, *mass assignment* (`role`) y envío de formulario de otro sitio (415); el correo duplicado responde igual que uno nuevo (anti-enumeración) | — | Bloque 2 |
| `evidencia-cita7-esquema.mts` **(node, no bash)** | CITA-7 Endpoint de registro | El esquema `registerSchema` sin servidor, regla por regla: cada requisito de la contraseña por separado, el tope de 72 bytes de bcrypt, la normalización del correo, la clave sobrante `role` y un cuerpo que no es un objeto | `salida-cita7-esquema.txt` | Complementa el bloque 2 |
| `evidencia-cita8.sh` | CITA-8 bcrypt | La contraseña se guarda como hash `$2b$12$`; la base rechaza un texto plano por `CHECK`; dos hashes de la misma contraseña tienen sal distinta | — | Bloque 2 (2.2 y 2.3) |
| `evidencia-cita9.sh` | CITA-9 Login y sesiones | Flags de la cookie; token guardado como SHA-256; ruta protegida con cookie válida, ausente e inventada; el logout revoca en el servidor; anti-enumeración por tiempo | — | Bloque 3 |
| `evidencia-cita10.sh` | CITA-10 Bloqueo por intentos | Bloqueo al quinto fallo; la contraseña correcta no entra durante el bloqueo; insistir no lo alarga; vencido se entra y se reinicia; el bloqueo no delata la cuenta por tiempo | — | Bloque 4 |
| `evidencia-cita18.sh` | CITA-18 Esquema de citas | `CHECK` de estado, fecha y motivo; privilegios por columna; doce operaciones que la base rechaza aunque el código las intente, y las tres que permite | `salida-cita18.txt`, `salida-cita18-ddp.txt` | Bloque 5 |
| `evidencia-cita12.sh` | CITA-12 API de citas | Sesión exigida (401); listado filtrado por dueño; el mismo 404 para cita inexistente, ajena o con id mal formado; validación del cuerpo; los rechazos no dejan filas | `salida-cita12.txt` | Sin bloque propio (evidencia de CITA-12 pendiente); la citan los bloques 6 y 7 |
| `evidencia-cita13.sh` | CITA-13 Control de acceso y anti-IDOR | Ningún endpoint devuelve una cita por id; cancelar una cita ajena no la cambia (md5 de la fila); ajena e inexistente no se distinguen por tiempo; UUID v4; el hallazgo del `INSERT` sobre `users`, antes y después | `salida-cita13.txt`, `salida-cita13-antes.txt` | Bloque 6 |
| `evidencia-cita14.sh` | CITA-14 Validación y sanitización | La validación no depende del navegador y las claves sobrantes no sirven para sondear; fecha pasada frenada en dos capas; el texto se guarda literal y se escapa al mostrarse | `salida-cita14.txt` | Bloque 7 |
| `evidencia-cita15.sh` | CITA-15 Configuración de `.env` | Archivos de entorno fuera de git y del historial; `.env.example` con los mismos nombres que lee la aplicación; ningún secreto en el JavaScript ni en el HTML que llega al navegador; sin una variable obligatoria la aplicación no arranca | `salida-cita15.txt` | Bloque 8 |

Las filas del Sprint 1 van por número de tarjeta; las del Sprint 2, en el
orden de ejecución del sprint por dependencias, el mismo de `CLAUDE.md` y
`ESTADO-PROYECTO.md`: primero el esquema (CITA-18), luego la API que lo usa
(CITA-12) y después los controles sobre esa API.

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
  - `evidencia-cita18.sh` habla solo con la base.
  - `evidencia-cita15.sh` exige lo contrario: el servidor de desarrollo
    **parado**. Modifica `.env.local` (sobre copia, y lo restaura comprobando
    el hash) y arranca su propio `next start` en el puerto 3015.
- **`.env.local`** con `DATABASE_URL`: los guiones de CITA-13, 14 y 15 leen de
  ahí la cadena de `citasegura_app` y nunca la imprimen.
- **La contraseña de `postgres`** en `PGPASSWORD` (`DB_PASSWORD` en el equipo
  anterior). Los guiones del Sprint 2 la usan solo para leer lo que la API no
  muestra y para borrar sus cuentas de prueba al terminar.

Cada guion del Sprint 2 crea sus propias cuentas (`prueba.citaN.*@ejemplo.com`)
y las borra al final por id y correo exacto. No dependen de datos previos.

### Los guiones del Sprint 1 (CITA-7 a CITA-10) hoy

Se escribieron en el equipo anterior y no tienen salida guardada: sus
resultados están transcritos en los bloques 2 a 4.
(`evidencia-cita7-esquema.mts` sí la tiene: se trajo de la raíz el 16 de
octubre y se ejecutó al moverlo.) Evaluados el 16 de octubre, sin
ejecutarlos:

- **`evidencia-cita7.sh`** se puede ejecutar tal cual: solo usa la API. Deja
  una cuenta `evidencia.*@ejemplo.com` sin borrar.
- **`evidencia-cita8.sh` y `evidencia-cita9.sh`** fallarían en este equipo.
  Conectan con `psql -U citasegura_app` sin dar contraseña, y `PGPASSWORD`
  tiene ahora la de `postgres`. Tampoco borran sus cuentas.
  `evidencia-cita9.sh` imprime además el token de sesión en claro: queda
  revocado dentro del mismo guion, pero no conviene guardarlo en un archivo
  versionado.
- **`evidencia-cita10.sh`** se corta en la comprobación inicial: exige
  `DB_PASSWORD`, el nombre de la variable en el equipo anterior.
- Los cuatro hacen `clear` sin comprobar si la salida va a una terminal, así
  que con `tee` meterían códigos de control en el archivo. Los del Sprint 2
  usan `[ -t 1 ] && clear`.

Ninguno depende de un estado de la base que ya no exista: cada uno crea sus
propias cuentas.

## Los dos nombres con sufijo

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
