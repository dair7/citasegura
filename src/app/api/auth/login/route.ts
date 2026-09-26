import {
  registrarIntentoFallido,
  reiniciarIntentosFallidos,
} from "@/lib/auth/lockout";
import { verifyPassword } from "@/lib/auth/password";
import { createSession } from "@/lib/auth/session";
import { query } from "@/lib/db";
import { loginSchema } from "@/lib/validations/auth";

/**
 * CitaSegura - POST /api/auth/login  (SCRUM-6 + SCRUM-7)
 *
 * Inicio de sesion con bloqueo de cuenta por intentos fallidos.
 * Como el registro, este archivo es frontera de confianza: nada de lo
 * que llega se da por bueno.
 *
 * La politica de bloqueo (cuantos intentos, cuanto dura) vive en
 * src/lib/auth/lockout.ts.
 */

// Runtime de Node: 'pg' abre sockets TCP y bcryptjs usa crypto.
export const runtime = "nodejs";

/**
 * UNICA respuesta de fallo, sea cual sea la causa: contrasena
 * incorrecta, correo inexistente O CUENTA BLOQUEADA.
 *
 * Que el bloqueo comparta mensaje con el resto no es descuido, es el
 * punto central. Un "demasiados intentos, espera 15 minutos" seria un
 * oraculo doble: solo una cuenta que EXISTE puede bloquearse, asi que
 * el mensaje confirma el correo; y como el atacante puede provocar el
 * bloqueo el mismo con 5 intentos basura, tendria una sonda activa
 * para comprobar cualquier correo de una lista. De paso le diria
 * cuanto esperar para cronometrar sus intentos.
 *
 * COSTE ASUMIDO: un usuario legitimo bloqueado escribe su contrasena
 * correcta, se le rechaza y no sabe por que. La solucion completa es
 * avisarle por correo, canal que solo lee el dueño de la cuenta (la
 * misma tecnica que en el registro duplicado). Pendiente.
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
 * respuesta "contrasena incorrecta" en ~400 ms, y esa diferencia
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
  cuenta_bloqueada: boolean;
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
    //
    // El bloqueo se evalua EN SQL, contra now(), es decir con el reloj
    // del servidor de base de datos. Comparar en JavaScript contra la
    // fecha del proceso seria peor: dos instancias de la aplicacion
    // con relojes distintos aplicarian bloqueos distintos.
    const resultado = await query<FilaUsuario>(
      `SELECT id,
              name,
              email,
              role,
              password_hash,
              (locked_until IS NOT NULL AND locked_until > now())
                  AS cuenta_bloqueada
         FROM users
        WHERE email = $1`,
      [email],
    );

    const usuario = resultado.rows[0];

    // ----------------------------------------------------------
    //  5. Verificar SIEMPRE, exista o no el usuario
    // ----------------------------------------------------------
    // INVARIANTE DE ESTE ENDPOINT: toda peticion que llega hasta aqui
    // ejecuta EXACTAMENTE UNA comparacion bcrypt. Ni cero ni dos.
    //
    // Si no hay usuario se compara contra el señuelo y el resultado se
    // descarta. Lo importante no es el booleano, es que el reloj mida
    // lo mismo en todos los casos.
    const hashContraElQueComparar = usuario?.password_hash ?? HASH_SENUELO;
    const passwordCorrecta = await verifyPassword(
      password,
      hashContraElQueComparar,
    );

    // El correo no existe. Misma respuesta y mismo coste temporal que
    // cualquier otro fallo.
    if (!usuario) {
      return Response.json(RESPUESTA_CREDENCIALES_INVALIDAS, { status: 401 });
    }

    // ----------------------------------------------------------
    //  6. Cuenta bloqueada (SCRUM-7)
    // ----------------------------------------------------------
    // ESTA COMPROBACION VA DESPUES DE bcrypt A PROPOSITO. Cortar aqui
    // antes de hashear haria que la respuesta de una cuenta bloqueada
    // llegara en ~15 ms en lugar de ~400 ms; y como SOLO una cuenta
    // existente puede estar bloqueada, esa diferencia de tiempo
    // volveria a delatar que correos tienen cuenta, justo lo que el
    // mensaje generico oculta.
    //
    // Durante el bloqueo NO se incrementa el contador y NO se alarga
    // locked_until. Si cada golpe extendiera el bloqueo, un atacante
    // dejaria a la victima fuera para siempre a base de insistir
    // (amplificacion del bloqueo). El bloqueo vence cuando toca,
    // aunque sigan llegando intentos.
    //
    // Tampoco se comprueba si la contrasena era correcta: con la
    // cuenta bloqueada da igual, y no se le confirma a nadie que
    // acerto la clave.
    if (usuario.cuenta_bloqueada) {
      // El registro queda en el servidor, con el id y no con el
      // correo: sirve para auditar sin volcar datos personales al log.
      console.warn(
        `[login] intento sobre cuenta bloqueada, usuario ${usuario.id}`,
      );
      return Response.json(RESPUESTA_CREDENCIALES_INVALIDAS, { status: 401 });
    }

    // ----------------------------------------------------------
    //  7. Contrasena incorrecta: contar el fallo
    // ----------------------------------------------------------
    if (!passwordCorrecta) {
      // Una sola sentencia atomica incrementa y, si toca, bloquea
      // (ver lockout.ts: asi el contador no se corrompe con intentos
      // simultaneos).
      const estado = await registrarIntentoFallido(usuario.id);

      if (estado?.lockedUntil) {
        console.warn(
          `[login] cuenta bloqueada por ${estado.failedAttempts} intentos fallidos, usuario ${usuario.id}`,
        );
      }

      // Misma respuesta que siempre. El cliente no se entera de que
      // acaba de quedar bloqueado, ni de cuantos intentos le quedaban.
      return Response.json(RESPUESTA_CREDENCIALES_INVALIDAS, { status: 401 });
    }

    // ----------------------------------------------------------
    //  8. Credenciales correctas
    // ----------------------------------------------------------
    // Reiniciar el contador es imprescindible: lo que se cuenta son
    // fallos CONSECUTIVOS. Sin reinicio, los errores de tecleo se
    // acumularian durante meses y cualquier cuenta acabaria
    // bloqueandose sola.
    await reiniciarIntentosFallidos(usuario.id);

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
