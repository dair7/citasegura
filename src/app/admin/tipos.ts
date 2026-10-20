/**
 * Lo que la vista de administrador recibe del servidor (CITA-19).
 *
 * Estos tipos son TODO lo que llega al navegador: la pagina los pasa
 * como props a un Client Component, y React los serializa dentro del
 * HTML. Por eso lo que no esta aqui no puede filtrarse, y lo que esta
 * aqui lo ve cualquiera que abra el codigo fuente de la pagina.
 *
 * Fuera a proposito:
 *   - password_hash, failed_attempts y locked_until: no se leen de la
 *     base (src/app/admin/datos.ts).
 *   - Los id de cuentas y citas: la vista solo consulta, no tiene
 *     ninguna accion que necesite identificar una fila.
 */
export type CitaAdmin = {
  /** ISO 8601 en UTC. */
  scheduledAt: string;
  reason: string;
  status: "programada" | "cancelada";
  createdAt: string;
  titularNombre: string;
  titularCorreo: string;
};

export type UsuarioAdmin = {
  name: string;
  email: string;
  role: string;
  /** Fecha de registro, ISO 8601 en UTC. */
  createdAt: string;
};
