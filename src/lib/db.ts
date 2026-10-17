import { Pool, type QueryResult, type QueryResultRow } from "pg";

import { env } from "@/lib/env";

/**
 * CitaSegura - Acceso a PostgreSQL.
 *
 * Sin ORM: se usa el driver 'pg' con CONSULTAS PARAMETRIZADAS,
 * para que el control anti-inyeccion SQL quede visible en el codigo
 * (OWASP A03: Injection).
 */

// --------------------------------------------------------------
//  Guarda: este modulo NUNCA debe ejecutarse en el navegador.
// --------------------------------------------------------------
// Si un Client Component importara este archivo por error, la cadena
// de conexion (con usuario y contrasena) podria acabar en el bundle
// que se descarga el navegador. Este chequeo lo hace fallar de forma
// ruidosa en lugar de filtrar credenciales en silencio.
if (typeof window !== "undefined") {
  throw new Error(
    "src/lib/db.ts es codigo de servidor y no puede importarse desde el navegador.",
  );
}

// --------------------------------------------------------------
//  Cadena de conexion
// --------------------------------------------------------------
// Viene de .env.local, validada en src/lib/env.ts (CITA-15): si falta
// o esta mal formada, la aplicacion no llega a arrancar. El nombre NO
// lleva el prefijo NEXT_PUBLIC_, asi que Next.js la mantiene solo en el
// servidor y jamas la incrusta en el JavaScript del cliente.
const connectionString = env.DATABASE_URL;

// --------------------------------------------------------------
//  Pool de conexiones (singleton)
// --------------------------------------------------------------
// En desarrollo Next.js recarga los modulos en caliente en cada
// guardado. Sin este singleton se crearia un Pool nuevo cada vez y
// las conexiones antiguas quedarian abiertas hasta agotar el servidor.
const globalForDb = globalThis as unknown as { citaseguraPool?: Pool };

export const pool: Pool =
  globalForDb.citaseguraPool ??
  new Pool({
    connectionString,
    // Limitar el numero de conexiones tambien es una defensa: evita
    // que una avalancha de peticiones agote los recursos del servidor.
    max: 10,
    idleTimeoutMillis: 30_000,
    connectionTimeoutMillis: 5_000,
  });

if (process.env.NODE_ENV !== "production") {
  globalForDb.citaseguraPool = pool;
}

// --------------------------------------------------------------
//  query() - el unico punto de entrada para hablar con la BD
// --------------------------------------------------------------
/**
 * Ejecuta una consulta parametrizada.
 *
 * El texto SQL y los datos viajan SEPARADOS: PostgreSQL compila
 * primero la consulta y despues recibe los valores, por lo que un
 * valor nunca puede convertirse en codigo SQL ejecutable.
 *
 * CORRECTO (parametrizado):
 *   query("SELECT id, email FROM users WHERE email = $1", [email])
 *
 * INCORRECTO (concatenado - vulnerable a inyeccion SQL):
 *   query(`SELECT id, email FROM users WHERE email = '${email}'`)
 *   // con email = "' OR 1=1 --" devolveria TODOS los usuarios.
 *
 * Los marcadores son $1, $2, $3... numerados desde 1.
 */
export async function query<T extends QueryResultRow = QueryResultRow>(
  text: string,
  params: ReadonlyArray<unknown> = [],
): Promise<QueryResult<T>> {
  return pool.query<T>(text, params as unknown[]);
}
