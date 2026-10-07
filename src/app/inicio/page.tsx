import { redirect } from "next/navigation";
import { CalendarClock, ShieldCheck } from "lucide-react";

import { BotonCerrarSesion } from "@/app/inicio/boton-cerrar-sesion";
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { getSession } from "@/lib/auth/session";

/**
 * CitaSegura - Pantalla privada de inicio (CITA-6).
 *
 * Primera ruta PROTEGIDA de la aplicacion, y la plantilla de como se
 * protegeran las de citas en el Sprint 2.
 *
 * ES UN SERVER COMPONENT, y eso es el control, no una preferencia de
 * arquitectura. La pregunta "quien eres" se resuelve en el servidor,
 * contra la tabla sessions, ANTES de generar una sola linea de HTML.
 *
 * La alternativa que NO se ha usado: pintar la pagina y comprobar la
 * sesion desde el cliente con un useEffect que llame a /api/auth/me y
 * redirija si responde 401. Eso no es un control de acceso, es una
 * sugerencia. El HTML con los datos ya habria salido del servidor y
 * viajado al navegador, donde cualquiera lo lee con las herramientas
 * de desarrollador o con curl, aunque el useEffect lo borre un
 * instante despues. Un control que se puede desactivar quitando el
 * JavaScript no es un control.
 *
 * Los datos que se muestran salen de getSession(), es decir de la
 * consulta SQL que une sessions con users. NO salen de la cookie: la
 * cookie solo contiene un token opaco y aleatorio, no un nombre ni un
 * correo, precisamente para que el cliente no pueda afirmar quien es.
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
    // token era falso": las tres cosas son lo mismo para quien no esta
    // autenticado, y responder distinto seria un oraculo.
    redirect("/login");
  }

  const { user } = sesion;

  return (
    <main className="flex flex-1 items-center justify-center bg-background p-6">
      <Card className="w-full max-w-md">
        <CardHeader>
          <div className="mb-4 flex items-center gap-2 text-sm font-medium text-muted-foreground">
            <ShieldCheck aria-hidden="true" className="size-4" />
            CitaSegura
          </div>

          <CardTitle className="text-2xl font-semibold tracking-tight">
            Hola, {user.name}
          </CardTitle>

          {/* El correo debajo del saludo tiene una funcion, no es
              decoracion: deja ver CON QUE CUENTA se esta dentro. En un
              equipo compartido es la diferencia entre agendar una cita
              a tu nombre y agendarla con la sesion que otro dejo
              abierta. */}
          <CardDescription>{user.email}</CardDescription>
        </CardHeader>

        <CardContent>
          <div className="flex gap-3 rounded-lg bg-muted/60 p-4 text-sm">
            <CalendarClock
              aria-hidden="true"
              className="mt-0.5 size-4 shrink-0 text-muted-foreground"
            />
            <p className="text-muted-foreground">
              La gestion de citas llega en el{" "}
              <span className="font-medium text-foreground">Sprint 2</span>:
              agendar, consultar y cancelar, con el control de acceso por
              objeto que impide ver las citas de otra persona.
            </p>
          </div>
        </CardContent>

        <CardFooter>
          <BotonCerrarSesion />
        </CardFooter>
      </Card>
    </main>
  );
}
