import * as z from "zod";

import { getSession } from "@/lib/auth/session";
import { query } from "@/lib/db";
import { crearCitaSchema } from "@/lib/validations/citas";

/**
 * CitaSegura - /api/citas  (CITA-12)
 *
 *   POST  crea una cita del usuario de la sesion
 *   GET   lista las citas del usuario de la sesion
 *
 * REGLA DE ESTE ARCHIVO: el dueño de una cita es SIEMPRE el usuario
 * de la sesion. Ni el cuerpo ni la URL pueden decir de quien es una
 * cita, porque eso es lo que un atacante controla.
 */

// Runtime de Node: el driver 'pg' abre sockets TCP y no funciona en
// el runtime Edge.
export const runtime = "nodejs";

/** Codigo de error de PostgreSQL para violacion de una restriccion CHECK. */
const PG_CHECK_VIOLATION = "23514";

function esViolacionDeCheck(error: unknown): boolean {
  return (
    typeof error === "object" &&
    error !== null &&
    "code" in error &&
    (error as { code?: unknown }).code === PG_CHECK_VIOLATION
  );
}

type FilaCita = {
  id: string;
  scheduled_at: Date;
  reason: string;
  status: string;
  created_at: Date;
};

/**
 * Lo que sale hacia el cliente. NO incluye user_id: el cliente ya sabe
 * quien es, y el id interno de su cuenta no le aporta nada a la
 * interfaz. Lo que no se envia no se puede filtrar.
 */
function aRespuesta(fila: FilaCita) {
  return {
    id: fila.id,
    scheduledAt: fila.scheduled_at,
    reason: fila.reason,
    status: fila.status,
    createdAt: fila.created_at,
  };
}

// ==============================================================
//  POST /api/citas - crear una cita
// ==============================================================
export async function POST(request: Request) {
  // ------------------------------------------------------------
  //  1. Exigir sesion valida, ANTES que nada
  // ------------------------------------------------------------
  // Va antes incluso de mirar el Content-Type o el cuerpo: un anonimo
  // recibe 401 envie lo que envie, y no puede usar este endpoint para
  // descubrir las reglas de validacion. Sin cookie, getSession() no
  // consulta la base; con cookie, solo consulta sessions. La tabla de
  // citas no se toca sin una sesion valida.
  const sesion = await getSession();

  if (!sesion) {
    return Response.json({ message: "No autenticado." }, { status: 401 });
  }

  // ------------------------------------------------------------
  //  2. Exigir Content-Type JSON
  // ------------------------------------------------------------
  // Barrera barata contra CSRF: un formulario HTML de otro sitio no
  // puede enviar application/json sin un preflight CORS que este
  // endpoint no autoriza.
  const contentType = request.headers.get("content-type") ?? "";
  if (!contentType.includes("application/json")) {
    return Response.json(
      { message: "Se esperaba un cuerpo JSON." },
      { status: 415 },
    );
  }

  // ------------------------------------------------------------
  //  3. Leer el cuerpo sin confiar en el
  // ------------------------------------------------------------
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
  //  4. Validar con el MISMO esquema que usa el cliente
  // ------------------------------------------------------------
  // strictObject: si llega userId, status o cualquier clave no
  // declarada, se rechaza el cuerpo entero (mass assignment).
  //
  // Los errores por campo se devuelven porque el formulario los
  // necesita, y solo describen la regla incumplida.
  const parsed = crearCitaSchema.safeParse(body);

  if (!parsed.success) {
    return Response.json(
      {
        message: "Los datos enviados no son validos.",
        errors: z.flattenError(parsed.error).fieldErrors,
      },
      { status: 400 },
    );
  }

  const { scheduledAt, reason } = parsed.data;

  try {
    // ----------------------------------------------------------
    //  5. INSERT parametrizado
    // ----------------------------------------------------------
    // El dueño ($1) sale de la SESION, no del cuerpo: el esquema ni
    // siquiera tiene un campo donde el cliente pudiera indicarlo.
    //
    // No se envian id, status ni created_at: los pone la base con sus
    // DEFAULT, y el rol de la aplicacion no tiene permiso INSERT sobre
    // esas columnas (db/appointments.sql).
    const resultado = await query<FilaCita>(
      `INSERT INTO appointments (user_id, scheduled_at, reason)
       VALUES ($1, $2, $3)
       RETURNING id, scheduled_at, reason, status, created_at`,
      [sesion.user.id, scheduledAt, reason],
    );

    // 201 con la cita creada: es del propio usuario, devolverla no
    // revela nada que no sepa, y la interfaz necesita su id.
    return Response.json(
      { message: "Cita creada.", cita: aRespuesta(resultado.rows[0]) },
      { status: 201 },
    );
  } catch (error) {
    // Un CHECK solo puede saltar aqui si la validacion y la base no
    // coinciden en el instante: una fecha que era futura al validar y
    // ya no lo es al insertar (milisegundos). Es un error del dato,
    // no del servidor, asi que se responde 400 con un mensaje util en
    // lugar de un 500.
    if (esViolacionDeCheck(error)) {
      console.warn("[citas] INSERT rechazado por un CHECK de la base");
      return Response.json(
        { message: "Los datos enviados no son validos." },
        { status: 400 },
      );
    }

    // El detalle va al log del servidor; al cliente, un mensaje
    // generico que no revela tablas, columnas ni version de PostgreSQL.
    console.error("[citas] error inesperado al crear:", error);
    return Response.json(
      { message: "No se pudo crear la cita. Intentalo de nuevo." },
      { status: 500 },
    );
  }
}

// ==============================================================
//  GET /api/citas - listar las citas propias
// ==============================================================
/**
 * Es GET porque solo LEE, como /api/auth/me.
 */
export async function GET() {
  const sesion = await getSession();

  if (!sesion) {
    return Response.json({ message: "No autenticado." }, { status: 401 });
  }

  try {
    // EL FILTRO POR DUEÑO VA EN SQL, no en el codigo. Traer todas las
    // citas y filtrar despues en JavaScript seria el error del caso
    // DIAN en pequeño: los datos de todos los usuarios ya estarian en
    // la memoria del proceso, y un solo descuido (olvidar el filter,
    // un log del array) los expondria. Lo que no se lee de la base no
    // se puede filtrar.
    //
    // ORDER BY scheduled_at aprovecha el indice
    // (user_id, scheduled_at): la base devuelve las filas ya ordenadas.
    const resultado = await query<FilaCita>(
      `SELECT id, scheduled_at, reason, status, created_at
         FROM appointments
        WHERE user_id = $1
        ORDER BY scheduled_at`,
      [sesion.user.id],
    );

    return Response.json(
      { citas: resultado.rows.map(aRespuesta) },
      { status: 200 },
    );
  } catch (error) {
    console.error("[citas] error inesperado al listar:", error);
    return Response.json(
      { message: "No se pudieron cargar las citas. Intentalo de nuevo." },
      { status: 500 },
    );
  }
}
