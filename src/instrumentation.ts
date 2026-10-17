/**
 * CitaSegura - Comprobaciones de arranque (CITA-15).
 *
 * Next.js ejecuta register() UNA vez al arrancar el servidor, y no
 * atiende ninguna peticion hasta que termina. Aqui se valida el entorno
 * (src/lib/arranque.ts -> src/lib/env.ts): si falta una variable
 * obligatoria, el proceso termina con codigo 1 y la aplicacion no llega
 * a servir nada.
 *
 * Sin esto, la validacion correria la primera vez que una ruta
 * importara src/lib/db.ts, es decir, con la primera peticion que toque
 * la base: el servidor arrancaria con la configuracion incompleta y
 * pareceria sano hasta entonces.
 *
 * Solo en el runtime de Node.js, que es donde corren las rutas que
 * usan la base. La condicion tiene que ser literalmente
 * process.env.NEXT_RUNTIME === "nodejs" alrededor del import dinamico:
 * es la forma que el compilador reconoce para dejar ese codigo fuera
 * del runtime edge, donde process.exit no existe.
 */
export async function register() {
  if (process.env.NEXT_RUNTIME === "nodejs") {
    const { comprobarEntornoAlArrancar } = await import("@/lib/arranque");
    await comprobarEntornoAlArrancar();
  }
}
