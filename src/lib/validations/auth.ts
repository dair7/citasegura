import * as z from "zod";

/**
 * CitaSegura - Esquemas de validacion de autenticacion.
 *
 * ESTE ARCHIVO SE USA EN CLIENTE Y EN SERVIDOR.
 *
 * La validacion del cliente es solo comodidad para el usuario: se puede
 * saltar por completo con las herramientas del navegador, con curl o con
 * un proxy como Burp. La validacion que MANDA es la del servidor, que
 * vuelve a ejecutar este mismo esquema sobre el cuerpo de la peticion.
 */

// --------------------------------------------------------------
//  Constantes de bcrypt
// --------------------------------------------------------------
/**
 * Factor de coste de bcrypt. Cada +1 DUPLICA el tiempo de calculo.
 * 12 es el equilibrio recomendado hoy: lento para un atacante que
 * prueba millones de contrasenas, tolerable para un inicio de sesion.
 */
export const BCRYPT_COST_FACTOR = 12;

/**
 * bcrypt solo considera los primeros 72 BYTES de la contrasena y
 * descarta el resto SIN AVISAR. Si no se limitara aqui, dos
 * contrasenas distintas que compartan los primeros 72 bytes serian
 * equivalentes para el sistema.
 */
export const BCRYPT_MAX_PASSWORD_BYTES = 72;

/** Longitud en BYTES (no en caracteres): una 'n' tilde o un emoji ocupan varios. */
function longitudEnBytes(texto: string): number {
  return new TextEncoder().encode(texto).length;
}

// --------------------------------------------------------------
//  Contrasena
// --------------------------------------------------------------
export const passwordSchema = z
  .string()
  .min(12, { message: "La contrasena debe tener al menos 12 caracteres." })
  .refine((v) => longitudEnBytes(v) <= BCRYPT_MAX_PASSWORD_BYTES, {
    message: `La contrasena no puede exceder ${BCRYPT_MAX_PASSWORD_BYTES} bytes.`,
  })
  .refine((v) => /[a-z]/.test(v), {
    message: "Debe incluir al menos una letra minuscula.",
  })
  .refine((v) => /[A-Z]/.test(v), {
    message: "Debe incluir al menos una letra mayuscula.",
  })
  .refine((v) => /[0-9]/.test(v), {
    message: "Debe incluir al menos un numero.",
  })
  .refine((v) => /[^A-Za-z0-9]/.test(v), {
    message: "Debe incluir al menos un simbolo (por ejemplo ! ? # $ % & * -).",
  });

// --------------------------------------------------------------
//  Registro
// --------------------------------------------------------------
/**
 * z.strictObject RECHAZA cualquier clave que no este declarada aqui.
 *
 * Es la defensa contra 'mass assignment': si el esquema aceptara claves
 * extra, un atacante podria enviar {"role":"admin"} o
 * {"failed_attempts":-5} en el JSON y manipular columnas que no le
 * corresponden. Con strict, el servidor rechaza el cuerpo completo.
 */
export const registerSchema = z.strictObject({
  name: z
    .string()
    .trim()
    .min(2, { message: "El nombre debe tener al menos 2 caracteres." })
    .max(80, { message: "El nombre no puede exceder 80 caracteres." }),

  // El correo se normaliza a minusculas AQUI, para que cliente, servidor
  // y la restriccion CHECK (email = lower(email)) de la base de datos
  // esperen exactamente lo mismo.
  //
  // EL ORDEN IMPORTA: se usa .pipe() para NORMALIZAR primero (recortar
  // espacios y pasar a minusculas) y VALIDAR el formato despues.
  // Al reves -- z.email().trim() -- Zod comprobaria el formato antes de
  // recortar, y un correo pegado con un espacio sobrante se rechazaria
  // como invalido aunque sea perfectamente valido.
  email: z
    .string()
    .trim()
    .toLowerCase()
    .pipe(
      z
        .email({ message: "Introduce un correo electronico valido." })
        .max(254, { message: "El correo no puede exceder 254 caracteres." }),
    ),

  password: passwordSchema,
});

/** Datos ya validados y normalizados (salida del esquema). */
export type RegisterInput = z.output<typeof registerSchema>;
/** Datos tal como los escribe el usuario (entrada del esquema). */
export type RegisterRawInput = z.input<typeof registerSchema>;
