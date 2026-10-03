import { query } from "@/lib/db";

/**
 * CitaSegura - Bloqueo de cuenta por intentos fallidos (CITA-10).
 *
 * La politica vive AQUI y no repartida por el endpoint, para que haya
 * un solo sitio donde leerla y cambiarla.
 *
 * Privilegios: la aplicacion solo tiene UPDATE sobre las columnas
 * failed_attempts y locked_until de users (ver db/roles.sql, apartado
 * 3.b). Cualquier otra columna esta fuera de su alcance, asi que este
 * modulo no podria tocar password_hash ni role ni por error ni por una
 * inyeccion.
 */

/**
 * Intentos fallidos consecutivos que disparan el bloqueo.
 *
 * Una persona se equivoca 1-3 veces de forma normal (mayusculas
 * activadas, confundir dos contrasenas). 5 deja margen al error
 * honesto y deja la fuerza bruta en linea en un goteo: 5 intentos
 * cada 15 minutos son 20 por hora, 480 al dia. Contra una contrasena
 * que cumple la politica de CITA-6 (12 caracteres, cuatro clases),
 * 480 intentos diarios es indistinguible de cero.
 */
export const MAX_FAILED_ATTEMPTS = 5;

/**
 * Duracion del bloqueo, en minutos.
 *
 * Corto a proposito. Con 480 intentos al dia la fuerza bruta ya es
 * inviable, asi que alargarlo a horas no aporta seguridad: solo
 * agrava los dos efectos secundarios (el usuario legitimo bloqueado
 * por un error de tecleo, y el DoS por bloqueo descrito abajo).
 *
 * Vence solo, sin desbloqueo manual: si hiciera falta un
 * administrador, el propio bloqueo seria un ataque de saturacion al
 * soporte.
 */
export const LOCKOUT_MINUTES = 15;

/**
 * LIMITACION CONOCIDA - DoS POR BLOQUEO.
 *
 * Bloquear por cuenta permite que un atacante que conozca el correo
 * de alguien lo deje fuera a voluntad: 5 intentos basura cada 15
 * minutos y esa persona no entra nunca. Es el precio de este control,
 * y es un intercambio consciente: se prefiere una cuenta
 * temporalmente inaccesible a una cuenta reventada por fuerza bruta.
 *
 * Que lo mitigaria (no implementado aqui):
 *
 * - LIMITE POR IP ademas de por cuenta: el atacante gasta su propia
 *   cuota antes de agotar la de la victima. Es la mitigacion mas
 *   efectiva y la primera que habria que añadir.
 * - RETARDO PROGRESIVO (exponential backoff) en lugar de bloqueo
 *   duro: cada fallo tarda mas en responder. Frena la fuerza bruta
 *   sin dejar a nadie fuera del todo.
 * - CAPTCHA a partir del tercer fallo: encarece el ataque
 *   automatizado sin castigar a la persona real.
 * - No bloquear si la contrasena enviada NUNCA se ha acercado, o
 *   permitir siempre el acceso desde un dispositivo ya conocido.
 *
 * La duracion corta de 15 minutos acota el daño mientras esto no
 * exista.
 */

/** Estado de la cuenta despues de registrar un fallo. */
export type EstadoTrasFallo = {
  failedAttempts: number;
  lockedUntil: Date | null;
};

/**
 * Registra UN intento fallido y bloquea la cuenta si se alcanza el
 * umbral. Devuelve el estado resultante.
 *
 * TODO OCURRE EN UNA SOLA SENTENCIA SQL, y eso es la defensa contra
 * la CONDICION DE CARRERA. Asi seria la forma incorrecta:
 *
 *   const n = await query("SELECT failed_attempts ...");  // lee 4
 *   await query("UPDATE ... SET failed_attempts = $1", [n + 1]);
 *
 * Con dos intentos casi simultaneos, los dos leen 4 y los dos
 * escriben 5: se pierde un fallo (lost update), y repitiendo el truco
 * en paralelo el contador nunca llega a 5 y el bloqueo no salta
 * jamas. Aqui, en cambio, 'failed_attempts + 1' se evalua DENTRO del
 * motor: PostgreSQL toma un cerrojo sobre la fila, la segunda
 * sentencia espera y vuelve a evaluar sobre el valor ya actualizado.
 * El contador no puede perder cuentas.
 *
 * La decision de bloquear va en la MISMA sentencia por el mismo
 * motivo: si se contara primero y se decidiera despues, entre las dos
 * consultas cabria otro intento (TOCTOU).
 *
 * La ventana se reinicia si habia un bloqueo YA VENCIDO: ese fallo
 * cuenta como el primero de una tanda nueva. Si no, una cuenta que se
 * bloqueo una vez se volveria a bloquear con un solo error para
 * siempre.
 */
export async function registrarIntentoFallido(
  userId: string,
): Promise<EstadoTrasFallo | null> {
  const resultado = await query<{
    failed_attempts: number;
    locked_until: Date | null;
  }>(
    `UPDATE users
        SET failed_attempts = CASE
                WHEN locked_until IS NOT NULL AND locked_until <= now()
                    THEN 1
                ELSE failed_attempts + 1
            END,
            locked_until = CASE
                -- El bloqueo anterior ya vencio: empieza ventana nueva.
                WHEN locked_until IS NOT NULL AND locked_until <= now()
                    THEN NULL
                -- Este fallo alcanza el umbral: se bloquea.
                WHEN failed_attempts + 1 >= $2
                    THEN now() + make_interval(mins => $3::int)
                -- Todavia hay margen: se deja como estaba.
                ELSE locked_until
            END
      WHERE id = $1
      RETURNING failed_attempts, locked_until`,
    [userId, MAX_FAILED_ATTEMPTS, LOCKOUT_MINUTES],
  );

  const fila = resultado.rows[0];

  if (!fila) {
    return null;
  }

  return {
    failedAttempts: fila.failed_attempts,
    lockedUntil: fila.locked_until,
  };
}

/**
 * Reinicia el contador tras un inicio de sesion correcto.
 *
 * El WHERE extra evita escribir cuando ya esta a cero, que es el caso
 * normal: sin el, CADA inicio de sesion generaria una escritura y una
 * fila muerta en la tabla sin cambiar nada.
 *
 * Reiniciar es imprescindible: si el contador no volviera a cero, los
 * fallos se acumularian a lo largo de meses y cualquier cuenta
 * terminaria bloqueandose sola por errores de tecleo repartidos en el
 * tiempo. Lo que se cuenta son fallos CONSECUTIVOS.
 */
export async function reiniciarIntentosFallidos(userId: string): Promise<void> {
  await query(
    `UPDATE users
        SET failed_attempts = 0,
            locked_until = NULL
      WHERE id = $1
        AND (failed_attempts <> 0 OR locked_until IS NOT NULL)`,
    [userId],
  );
}
