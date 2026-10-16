/**
 * Una cita tal como la devuelve GET /api/citas (CITA-12).
 *
 * Es TODO lo que el panel sabe de una cita, y no le hace falta mas:
 * con estos campos se pinta tanto la fila de la lista como su detalle.
 * No hay user_id: la API no lo devuelve, porque el dueño es siempre
 * quien pregunta.
 */
export type Cita = {
  id: string;
  /** ISO 8601 en UTC, tal como lo serializa la API. */
  scheduledAt: string;
  reason: string;
  /** Los dos unicos valores que admite el CHECK de la tabla. */
  status: "programada" | "cancelada";
  createdAt: string;
};
