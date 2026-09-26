import { destroySession } from "@/lib/auth/session";

/**
 * CitaSegura - POST /api/auth/logout  (SCRUM-6)
 *
 * Cierra la sesion: borra la fila de sessions y elimina la cookie.
 */

export const runtime = "nodejs";

/**
 * Es POST y no GET A PROPOSITO.
 *
 * Cerrar sesion CAMBIA ESTADO, y sameSite=lax SI envia la cookie en
 * las navegaciones GET de nivel superior. Si el logout respondiera a
 * GET, bastaria con que alguien incrustara
 *   <img src="https://citasegura/api/auth/logout">
 * en cualquier pagina para desconectar a quien la visitara.
 *
 * Regla general que se deriva de esto: ninguna ruta que modifique
 * estado responde a GET. Al ser POST, sameSite=lax ya impide que la
 * peticion llegue con cookie desde otro sitio.
 */
export async function POST() {
  try {
    await destroySession();

    // Siempre 200, incluso si no habia sesion: el logout es
    // IDEMPOTENTE. Responder distinto segun si habia sesion o no
    // seria otro oraculo, esta vez sobre el estado de la cookie.
    return Response.json({ message: "Sesion cerrada." }, { status: 200 });
  } catch (error) {
    console.error("[logout] error inesperado:", error);
    return Response.json(
      { message: "No se pudo cerrar la sesion." },
      { status: 500 },
    );
  }
}
