import { PanelAdmin } from "@/app/admin/panel-admin";
import { cargarVistaAdministrador } from "@/app/admin/datos";
import { BotonCerrarSesion } from "@/app/inicio/boton-cerrar-sesion";
import { Logotipo } from "@/components/identidad/marca";

/** Los mismos margenes y la misma columna que /inicio. */
const MARGENES = "px-6 sm:px-10 lg:px-16";
const COLUMNA = "mx-auto w-[min(100%,72rem)]";

/**
 * CitaSegura - Vista de administrador (CITA-19), en la ruta /admin.
 *
 * Mismo patron que /inicio: ES UN SERVER COMPONENT, y la pregunta
 * "quien eres" se resuelve en el servidor antes de generar una sola
 * linea de HTML. La diferencia es la respuesta a quien no debe entrar:
 * /inicio redirige a /login, porque que exista un panel para usuarios
 * no es ningun secreto; aqui se responde 404, porque que exista una
 * vista de administrador si lo es (src/lib/auth/administrador.ts).
 *
 * UNA SOLA RUTA. Citas y usuarios son dos pestañas en el cliente, no
 * /admin/citas y /admin/usuarios: cada ruta nueva seria otro sitio
 * donde acordarse de comprobar el rol (el mismo criterio de las
 * pestañas de /inicio en CITA-11).
 *
 * LOS DATOS LLEGAN YA EN EL HTML, no por una API. La alternativa
 * (pestañas que piden GET /api/admin/...) obligaria a repetir la
 * comprobacion de rol en cada endpoint, y añadiria rutas de
 * administrador bajo /api. Asi solo hay un control y ninguna ruta mas.
 * La contrapartida: lo que la pagina pasa a PanelAdmin viaja
 * serializado en el HTML, por eso las consultas eligen columna a
 * columna lo que sale de la base (src/app/admin/datos.ts).
 *
 * SOLO CONSULTA. Ni aqui ni en el panel hay ningun boton, formulario o
 * fetch que escriba. El rol de administrador tampoco se puede cambiar
 * desde la aplicacion: se asigna directamente en la base, porque
 * citasegura_app no tiene permiso para escribir la columna role, ni al
 * crear una cuenta (INSERT, evidencias 6.6 y 6.7) ni sobre una
 * existente (UPDATE, evidencia 1.4).
 */
export default async function AdminPage() {
  // Comprobacion de rol y consultas, en este orden y en un solo paso.
  // Sin rol de administrador, notFound() corta aqui.
  const { sesion, citas, usuarios } = await cargarVistaAdministrador();
  const { user } = sesion;

  return (
    <div className="flex min-h-dvh flex-1 flex-col overflow-x-hidden bg-neutral-50 text-neutral-900">
      <header
        className={`flex flex-col gap-5 border-b border-neutral-200 py-6 md:flex-row md:items-center md:justify-between ${MARGENES}`}
      >
        <Logotipo />

        <div className="flex min-w-0 items-center gap-4">
          <div className="min-w-0 flex-1 md:text-right">
            <p className="truncate text-sm font-medium text-neutral-900">
              {user.name}
            </p>
            <p className="truncate text-sm text-neutral-600">{user.email}</p>
          </div>
          <div className="w-44 shrink-0">
            <BotonCerrarSesion />
          </div>
        </div>
      </header>

      <main className={`flex-1 py-8 sm:py-12 lg:py-16 ${MARGENES}`}>
        <div className={COLUMNA}>
          <PanelAdmin citas={citas} usuarios={usuarios} />
        </div>
      </main>
    </div>
  );
}
