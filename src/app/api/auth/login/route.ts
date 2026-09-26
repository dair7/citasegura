import { verifyPassword } from "@/lib/auth/password";
import { createSession } from "@/lib/auth/session";
import { query } from "@/lib/db";
import { loginSchema } from "@/lib/validations/auth";

/**
 * CitaSegura - POST /api/auth/login  (SCRUM-6)
 *
 * Inicio de sesion. Como el registro, este archivo es frontera de
 * confianza: nada de lo que llega se da por bueno.
 *
 * NO implementa el bloqueo por intentos fallidos: eso es SCRUM-7, y
 * para eso ya existen las columnas failed_attempts y locked_until.
 */

// Runtime de Node: 'pg' abre sockets TCP y bcryptjs usa crypto.
export const runtime = "nodejs";

/**
 * UNICA respuesta de fallo, sea cual sea la causa.
 *
 * No se dice nunca cual de los dos campos fallo. Un mensaje del tipo
 * "ese correo no esta registrado" convierte el login en un directorio
 * de usuarios: se le pasa una lista de correos y el sistema responde
 * quien tiene cuenta. En una aplicacion de citas medicas eso ya es un
 * dato personal, y ademas le entrega al atacante la lista de objetivos
 * validos sobre los que insistir.
 */
const RESPUESTA_CREDENCIALES_INVALIDAS = {
  message: "Correo o contrasena incorrectos.",
} as const;

/**
 * Hash SEÑUELO para igualar los tiempos.
 *
 * Es el hash bcrypt (coste 12, el mismo que el de las cuentas reales)
 * de una cadena aleatoria de 32 bytes que se descarto al generarla.
 *
 * Su unica funcion es dar algo contra lo que comparar cuando el correo
 * NO existe, para que ese camino tarde lo mismo que el de una cuenta
 * real. Sin el, la respuesta "no existe" llegaria en milisegundos y la
 * respuesta "contrasena incorrecta" en ~425 ms, y esa diferencia
 * medible delata que cuentas existen aunque el mensaje sea identico:
 * es un CANAL LATERAL DE TEMPORIZACION.
 *
 * El coste 12 es imprescindible: bcrypt tarda segun el coste grabado
 * DENTRO del hash, asi que un señuelo mas barato reabriria la fuga.
 *
 * No es un secreto y no pasa nada si se lee: no pertenece a ninguna
 * cuenta, asi que romperlo no abre nada.
 */
const HASH_SENUELO =
  "$2b$12$iqGLNcU7tjbujyHqsGsCdeDF1BRAC8SvPlcYq5SsLy7BfUBPc7p.C";

type FilaUsuario = {
  id: string;
  name: string;
  email: string;
  role: string;
  password_hash: string;
};

export async function POST(request: Request) {
  // ------------------------------------------------------------
  //  1. Exigir Content-Type JSON
  // ------------------------------------------------------------
  // Barrera barata contra CSRF: un formulario HTML alojado en otro
  // sitio no puede enviar application/json sin un preflight CORS que
  // este endpoint no autoriza.
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
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return Response.json(RESPUESTA_CREDENCIALES_INVALIDAS, { status: 400 });
  }

  // ------------------------------------------------------------
  //  3. Validar con Zod
  // ------------------------------------------------------------
  // A diferencia del registro, aqui NO se devuelven los errores por
  // campo. En un formulario de alta es util decir "el correo no es
  // valido"; en un login, cada detalle extra es informacion para
  // quien esta probando. El mensaje es siempre el mismo.
  //
  // El 400 (en lugar de 401) solo distingue "peticion mal formada" de
  // "credenciales rechazadas", y eso no filtra nada sobre las cuentas:
  // el formato del propio JSON ya lo conoce quien lo envio.
  const parsed = loginSchema.safeParse(body);

  if (!parsed.success) {
    return Response.json(RESPUESTA_CREDENCIALES_INVALIDAS, { status: 400 });
  }

  const { email, password } = parsed.data;

  try {
    // ----------------------------------------------------------
    //  4. Buscar el usuario (consulta parametrizada)
    // ----------------------------------------------------------
    // El correo llega ya normalizado a minusculas por el esquema, que
    // es como lo guarda la base de datos (CHECK email = lower(email)).
    // Por eso basta una comparacion por igualdad, que ademas usa el
    // indice del UNIQUE.
    const resultado = await query<FilaUsuario>(
      `SELECT id, name, email, role, password_hash
         FROM users
        WHERE email = $1`,
      [email],
    );

    const usuario = resultado.rows[0];

    // ----------------------------------------------------------
    //  5. Verificar SIEMPRE, exista o no el usuario
    // ----------------------------------------------------------
    // Si no hay usuario se compara contra el señuelo y el resultado se
    // descarta. Lo importante no es el booleano, es que el reloj mida
    // lo mismo en los dos casos.
    const hashContraElQueComparar = usuario?.password_hash ?? HASH_SENUELO;
    const passwordCorrecta = await verifyPassword(
      password,
      hashContraElQueComparar,
    );

    // Una sola salida para los dos fallos posibles, con el mismo
    // cuerpo y el mismo estado. Ni el mensaje ni el tiempo distinguen
    // "no existe" de "contrasena incorrecta".
    if (!usuario || !passwordCorrecta) {
      return Response.json(RESPUESTA_CREDENCIALES_INVALIDAS, { status: 401 });
    }

    // ----------------------------------------------------------
    //  6. Credenciales correctas: crear la sesion
    // ----------------------------------------------------------
    // Token nuevo en cada inicio de sesion (ver createSession: evita
    // la fijacion de sesion). La cookie httpOnly se añade aqui, en el
    // Route Handler, que es el unico lugar donde HTTP permite enviar
    // la cabecera Set-Cookie.
    await createSession(usuario.id);

    // Se devuelven solo los datos que la interfaz necesita para
    // saludar al usuario. NUNCA el password_hash: un hash filtrado se
    // ataca sin prisa y sin conexion con hashcat.
    return Response.json(
      {
        message: "Sesion iniciada.",
        user: {
          name: usuario.name,
          email: usuario.email,
          role: usuario.role,
        },
      },
      { status: 200 },
    );
  } catch (error) {
    // El detalle va al log del servidor; al cliente, un mensaje
    // generico. Un error tecnico devuelto al navegador revela version
    // de PostgreSQL, nombres de columnas y rutas de archivos.
    console.error("[login] error inesperado:", error);
    return Response.json(
      { message: "No se pudo iniciar sesion. Intentalo de nuevo." },
      { status: 500 },
    );
  }
}
