import { createHash, randomBytes } from "node:crypto";

import { cookies } from "next/headers";

import { query } from "@/lib/db";

/**
 * CitaSegura - Sesiones propias con cookie httpOnly (CITA-9).
 *
 * Se implementa a mano, sin Auth.js/NextAuth, para tener el control
 * completo del mecanismo y poder defenderlo.
 *
 * MODELO: sesion opaca del lado del servidor. La cookie no contiene
 * datos ni firma nada: es solo un identificador aleatorio que no
 * significa nada por si mismo. Toda la informacion real (a quien
 * pertenece, cuando caduca) vive en la tabla sessions.
 *
 * Es la alternativa a un JWT autocontenido, y aqui es la mejor
 * opcion: un JWT es valido hasta que caduca porque el servidor no
 * guarda nada, asi que NO se puede revocar (un logout solo borra la
 * copia del cliente; el token sigue sirviendo si alguien lo copio).
 * Con una fila en la tabla, cerrar sesion es un DELETE y la sesion
 * muere de verdad. Para una app con bloqueo de cuentas (CITA-10) esa
 * capacidad de revocar es imprescindible.
 */

// --------------------------------------------------------------
//  Constantes
// --------------------------------------------------------------
/** Nombre de la cookie. Neutro: no revela ni la tecnologia ni el rol. */
export const SESSION_COOKIE_NAME = "citasegura_session";

/**
 * Duracion de la sesion: 8 horas.
 *
 * Es un equilibrio: muy corta obliga a reautenticarse a media
 * jornada; muy larga alarga la ventana en la que un token robado
 * sigue sirviendo. 8 horas cubren una jornada de trabajo.
 */
export const SESSION_DURATION_SECONDS = 60 * 60 * 8;

/**
 * 32 bytes = 256 bits de entropia.
 *
 * Con 256 bits, adivinar un token por fuerza bruta no es un problema
 * de computacion sino de fisica: no hay tiempo ni energia suficientes.
 */
const SESSION_TOKEN_BYTES = 32;

// --------------------------------------------------------------
//  Token: generar y hashear
// --------------------------------------------------------------
/**
 * Genera el token de sesion que viaja en la cookie.
 *
 * randomBytes() es un generador CRIPTOGRAFICAMENTE SEGURO: pide
 * entropia al sistema operativo (BCryptGenRandom en Windows).
 *
 * NUNCA Math.random(): es un pseudoaleatorio rapido (xorshift128+ en
 * V8) cuyo estado interno se puede reconstruir observando unos pocos
 * valores. Con el estado se predicen los siguientes, y un token de
 * sesion predecible es una toma de cuenta completa: el atacante entra
 * como otro usuario sin contrasena, dejando inutil todo lo que hace
 * bcrypt en CITA-7.
 *
 * base64url y no hexadecimal: la misma entropia en menos caracteres
 * (43 frente a 64) y con un alfabeto seguro para cabeceras HTTP, sin
 * los caracteres + / = que habria que escapar.
 */
function generarTokenDeSesion(): string {
  return randomBytes(SESSION_TOKEN_BYTES).toString("base64url");
}

/**
 * Calcula el SHA-256 del token, que es lo UNICO que se guarda en la
 * base de datos. El token en claro solo existe en la cookie.
 *
 * Asi, quien consiga leer la tabla sessions no obtiene sesiones
 * utilizables: para pasar la validacion haria falta el token original,
 * y SHA-256 no se invierte.
 *
 * Se usa SHA-256 y no bcrypt a proposito: el hash tiene que ser
 * DETERMINISTA para poder buscar la fila por su clave primaria
 * (bcrypt, con su sal aleatoria, obligaria a recorrer la tabla entera
 * comparando una por una). Y la lentitud de bcrypt aqui no aportaria
 * nada: sirve para encarecer el adivinar contrasenas debiles, no
 * tokens de 256 bits aleatorios.
 */
function hashDelToken(token: string): string {
  return createHash("sha256").update(token).digest("hex");
}

// --------------------------------------------------------------
//  Tipos
// --------------------------------------------------------------
/** Sesion valida, con los datos del usuario ya resueltos. */
export type SesionActiva = {
  sessionId: string;
  expiresAt: Date;
  user: {
    id: string;
    name: string;
    email: string;
    role: string;
  };
};

type FilaSesion = {
  session_id: string;
  expires_at: Date;
  user_id: string;
  name: string;
  email: string;
  role: string;
};

// --------------------------------------------------------------
//  createSession() - tras un inicio de sesion correcto
// --------------------------------------------------------------
/**
 * Crea una sesion nueva y deja la cookie en la respuesta.
 *
 * Se genera SIEMPRE un token nuevo, sin reutilizar ninguno anterior.
 * Eso evita la FIJACION DE SESION (session fixation): el ataque en el
 * que el agresor consigue que la victima use un identificador que el
 * ya conoce (por ejemplo plantandole una cookie antes de que entre) y
 * que, tras el login, ese mismo identificador queda autenticado.
 *
 * Solo puede llamarse desde un Route Handler o una Server Function:
 * HTTP no permite enviar cabeceras Set-Cookie una vez que empezo a
 * transmitirse la respuesta.
 */
export async function createSession(userId: string): Promise<void> {
  const token = generarTokenDeSesion();
  const expiresAt = new Date(Date.now() + SESSION_DURATION_SECONDS * 1000);

  // Consulta parametrizada: el hash y el id viajan como datos, jamas
  // concatenados en el texto SQL.
  await query(
    `INSERT INTO sessions (id, user_id, expires_at)
     VALUES ($1, $2, $3)`,
    [hashDelToken(token), userId, expiresAt],
  );

  const cookieStore = await cookies();

  cookieStore.set(SESSION_COOKIE_NAME, token, {
    // El JavaScript de la pagina no puede leer esta cookie. Si
    // alguien logra inyectar un script (XSS), no podra exfiltrar el
    // token para reutilizarlo despues desde otra maquina.
    httpOnly: true,

    // La cookie solo viaja por HTTPS. En desarrollo se sirve por http
    // y Next escucha tambien en la IP de red, donde el navegador
    // descartaria una cookie Secure: por eso se activa solo en
    // produccion, que es donde de verdad importa.
    secure: process.env.NODE_ENV === "production",

    // El navegador NO envia esta cookie en peticiones POST originadas
    // en otro sitio web, lo que corta el CSRF clasico. Se elige 'lax'
    // y no 'strict' para que al llegar desde un enlace externo la
    // sesion siga activa y el usuario no parezca desconectado.
    sameSite: "lax",

    // Valida en toda la aplicacion.
    path: "/",

    // Caducidad en el cliente. Es solo una indicacion al navegador:
    // una herramienta como curl puede seguir enviando la cookie
    // despues. La caducidad que MANDA se comprueba en la base de
    // datos con expires_at > now().
    maxAge: SESSION_DURATION_SECONDS,
  });
}

// --------------------------------------------------------------
//  getSession() - validar la sesion de la peticion actual
// --------------------------------------------------------------
/**
 * Lee la cookie y devuelve la sesion si existe y no ha caducado.
 * Devuelve null en cualquier otro caso.
 *
 * ES DE SOLO LECTURA A PROPOSITO: no borra la cookie ni la fila
 * caducada. Asi puede llamarse tambien desde un Server Component,
 * donde escribir una cookie lanzaria un error. La limpieza de
 * sesiones caducadas es un barrido aparte (pendiente).
 *
 * La comprobacion de caducidad se hace en SQL contra now(), es decir
 * con el reloj del servidor de base de datos. Si se comparara en
 * JavaScript contra la fecha del cliente, bastaria cambiar la hora del
 * equipo para revivir una sesion caducada.
 */
export async function getSession(): Promise<SesionActiva | null> {
  const cookieStore = await cookies();
  const token = cookieStore.get(SESSION_COOKIE_NAME)?.value;

  if (!token) {
    return null;
  }

  // Se busca por el HASH del token recibido: en la tabla no hay
  // tokens en claro con los que comparar.
  const resultado = await query<FilaSesion>(
    `SELECT s.id         AS session_id,
            s.expires_at AS expires_at,
            u.id         AS user_id,
            u.name       AS name,
            u.email      AS email,
            u.role       AS role
       FROM sessions s
       JOIN users u ON u.id = s.user_id
      WHERE s.id = $1
        AND s.expires_at > now()`,
    [hashDelToken(token)],
  );

  const fila = resultado.rows[0];

  if (!fila) {
    return null;
  }

  return {
    sessionId: fila.session_id,
    expiresAt: fila.expires_at,
    user: {
      id: fila.user_id,
      name: fila.name,
      email: fila.email,
      role: fila.role,
    },
  };
}

// --------------------------------------------------------------
//  destroySession() - cerrar sesion
// --------------------------------------------------------------
/**
 * Cierra la sesion actual: borra la fila y elimina la cookie.
 *
 * EL DELETE ES LA PARTE ESENCIAL. Borrar solo la cookie dejaria la
 * sesion viva en el servidor: quien tuviera una copia del token
 * seguiria entrando con ella. Un cierre de sesion de verdad invalida
 * la sesion en el SERVIDOR, y eso es precisamente lo que un JWT
 * autocontenido no puede hacer.
 */
export async function destroySession(): Promise<void> {
  const cookieStore = await cookies();
  const token = cookieStore.get(SESSION_COOKIE_NAME)?.value;

  if (token) {
    // No hace falta comprobar antes de quien es la sesion: si el
    // token es valido borra su propia fila, y si es basura no borra
    // nada. El WHERE va sobre el hash, que es la clave primaria.
    await query(`DELETE FROM sessions WHERE id = $1`, [hashDelToken(token)]);
  }

  // La cookie se borra en cualquier caso, incluso si no habia sesion
  // valida: el estado final que se busca es "sin cookie".
  cookieStore.delete(SESSION_COOKIE_NAME);
}
