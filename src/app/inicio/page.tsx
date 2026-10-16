import { redirect } from "next/navigation";

import { BotonCerrarSesion } from "@/app/inicio/boton-cerrar-sesion";
import { PanelCitas } from "@/app/inicio/panel-citas";
import { Logotipo } from "@/components/identidad/marca";
import { getSession } from "@/lib/auth/session";

/**
 * Margenes laterales de las pantallas de autenticacion. Los usan la
 * cabecera, que va de borde a borde, y el cuerpo.
 */
const MARGENES = "px-6 sm:px-10 lg:px-16";

/**
 * Columna del contenido: crece con la ventana hasta 64rem y ahi se
 * para, para que las lineas no se hagan kilometricas en un monitor
 * ancho. min(100%, ...) como en las pantallas de autenticacion: nunca
 * pide mas ancho del que hay, asi que no provoca scroll horizontal con
 * ningun zoom.
 */
const COLUMNA = "mx-auto w-[min(100%,64rem)]";

/**
 * CitaSegura - Panel de citas (CITA-11), en la ruta protegida /inicio.
 *
 * Sustituye el contenido provisional de CITA-6, pero conserva lo que
 * hacia de /inicio una ruta protegida: ES UN SERVER COMPONENT, y eso
 * es el control, no una preferencia de arquitectura. La pregunta
 * "quien eres" se resuelve en el servidor, contra la tabla sessions,
 * ANTES de generar una sola linea de HTML. Sin sesion, redirect() corta
 * el renderizado y el navegador no recibe nada del panel.
 *
 * La alternativa que NO se ha usado: pintar la pagina y comprobar la
 * sesion desde el cliente con un useEffect que redirija si la API
 * responde 401. Eso no es un control de acceso, es una sugerencia: el
 * HTML ya habria salido del servidor. Un control que se desactiva
 * quitando el JavaScript no es un control.
 *
 * REPARTO SERVIDOR / CLIENTE:
 *   - Aqui, en el servidor: la sesion, la cabecera con la marca y los
 *     datos de la cuenta.
 *   - En el cliente (PanelCitas): las pestañas, la lista y el
 *     formulario, que necesitan interactividad. Piden sus datos a la API
 *     de citas (CITA-12), que vuelve a exigir la sesion y filtra por
 *     dueño en SQL. El panel no tiene una via propia hacia la base: el
 *     filtro por dueño vive en un solo sitio.
 *
 * ASPECTO: todo en el lado CLARO de /login y /registro, con el mismo
 * logotipo (components/identidad/marca.tsx). La cabecera va de borde a
 * borde; el contenido, en su columna. Sin marca de agua: en /login y
 * /registro funciona porque hay un panel dedicado a la marca y vacio.
 * El panel de citas es una herramienta llena de contenido, y hacerle
 * sitio al escudo obligaria a dejar huecos.
 */

export default async function InicioPage() {
  // La unica fuente de verdad: cookie presente, fila existente en
  // sessions y expires_at > now() comprobado con el reloj del servidor
  // de base de datos.
  const sesion = await getSession();

  if (!sesion) {
    // redirect() interrumpe el renderizado lanzando NEXT_REDIRECT, asi
    // que nada de lo que hay debajo llega a ejecutarse ni a enviarse.
    // No se distingue "no habia cookie" de "la sesion caduco" de "el
    // token era falso": para quien no esta autenticado son lo mismo, y
    // responder distinto seria un oraculo.
    redirect("/login");
  }

  const { user } = sesion;

  return (
    // overflow-x-hidden en la raiz de la pantalla, como en las
    // pantallas de autenticacion: el scroll horizontal no debe
    // aparecer a ningun nivel de zoom.
    <div className="flex min-h-dvh flex-1 flex-col overflow-x-hidden bg-neutral-50 text-neutral-900">
      {/* De borde a borde: el logotipo pegado a la izquierda y la
          cuenta a la derecha, con el margen lateral normal. Por debajo
          de md no caben los dos en una fila sin apretarse, y la cuenta
          baja debajo del logotipo. */}
      <header
        className={`flex flex-col gap-5 border-b border-neutral-200 py-6 md:flex-row md:items-center md:justify-between ${MARGENES}`}
      >
        <Logotipo />

        {/* Cuenta y salida en una sola fila. min-w-0 deja que el
            correo se recorte con puntos suspensivos en vez de empujar
            el boton fuera de la pantalla. */}
        <div className="flex min-w-0 items-center gap-4">
          {/* El correo junto al nombre tiene una funcion: deja ver
              CON QUE CUENTA se esta dentro. En un equipo compartido es
              la diferencia entre agendar una cita a tu nombre y
              agendarla con la sesion que otro dejo abierta.
              React escapa ambos textos al generar el HTML (CITA-14,
              evidencia 7.4). */}
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
          <PanelCitas />
        </div>
      </main>
    </div>
  );
}
