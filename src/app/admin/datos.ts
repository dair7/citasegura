import "server-only";

import type { CitaAdmin, UsuarioAdmin } from "@/app/admin/tipos";
import { exigirAdministrador } from "@/lib/auth/administrador";
import type { SesionActiva } from "@/lib/auth/session";
import { query } from "@/lib/db";

/**
 * CitaSegura - Datos de la vista de administrador (CITA-19).
 *
 * LA UNICA FORMA DE OBTENER ESTOS DATOS PASA POR LA COMPROBACION DE
 * ROL. Las consultas no se exportan sueltas: solo existe
 * cargarVistaAdministrador(), que empieza llamando a
 * exigirAdministrador(). Asi, si mañana otra pagina quisiera la lista
 * de usuarios, no podria pedirla sin pasar por el mismo control. La
 * comprobacion sigue ocurriendo una sola vez por peticion.
 *
 * SOLO LECTURA. Este modulo no tiene ningun INSERT ni UPDATE, y no hay
 * ninguna ruta de administrador bajo /api. El administrador no puede
 * crear ni cancelar citas en nombre de otros ni modificar cuentas, y
 * la forma de garantizarlo no es comprobar permisos al escribir, sino
 * que no exista el codigo que escribe.
 */

type FilaCita = {
  scheduled_at: Date;
  reason: string;
  status: CitaAdmin["status"];
  created_at: Date;
  titular_nombre: string;
  titular_correo: string;
};

type FilaUsuario = {
  name: string;
  email: string;
  role: string;
  created_at: Date;
};

export async function cargarVistaAdministrador(): Promise<{
  sesion: SesionActiva;
  citas: CitaAdmin[];
  usuarios: UsuarioAdmin[];
}> {
  // Primero el control. Si no pasa, notFound() corta aqui y ninguna de
  // las dos consultas de abajo llega a ejecutarse.
  const sesion = await exigirAdministrador();

  // ----------------------------------------------------------------
  //  LAS COLUMNAS SE NOMBRAN UNA A UNA. Nada de SELECT *.
  // ----------------------------------------------------------------
  // citasegura_app SI tiene permiso de lectura sobre password_hash,
  // failed_attempts y locked_until: el login los necesita. Lo que
  // impide que salgan de la base no es un permiso, es esta lista de
  // columnas (limitacion 9 de db/EVIDENCIAS-FASE2.md). Si se trajeran
  // al servidor "porque no se muestran", bastaria un descuido al
  // construir las props para que viajaran serializados dentro del
  // HTML, que es la via que CITA-15 vigila para los secretos
  // (evidencia 8.3).
  //
  // El arreglo de verdad seria un segundo rol de base de datos, de
  // solo lectura y sin permiso sobre esas columnas, con su propio pool
  // para esta vista. No esta construido.
  const [resultadoCitas, resultadoUsuarios] = await Promise.all([
    // Sin WHERE por dueño: es la unica consulta de la aplicacion que
    // lee las citas de todos, y por eso solo se alcanza desde aqui.
    // Del titular se lee lo que el administrador necesita para saber
    // de quien es la cita, nombre y correo, y nada mas de users.
    query<FilaCita>(
      `SELECT a.scheduled_at,
              a.reason,
              a.status,
              a.created_at,
              u.name  AS titular_nombre,
              u.email AS titular_correo
         FROM appointments a
         JOIN users u ON u.id = a.user_id
        ORDER BY a.scheduled_at`,
    ),
    query<FilaUsuario>(
      `SELECT name, email, role, created_at
         FROM users
        ORDER BY created_at`,
    ),
  ]);

  return {
    sesion,
    citas: resultadoCitas.rows.map((fila) => ({
      scheduledAt: fila.scheduled_at.toISOString(),
      reason: fila.reason,
      status: fila.status,
      createdAt: fila.created_at.toISOString(),
      titularNombre: fila.titular_nombre,
      titularCorreo: fila.titular_correo,
    })),
    usuarios: resultadoUsuarios.rows.map((fila) => ({
      name: fila.name,
      email: fila.email,
      role: fila.role,
      createdAt: fila.created_at.toISOString(),
    })),
  };
}
