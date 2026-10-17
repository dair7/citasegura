import "server-only";

import { z } from "zod";

/**
 * CitaSegura - Variables de entorno validadas (CITA-15).
 *
 * Es el UNICO sitio de la aplicacion que lee una variable de
 * configuracion propia de process.env. El resto del codigo importa
 * 'env' de aqui, ya validado y con su tipo.
 *
 * SE VALIDA AL IMPORTARSE. Si falta una variable obligatoria, este
 * modulo lanza un error en cuanto se evalua. Lo importan:
 *   - src/instrumentation.ts, cuyo register() ejecuta Next.js una vez
 *     al arrancar el servidor y antes de atender ninguna peticion. Es
 *     lo que hace que la aplicacion NO ARRANQUE con la configuracion
 *     incompleta.
 *   - src/lib/db.ts, que necesita la cadena de conexion.
 *
 * Por que fallar al arrancar y no en la primera peticion: una
 * aplicacion que arranca "a medias" parece sana hasta que alguien usa
 * la parte rota, y entonces falla delante de un usuario y con un error
 * generico. Fallar al arrancar lo detecta quien despliega, con un
 * mensaje que dice exactamente que falta.
 *
 * EL MENSAJE NUNCA INCLUYE UN VALOR. Nombra la variable y dice que le
 * pasa, nada mas. Los errores de arranque acaban en la consola, en los
 * registros del servidor o en una captura de pantalla, y la cadena de
 * conexion lleva la contrasena de la base. Por eso tampoco se adjunta
 * el error de Zod como 'cause': Node lo imprimiria entero.
 *
 * SOLO SERVIDOR: el import "server-only" de la primera linea hace que
 * el build falle si un Client Component importa este archivo, directa
 * o indirectamente. Asi la cadena de conexion no puede acabar en el
 * JavaScript del navegador por un import descuidado.
 */

/** El marcador de .env.example. Si llega tal cual, no se configuro. */
const MARCADOR_DE_EJEMPLO = "CAMBIAR_POR_LA_CONTRASENA";

/**
 * Lo que la aplicacion necesita del entorno. z.object y no
 * z.strictObject, al contrario que en las peticiones: process.env
 * trae muchas variables del sistema (PATH, NODE_ENV...) que no son de
 * la aplicacion, y no son un intento de mass assignment. z.object las
 * descarta y 'env' solo contiene lo declarado aqui.
 */
const esquemaEntorno = z.object({
  DATABASE_URL: z
    .string({
      error: (issue) =>
        issue.input === undefined
          ? "falta. Definela en .env.local (ver .env.example)."
          : "debe ser texto.",
    })
    .min(1, { error: "esta vacia. Definela en .env.local (ver .env.example)." })
    .superRefine((valor, ctx) => {
      let url: URL;
      try {
        url = new URL(valor);
      } catch {
        ctx.addIssue({ code: "custom", message: "no es una URL valida." });
        return;
      }

      if (url.protocol !== "postgresql:" && url.protocol !== "postgres:") {
        ctx.addIssue({
          code: "custom",
          message: "debe empezar por postgresql://.",
        });
      }

      // Convencion 5 del proyecto, comprobada al arrancar: la aplicacion
      // NUNCA se conecta como superusuario. Si alguien pone postgres
      // "para probar", todo funcionaria y el aislamiento de privilegios
      // de db/roles.sql dejaria de proteger nada, en silencio.
      if (url.username === "postgres") {
        ctx.addIssue({
          code: "custom",
          message:
            "usa el superusuario postgres. La aplicacion debe conectarse como citasegura_app.",
        });
      }

      if (url.password === "") {
        ctx.addIssue({ code: "custom", message: "no lleva contrasena." });
      } else if (decodeURIComponent(url.password) === MARCADOR_DE_EJEMPLO) {
        ctx.addIssue({
          code: "custom",
          message:
            "conserva el marcador de .env.example. Sustituyelo por la contrasena real.",
        });
      }
    }),
});

export type Entorno = z.infer<typeof esquemaEntorno>;

function validarEntorno(fuente: NodeJS.ProcessEnv): Entorno {
  const resultado = esquemaEntorno.safeParse(fuente);

  if (!resultado.success) {
    // Solo el NOMBRE de la variable (issue.path) y el mensaje propio de
    // cada regla, escritos arriba sin interpolar el valor. Nunca
    // issue.input ni el error de Zod completo.
    const lineas = resultado.error.issues.map(
      (issue) => `  - ${issue.path.join(".")}: ${issue.message}`,
    );
    throw new Error(
      [
        "Configuracion de entorno invalida. CitaSegura no arranca:",
        ...lineas,
      ].join("\n"),
    );
  }

  return resultado.data;
}

export const env: Readonly<Entorno> = Object.freeze(
  validarEntorno(process.env),
);
