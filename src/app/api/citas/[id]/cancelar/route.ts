import { getSession } from "@/lib/auth/session";
import { query } from "@/lib/db";
import { citaIdSchema } from "@/lib/validations/citas";

/**
 * CitaSegura - POST /api/citas/[id]/cancelar  (CITA-12)
 *
 * Cancela una cita del usuario de la sesion.
 *
 * ¿POR QUE "POST .../cancelar" Y NO "PATCH /api/citas/[id]"?
 *
 * Un PATCH sobre el recurso recibiria un cuerpo diciendo QUE modificar
 * ({"status":"cancelada"}). Ese cuerpo reabre la puerta del mass
 * assignment que se cerro en el registro (CITA-7): habria que decidir
 * que campos admite, que valores de estado acepta, y un error en esa
 * lista permitiria cambiar la fecha, el motivo o reactivar una cita
 * cancelada.
 *
 * Una accion con nombre propio y SIN CUERPO no puede usarse para
 * cambiar otra cosa: este endpoint solo sabe hacer una, y el unico
 * valor que escribe va fijo en el SQL. No hay nada que el cliente
 * pueda elegir salvo QUE cita, y eso tambien se filtra por dueño.
 */

// Runtime de Node: el driver 'pg' abre sockets TCP y no funciona en
// el runtime Edge.
export const runtime = "nodejs";

/**
 * UNICA respuesta para "no existe", "existe pero es de otro usuario"
 * e "id mal formado".
 *
 * ANTI-ENUMERACION DE CITAS. Si una cita ajena respondiera 403 y una
 * inexistente 404, el endpoint seria un ORACULO DE EXISTENCIA: quien
 * tuviera un id (filtrado en un log, un enlace compartido, un volcado)
 * confirmaria que la cita existe y que pertenece a otra persona. Saber
 * que otra persona tiene una cita ya es exponer un dato suyo, y esa es
 * la clase de fallo por la que un sistema de agendamiento acaba
 * exponiendo datos personales ajenos.
 *
 * Para quien no es el dueño, la cita de otro no esta "prohibida": NO
 * EXISTE. Mismo estado, mismo cuerpo y mismo camino de codigo (ver el
 * paso 3: una sola consulta resuelve ambos casos, asi que tampoco hay
 * diferencia de tiempo que medir).
 */
const RESPUESTA_CITA_NO_ENCONTRADA = {
  message: "Cita no encontrada.",
} as const;

type FilaCancelada = {
  id: string;
  status: string;
};

/**
 * Sin cuerpo: el request no se lee. Es POST porque CAMBIA ESTADO, y
 * ninguna ruta que cambie estado responde a GET (ver logout/route.ts).
 */
export async function POST(
  _request: Request,
  ctx: RouteContext<"/api/citas/[id]/cancelar">,
) {
  // ------------------------------------------------------------
  //  1. Exigir sesion valida, ANTES que nada
  // ------------------------------------------------------------
  const sesion = await getSession();

  if (!sesion) {
    return Response.json({ message: "No autenticado." }, { status: 401 });
  }

  // ------------------------------------------------------------
  //  2. Validar el id de la URL
  // ------------------------------------------------------------
  // En Next 16, params es una promesa.
  const { id } = await ctx.params;

  // Un id mal formado no llega a SQL (PostgreSQL lo rechazaria con un
  // error de sintaxis de UUID que acabaria en 500). Se responde lo
  // mismo que a una cita inexistente: no hay ningun matiz que analizar.
  const parsedId = citaIdSchema.safeParse(id);

  if (!parsedId.success) {
    return Response.json(RESPUESTA_CITA_NO_ENCONTRADA, { status: 404 });
  }

  const citaId = parsedId.data;

  try {
    // ----------------------------------------------------------
    //  3. Cancelar en UNA sentencia atomica, filtrando por dueño
    // ----------------------------------------------------------
    // CONTROL ANTI-IDOR: no basta con que el id exista. La condicion
    // user_id = $2 (el usuario de la SESION) va en el mismo WHERE, asi
    // que una cita ajena se comporta exactamente igual que una
    // inexistente: 0 filas afectadas.
    //
    // No hay un SELECT previo "¿existe?" seguido de "¿es suya?": ese
    // patron tarda distinto en cada caso (canal lateral de tiempo) y
    // deja una ventana entre la comprobacion y el UPDATE (TOCTOU).
    //
    // 'cancelada' va LITERAL en el SQL, no como parametro: este
    // endpoint no puede escribir otro estado. Y AND status =
    // 'programada' limita la unica transicion posible a
    // programada -> cancelada (ver la limitacion documentada en
    // db/appointments.sql: la base no controla el orden de los estados).
    const resultado = await query<FilaCancelada>(
      `UPDATE appointments
          SET status = 'cancelada'
        WHERE id = $1
          AND user_id = $2
          AND status = 'programada'
       RETURNING id, status`,
      [citaId, sesion.user.id],
    );

    if (resultado.rows[0]) {
      return Response.json(
        { message: "Cita cancelada.", cita: resultado.rows[0] },
        { status: 200 },
      );
    }

    // ----------------------------------------------------------
    //  4. 0 filas: ¿ya estaba cancelada, o no es del usuario?
    // ----------------------------------------------------------
    // Esta consulta TAMBIEN filtra por dueño, asi que solo puede
    // encontrar la cita si es del propio usuario. El 409 confirma la
    // existencia unicamente a quien ya es su dueño; para cualquier
    // otro, inexistente y ajena siguen siendo identicas (ambas llegan
    // aqui, ejecutan esta misma consulta y obtienen 0 filas).
    const propia = await query(
      `SELECT 1
         FROM appointments
        WHERE id = $1
          AND user_id = $2`,
      [citaId, sesion.user.id],
    );

    if (propia.rows[0]) {
      return Response.json(
        { message: "La cita ya estaba cancelada." },
        { status: 409 },
      );
    }

    return Response.json(RESPUESTA_CITA_NO_ENCONTRADA, { status: 404 });
  } catch (error) {
    console.error("[citas] error inesperado al cancelar:", error);
    return Response.json(
      { message: "No se pudo cancelar la cita. Intentalo de nuevo." },
      { status: 500 },
    );
  }
}
