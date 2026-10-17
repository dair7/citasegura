import "server-only";

/**
 * CitaSegura - Comprobacion del entorno al arrancar (CITA-15).
 *
 * La llama register() de src/instrumentation.ts, solo en el runtime de
 * Node.js. Vive en un modulo aparte porque usa process.exit, que no
 * existe en el runtime edge: asi el compilador de edge no llega a
 * verlo.
 *
 * Importa src/lib/env.ts, que valida el entorno al evaluarse. Si falta
 * una variable obligatoria, ese import lanza el error y aqui se
 * termina el proceso.
 *
 * POR QUE process.exit(1): si solo se lanzara el error, Next.js lo
 * registra ("Failed to prepare server") pero el proceso SIGUE VIVO,
 * escuchando en su puerto y respondiendo HTTP 500 a cada peticion
 * (comprobado con next start el 16 de octubre). Para quien vigila si el
 * proceso existe o si el puerto acepta conexiones, eso es un servidor
 * sano. Terminar con codigo 1 es negarse a arrancar de verdad: el
 * proceso muere, el puerto se cierra y quien despliega ve el fallo.
 *
 * Se imprime solo error.message, que env.ts compone con el NOMBRE de
 * cada variable y nunca con su valor. Ni la traza ni 'cause'.
 */
export async function comprobarEntornoAlArrancar() {
  try {
    await import("@/lib/env");
  } catch (error) {
    console.error(
      error instanceof Error ? error.message : "Configuracion de entorno invalida.",
    );
    process.exit(1);
  }
}
