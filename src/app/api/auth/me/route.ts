import { getSession } from "@/lib/auth/session";

/**
 * CitaSegura - GET /api/auth/me  (SCRUM-6)
 *
 * Ruta PROTEGIDA de prueba: devuelve quien es el usuario de la sesion
 * actual. Sirve para comprobar de extremo a extremo que la cookie
 * funciona, y como plantilla de como se protegera cualquier ruta
 * futura (las citas, el panel de administracion...).
 *
 * Es GET porque solo LEE: no cambia ningun estado, asi que no hay
 * superficie de CSRF que cubrir.
 */

export const runtime = "nodejs";

export async function GET() {
  // Toda la validacion esta en getSession(): cookie presente, fila
  // existente en la base y expires_at > now() comprobado por el reloj
  // del servidor de base de datos.
  const sesion = await getSession();

  if (!sesion) {
    // 401 sin detalles. No se distingue "no habia cookie" de "la
    // cookie era invalida" ni de "la sesion caduco": para quien no
    // esta autenticado, las tres cosas son lo mismo.
    return Response.json({ message: "No autenticado." }, { status: 401 });
  }

  // Se devuelve lo minimo. El id de sesion no sale nunca de aqui: es
  // el equivalente a una credencial.
  return Response.json(
    {
      user: sesion.user,
      expiresAt: sesion.expiresAt,
    },
    { status: 200 },
  );
}
