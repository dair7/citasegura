import * as z from "zod";

import { hashPassword } from "@/lib/auth/password";
import { query } from "@/lib/db";
import { registerSchema } from "@/lib/validations/auth";

/**
 * CitaSegura - POST /api/auth/register  (SCRUM-3)
 *
 * Registro de usuario. Este archivo es la FRONTERA DE CONFIANZA de la
 * aplicacion: todo lo que entra por aqui es hostil hasta que el
 * esquema Zod demuestre lo contrario.
 */

// Necesita el runtime de Node: el driver 'pg' abre sockets TCP y
// bcryptjs usa el modulo crypto. No funcionaria en el runtime Edge.
export const runtime = "nodejs";

/**
 * Respuesta unica para "creado" y para "ya existia".
 *
 * ANTI-ENUMERACION DE USUARIOS: si el servidor contestara distinto en
 * cada caso, cualquiera podria comprobar que correos tienen cuenta en
 * el sistema simplemente intentando registrarlos. En una aplicacion de
 * citas eso ya filtra informacion personal, y ademas entrega la lista
 * de objetivos validos para atacar el inicio de sesion.
 */
const RESPUESTA_REGISTRO_ACEPTADO = {
  message:
    "Si el correo no estaba registrado, la cuenta ha sido creada. Ya puedes iniciar sesion.",
} as const;

/** Codigo de error de PostgreSQL para violacion de restriccion UNIQUE. */
const PG_UNIQUE_VIOLATION = "23505";

/** Comprueba si un error de 'pg' es la violacion de UNIQUE de email. */
function esEmailDuplicado(error: unknown): boolean {
  return (
    typeof error === "object" &&
    error !== null &&
    "code" in error &&
    (error as { code?: unknown }).code === PG_UNIQUE_VIOLATION
  );
}

export async function POST(request: Request) {
  // ------------------------------------------------------------
  //  1. Exigir Content-Type JSON
  // ------------------------------------------------------------
  // Ademas de descartar peticiones mal formadas, es una barrera
  // barata contra CSRF: un formulario HTML de otro sitio web solo
  // puede enviar los tipos de formulario clasicos, nunca
  // application/json (el navegador exigiria un preflight CORS que
  // este endpoint no autoriza).
  const contentType = request.headers.get("content-type") ?? "";
  if (!contentType.includes("application/json")) {
    return Response.json(
      { message: "Se esperaba un cuerpo JSON." },
      { status: 415 },
    );
  }

  // ------------------------------------------------------------
  //  2. Leer el cuerpo sin confiar en el
  // ------------------------------------------------------------
  // request.json() LANZA si el cuerpo no es JSON valido. Sin este
  // try/catch, un cuerpo basura tumbaria el handler con un 500 y la
  // traza de error; con el, es un 400 limpio.
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return Response.json(
      { message: "El cuerpo de la peticion no es JSON valido." },
      { status: 400 },
    );
  }

  // ------------------------------------------------------------
  //  3. Validar con el MISMO esquema que usa el cliente
  // ------------------------------------------------------------
  // La validacion del navegador se salta con curl, con Burp o con las
  // herramientas de desarrollo. ESTA es la que manda. El esquema es
  // strictObject, asi que tambien rechaza claves no declaradas como
  // {"role":"admin"} (mass assignment).
  //
  // El esquema NORMALIZA a la vez que valida: recorta espacios del
  // nombre y pasa el correo a minusculas. Por eso a partir de aqui se
  // usa parsed.data y nunca el body original.
  const parsed = registerSchema.safeParse(body);

  if (!parsed.success) {
    // Se devuelven los mensajes por campo porque el formulario los
    // necesita para guiar al usuario, y no revelan nada sensible:
    // describen la regla incumplida, no datos de otras cuentas.
    return Response.json(
      {
        message: "Los datos enviados no son validos.",
        errors: z.flattenError(parsed.error).fieldErrors,
      },
      { status: 400 },
    );
  }

  const { name, email, password } = parsed.data;

  try {
    // ----------------------------------------------------------
    //  4. Hashear ANTES de tocar la base de datos
    // ----------------------------------------------------------
    // El orden es una decision de seguridad, no de estilo: asi el
    // caso "correo ya registrado" tarda lo mismo que el caso nuevo.
    // Si se comprobara la existencia primero y se hasheara despues,
    // la respuesta del duplicado llegaria ~400 ms antes y esa
    // diferencia medible permitiria enumerar usuarios por tiempo.
    const passwordHash = await hashPassword(password);

    // ----------------------------------------------------------
    //  5. INSERT parametrizado
    // ----------------------------------------------------------
    // El SQL y los datos viajan separados ($1, $2, $3): un valor
    // jamas se interpreta como codigo SQL (OWASP A03: Injection).
    //
    // No se envian 'role', 'failed_attempts' ni 'locked_until': los
    // pone la base de datos con sus DEFAULT. Aunque el atacante
    // colara un rol en el JSON, aqui no hay columna donde escribirlo
    // (minimo privilegio por construccion).
    //
    // No se hace un SELECT previo para ver si el correo existe: entre
    // la consulta y el INSERT cabe otra peticion con el mismo correo
    // (condicion de carrera TOCTOU). Se deja que la restriccion
    // UNIQUE de la base de datos decida, que es atomica.
    await query(
      `INSERT INTO users (name, email, password_hash)
       VALUES ($1, $2, $3)`,
      [name, email, passwordHash],
    );

    // 201 Created, y NUNCA se devuelve el usuario insertado: ni el
    // password_hash (un hash filtrado se puede atacar offline con
    // hashcat) ni el id (devolverlo solo en el caso nuevo delataria
    // por el cuerpo lo mismo que se oculta en el estado).
    return Response.json(RESPUESTA_REGISTRO_ACEPTADO, { status: 201 });
  } catch (error) {
    if (esEmailDuplicado(error)) {
      // Correo ya registrado: se responde EXACTAMENTE lo mismo que en
      // un registro correcto. El motivo real queda en el log del
      // servidor, que solo ve el equipo de desarrollo.
      //
      // Limitacion asumida: el dueño legitimo de la cuenta no recibe
      // aviso. La solucion completa es enviarle un correo ("ya tienes
      // cuenta"), porque ese canal solo lo lee el dueño del buzon.
      // Requiere servidor de correo; pendiente.
      console.warn("[register] intento de registro con correo ya existente");
      return Response.json(RESPUESTA_REGISTRO_ACEPTADO, { status: 201 });
    }

    // Cualquier otro fallo (base de datos caida, CHECK incumplido...)
    // se registra completo en el servidor y se resume al cliente en un
    // mensaje generico: un mensaje de error detallado revela version
    // de PostgreSQL, nombres de tablas y columnas, rutas de archivos...
    // material de reconocimiento para un atacante.
    console.error("[register] error inesperado:", error);
    return Response.json(
      { message: "No se pudo completar el registro. Intentalo de nuevo." },
      { status: 500 },
    );
  }
}
