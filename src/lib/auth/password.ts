import { compare, hash } from "bcryptjs";

import {
  BCRYPT_COST_FACTOR,
  BCRYPT_MAX_PASSWORD_BYTES,
} from "@/lib/validations/auth";

/**
 * CitaSegura - Hasheo y verificacion de contrasenas con bcrypt.
 *
 * NUNCA se almacena la contrasena: solo su hash bcrypt.
 * (OWASP A02: Cryptographic Failures / A07: Identification and
 * Authentication Failures.)
 *
 * Se usa 'bcryptjs' (JavaScript puro) y no 'bcrypt' (addon nativo en
 * C++) porque el nativo exige compilarse al instalar; el formato del
 * hash es el mismo y es intercambiable con cualquier implementacion.
 */

// --------------------------------------------------------------
//  Guarda: este modulo es solo de servidor.
// --------------------------------------------------------------
// bcryptjs tambien funciona en el navegador, y ahi esta el peligro:
// hashear en el cliente convertiria el hash en la contrasena efectiva
// (quien capture el hash entra sin conocer la original). El hasheo
// pertenece al servidor, siempre.
if (typeof window !== "undefined") {
  throw new Error(
    "src/lib/auth/password.ts es codigo de servidor: el hasheo nunca se hace en el navegador.",
  );
}

/** Longitud en BYTES, no en caracteres (una 'n' tilde o un emoji ocupan varios). */
function longitudEnBytes(texto: string): number {
  return new TextEncoder().encode(texto).length;
}

// --------------------------------------------------------------
//  hashPassword() - al registrar (CITA-7)
// --------------------------------------------------------------
/**
 * Convierte una contrasena en texto plano en un hash bcrypt.
 *
 * Tres propiedades que hacen esto seguro:
 *
 * 1. SAL ALEATORIA POR CONTRASENA. bcrypt genera una sal distinta
 *    cada vez y la guarda dentro del propio hash. Dos usuarios con la
 *    misma contrasena obtienen hashes DISTINTOS, asi que una tabla
 *    precalculada (rainbow table) no sirve de nada y comparar hashes
 *    no revela que dos cuentas comparten clave.
 *
 * 2. COSTE DELIBERADO. El factor 12 obliga a 2^12 iteraciones. Es
 *    lento a proposito: irrelevante para un inicio de sesion, caro
 *    para quien prueba millones de contrasenas con una filtracion de
 *    la base de datos. (Un SHA-256 se calcula miles de millones de
 *    veces por segundo en una GPU; para eso NO sirve.)
 *
 * 3. ASINCRONO. Se usa hash() y no hashSync(): la version Sync
 *    bloquearia el unico hilo de Node cientos de milisegundos y
 *    dejaria al servidor sin atender a nadie mas.
 *
 * @throws Si la contrasena excede los 72 bytes utiles de bcrypt.
 */
export async function hashPassword(passwordEnTextoPlano: string): Promise<string> {
  // Defensa en profundidad: registerSchema ya lo valida, pero si
  // alguien llamara a esta funcion desde otro sitio sin validar,
  // bcrypt truncaria en 72 bytes EN SILENCIO y dos contrasenas
  // distintas pasarian a ser equivalentes. Mejor fallar ruidosamente.
  if (longitudEnBytes(passwordEnTextoPlano) > BCRYPT_MAX_PASSWORD_BYTES) {
    throw new Error(
      `La contrasena excede ${BCRYPT_MAX_PASSWORD_BYTES} bytes, el maximo que bcrypt procesa.`,
    );
  }

  // Al pasar un numero, bcryptjs genera la sal con ese coste y la
  // incrusta en el resultado: $2b$12$<22 chars de sal><31 de hash>.
  return hash(passwordEnTextoPlano, BCRYPT_COST_FACTOR);
}

// --------------------------------------------------------------
//  verifyPassword() - al iniciar sesion (CITA-9)
// --------------------------------------------------------------
/**
 * Comprueba si una contrasena corresponde a un hash almacenado.
 *
 * No se "descifra" el hash (bcrypt es unidireccional): se vuelve a
 * hashear la contrasena recibida con la MISMA sal y el MISMO coste,
 * que viajan dentro del hash guardado, y se comparan los resultados.
 *
 * La comparacion final la hace bcryptjs en TIEMPO CONSTANTE, sin
 * cortar en el primer caracter distinto. Un '===' normal tarda un
 * poquito mas cuantos mas caracteres iniciales coincidan, y esa
 * diferencia de tiempo es medible: un ataque de temporizacion podria
 * ir adivinando el hash caracter a caracter.
 *
 * Nunca lanza por un hash con formato invalido: bcryptjs devuelve
 * false si el hash guardado no mide 60 caracteres.
 */
export async function verifyPassword(
  passwordEnTextoPlano: string,
  hashAlmacenado: string,
): Promise<boolean> {
  // Una contrasena de mas de 72 bytes se truncaria antes de comparar,
  // asi que cualquier cadena que comparta los primeros 72 bytes con
  // la correcta entraria. Se rechaza sin llegar a comparar.
  if (longitudEnBytes(passwordEnTextoPlano) > BCRYPT_MAX_PASSWORD_BYTES) {
    return false;
  }

  return compare(passwordEnTextoPlano, hashAlmacenado);
}
