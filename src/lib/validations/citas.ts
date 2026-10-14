import * as z from "zod";

/**
 * CitaSegura - Esquemas de validacion de citas (CITA-12).
 *
 * ESTE ARCHIVO SE USA EN CLIENTE Y EN SERVIDOR, igual que auth.ts.
 *
 * En el navegador sirve para avisar al usuario antes de enviar. La
 * validacion que MANDA es la del servidor, que vuelve a ejecutar este
 * mismo esquema sobre el cuerpo de la peticion: la del cliente se salta
 * con curl, con Burp o con las herramientas de desarrollo.
 */

// --------------------------------------------------------------
//  Motivo
// --------------------------------------------------------------
/**
 * Longitud maxima del motivo. DEBE COINCIDIR con el CHECK
 * appointments_reason_longitud de db/appointments.sql
 * (char_length(reason) <= 500).
 *
 * Si este limite fuera MAYOR que el de la base, un motivo de 501
 * caracteres pasaria la validacion y lo rechazaria el CHECK: el
 * usuario veria un error generico del servidor en lugar de un mensaje
 * que le diga que hacer.
 *
 * Con el mismo numero, Zod es IGUAL O MAS estricto que la base, nunca
 * menos: char_length() de PostgreSQL cuenta caracteres, mientras que
 * .length de JavaScript cuenta unidades UTF-16 (un emoji cuenta 2).
 * Lo que pasa este esquema, la base lo acepta.
 */
export const MOTIVO_MAX_CARACTERES = 500;

// --------------------------------------------------------------
//  Crear cita
// --------------------------------------------------------------
/**
 * Cuerpo de POST /api/citas: SOLO fecha y motivo.
 *
 * z.strictObject RECHAZA EL CUERPO COMPLETO si llega cualquier clave
 * no declarada. Es la misma defensa contra mass assignment que en el
 * registro, y aqui protege tres cosas concretas:
 *
 *   - userId: el dueño de la cita sale SIEMPRE de la sesion. Si el
 *     esquema lo aceptara, cualquiera podria agendar citas a nombre de
 *     otra persona.
 *   - status: una cita nace 'programada'; no se puede crear ya
 *     cancelada ni con un estado inventado.
 *   - id / createdAt: los pone la base de datos, no el cliente.
 *
 * Rechazar (y no ignorar en silencio) es deliberado: un cuerpo con
 * claves de mas no es un error de tecleo, es alguien probando.
 */
export const crearCitaSchema = z.strictObject({
  // Fecha y hora en ISO 8601 CON ZONA HORARIA OBLIGATORIA
  // ("2026-10-20T15:30:00-05:00" o "...Z").
  //
  // Una hora sin zona ("2026-10-20T15:30") es ambigua: el servidor la
  // interpretaria con SU zona y la cita quedaria a otra hora. Es el
  // mismo motivo por el que la columna es TIMESTAMPTZ y no TIMESTAMP.
  scheduledAt: z
    .iso.datetime({
      offset: true,
      message: "Indica una fecha y hora validas, con zona horaria.",
    })
    .transform((valor) => new Date(valor))
    // Fecha futura. En el navegador es solo comodidad (usa el reloj
    // del equipo, que el usuario controla). En el servidor se compara
    // con el reloj del servidor, y detras sigue el CHECK
    // scheduled_at >= created_at, que usa el reloj de la base.
    .refine((fecha) => fecha.getTime() > Date.now(), {
      message: "La cita debe ser en una fecha futura.",
    }),

  // Se recorta antes de medir, como hace el CHECK con btrim(): un
  // motivo de solo espacios es un motivo vacio. Se guarda ya recortado.
  // El mensaje de z.string() cubre el campo ausente o de otro tipo;
  // sin el, Zod responderia con su texto por defecto en ingles.
  reason: z
    .string({ error: "Indica el motivo de la cita." })
    .trim()
    .min(1, { message: "Indica el motivo de la cita." })
    .max(MOTIVO_MAX_CARACTERES, {
      message: `El motivo no puede exceder ${MOTIVO_MAX_CARACTERES} caracteres.`,
    }),
});

/** Datos ya validados: scheduledAt es un Date. */
export type CrearCitaInput = z.output<typeof crearCitaSchema>;
/** Datos tal como los envia el cliente: scheduledAt es texto ISO. */
export type CrearCitaRawInput = z.input<typeof crearCitaSchema>;

// --------------------------------------------------------------
//  Identificador de cita (segmento [id] de la URL)
// --------------------------------------------------------------
/**
 * El id llega en la URL, que es tan hostil como el cuerpo.
 *
 * Validarlo ANTES de usarlo en SQL evita que un id mal formado llegue
 * a PostgreSQL: la base lo rechazaria con un error de sintaxis de UUID
 * (codigo 22P02) que acabaria en un 500. El endpoint responde en su
 * lugar el mismo 404 que a una cita inexistente o ajena.
 */
export const citaIdSchema = z.uuid();
