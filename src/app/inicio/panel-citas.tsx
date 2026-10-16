"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { CalendarPlus, CircleCheck, ListChecks } from "lucide-react";

import { AVISO_ERROR, AVISO_OK } from "@/app/inicio/estilos";
import { FormularioCita } from "@/app/inicio/formulario-cita";
import { ItemCita } from "@/app/inicio/item-cita";
import type { Cita } from "@/app/inicio/tipos";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardAction,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { cn } from "@/lib/utils";

type Aviso = { tipo: "ok" | "error"; texto: string };

type ResultadoCarga =
  { tipo: "ok"; citas: Cita[] } | { tipo: "sin-sesion" } | { tipo: "error" };

/**
 * Pide la lista a la API. No toca el estado del componente: solo
 * devuelve lo que paso, y quien la llama decide que hacer con ello.
 */
async function pedirCitas(): Promise<ResultadoCarga> {
  try {
    // no-store: la lista de citas de una persona no debe servirse
    // nunca desde una cache.
    const respuesta = await fetch("/api/citas", { cache: "no-store" });

    if (respuesta.status === 401) return { tipo: "sin-sesion" };
    if (!respuesta.ok) return { tipo: "error" };

    const cuerpo: { citas: Cita[] } = await respuesta.json();
    return { tipo: "ok", citas: cuerpo.citas };
  } catch {
    return { tipo: "error" };
  }
}

/**
 * Las dos pestañas del panel.
 *
 * SON ESTADO DEL CLIENTE, NO RUTAS. "Agendar" no es /inicio/agendar ni
 * /citas/nueva: es la misma pagina mostrando otra parte. Es la misma
 * razon por la que no existe GET /api/citas/[id]. Cada ruta nueva es
 * otro sitio donde hay que acordarse de comprobar la sesion, y hoy no
 * hay denegacion por defecto: cada ruta protegida llama a getSession()
 * por su cuenta (limitacion 7 de db/EVIDENCIAS-FASE2.md). Una ruta mas
 * es una oportunidad mas de olvidarlo. Con pestañas en el cliente, la
 * unica comprobacion de sesion de todo el panel sigue siendo la de
 * page.tsx.
 *
 * Contrapartida asumida: la pestaña no queda en la URL, asi que
 * recargar la pagina vuelve siempre a "Mis citas".
 */
const PESTANAS = [
  { id: "mis-citas", titulo: "Mis citas", icono: ListChecks },
  { id: "agendar", titulo: "Agendar", icono: CalendarPlus },
] as const;

type Pestana = (typeof PESTANAS)[number]["id"];

/**
 * Tarjeta clara de shadcn (la misma Card que usaba el /inicio de
 * CITA-6): blanca, con mas aire por dentro y una sombra que la levanta
 * sobre la superficie neutral-100 que la contiene. En movil el relleno
 * baja para no estrechar demasiado los campos.
 */
const TARJETA =
  "shadow-md [--card-spacing:--spacing(5)] sm:[--card-spacing:--spacing(8)]";

/**
 * CitaSegura - Pestañas, lista de citas y formulario de agendar
 * (CITA-11).
 *
 * Client Component porque todo lo que hace es interactivo. La pagina
 * que lo contiene ya comprobo la sesion en el servidor; aun asi, cada
 * peticion de este panel vuelve a pasar por la API, que exige la sesion
 * otra vez y filtra por dueño en SQL. Si la sesion caduca con el panel
 * abierto, la API responde 401 y el panel lleva al usuario a /login en
 * lugar de quedarse mostrando datos que ya no deberia ver.
 *
 * LA LISTA SALE SIEMPRE DE LA API. Despues de agendar o cancelar no se
 * edita la lista a mano en el navegador: se vuelve a pedir. Asi lo que
 * se ve es lo que hay en la base, y no una suposicion del cliente sobre
 * como deberia haber quedado.
 */
export function PanelCitas() {
  const router = useRouter();

  const [pestana, setPestana] = useState<Pestana>("mis-citas");
  // null = todavia no ha llegado la primera respuesta.
  const [citas, setCitas] = useState<Cita[] | null>(null);
  const [errorCarga, setErrorCarga] = useState<string | null>(null);
  const [aviso, setAviso] = useState<Aviso | null>(null);
  const botonesPestana = useRef<Record<Pestana, HTMLButtonElement | null>>({
    "mis-citas": null,
    agendar: null,
  });

  const aplicarCarga = useCallback(
    (resultado: ResultadoCarga) => {
      if (resultado.tipo === "sin-sesion") {
        router.replace("/login");
      } else if (resultado.tipo === "ok") {
        setCitas(resultado.citas);
        setErrorCarga(null);
      } else {
        setErrorCarga("No se pudieron cargar las citas. Intentalo de nuevo.");
      }
    },
    [router],
  );

  async function cargarCitas() {
    aplicarCarga(await pedirCitas());
  }

  // Primera carga al montar el panel. 'activo' descarta la respuesta si
  // el componente se desmonta antes de que llegue.
  useEffect(() => {
    let activo = true;
    pedirCitas().then((resultado) => {
      if (activo) aplicarCarga(resultado);
    });
    return () => {
      activo = false;
    };
  }, [aplicarCarga]);

  function cambiarPestana(nueva: Pestana, enfocar = false) {
    setPestana(nueva);
    if (enfocar) botonesPestana.current[nueva]?.focus();
  }

  // Teclado del patron de pestañas de WAI-ARIA: las flechas pasan de
  // una pestaña a otra, Inicio y Fin van a la primera y a la ultima.
  function alPulsarTecla(evento: React.KeyboardEvent) {
    const indice = PESTANAS.findIndex((p) => p.id === pestana);
    const ultima = PESTANAS.length - 1;
    const destino = {
      ArrowRight: indice === ultima ? 0 : indice + 1,
      ArrowLeft: indice === 0 ? ultima : indice - 1,
      Home: 0,
      End: ultima,
    }[evento.key];

    if (destino !== undefined) {
      evento.preventDefault();
      cambiarPestana(PESTANAS[destino].id, true);
    }
  }

  async function cancelarCita(id: string) {
    setAviso(null);

    try {
      // POST sin cuerpo a una accion con nombre propio: el endpoint
      // solo sabe cancelar, no hay nada mas que se le pueda pedir.
      const respuesta = await fetch(
        `/api/citas/${encodeURIComponent(id)}/cancelar`,
        { method: "POST" },
      );

      if (respuesta.status === 401) {
        router.replace("/login");
        return;
      }

      if (respuesta.ok) {
        setAviso({ tipo: "ok", texto: "Cita cancelada." });
      } else if (respuesta.status === 409) {
        // La interfaz no ofrece cancelar una cita cancelada, asi que
        // esto solo ocurre si la lista estaba desfasada (por ejemplo,
        // se cancelo desde otra pestaña del navegador). Se dice y se
        // refresca.
        setAviso({ tipo: "error", texto: "La cita ya estaba cancelada." });
      } else {
        // 404 u otro fallo: el mismo mensaje generico. El 404 es el que
        // la API da a una cita inexistente, ajena o con id mal formado
        // (CITA-13), y el panel no intenta distinguirlos.
        setAviso({
          tipo: "error",
          texto: "No se pudo cancelar la cita. Intentalo de nuevo.",
        });
      }
    } catch {
      setAviso({
        tipo: "error",
        texto: "No se pudo conectar con el servidor. Intentalo de nuevo.",
      });
    }

    await cargarCitas();
  }

  // Tras agendar se vuelve a "Mis citas", con la lista ya recargada y la
  // cita nueva en ella: es la confirmacion mas clara de que se guardo.
  async function alAgendar() {
    await cargarCitas();
    setAviso({ tipo: "ok", texto: "Cita agendada." });
    setPestana("mis-citas");
  }

  return (
    // LA SUPERFICIE CONTENEDORA. Envuelve el titulo, las pestañas y la
    // tarjeta activa, que va apilada encima. La jerarquia se lee por el
    // tono: pagina neutral-50, superficie neutral-100 y tarjeta blanca
    // con sombra, que es la que resalta.
    // gap y no space-y: el panel inactivo esta oculto con 'hidden', y
    // space-y le seguiria dando margen a su hermano visible, que dejaria
    // un hueco bajo la tarjeta. gap no cuenta los elementos ocultos.
    <div className="flex flex-col gap-6 rounded-2xl border border-neutral-200 bg-neutral-100 p-4 sm:gap-8 sm:p-8 lg:p-10">
      {/* Titulo a la izquierda y pestañas a la derecha, en la misma
          fila desde sm; en movil, el titulo arriba y las pestañas
          debajo, a todo el ancho. */}
      <div className="flex flex-col gap-6 sm:flex-row sm:items-end sm:justify-between">
        <div className="space-y-2">
          <h1 className="text-2xl font-semibold tracking-tight text-neutral-900">
            Mis citas
          </h1>
          <p className="text-sm text-neutral-600">
            Consulta, agenda y cancela tus citas. Solo tu ves esta lista.
          </p>
        </div>

        <div
          role="tablist"
          aria-label="Secciones del panel"
          className="flex w-full shrink-0 gap-1 rounded-xl border border-neutral-200 bg-white p-1 shadow-sm sm:inline-flex sm:w-auto"
          onKeyDown={alPulsarTecla}
        >
          {PESTANAS.map(({ id, titulo, icono: Icono }) => {
            const activa = pestana === id;
            return (
              <Button
                key={id}
                ref={(boton) => {
                  botonesPestana.current[id] = boton;
                }}
                type="button"
                role="tab"
                id={`pestana-${id}`}
                aria-selected={activa}
                aria-controls={`panel-${id}`}
                // Solo la pestaña activa entra en el orden de
                // tabulacion; entre pestañas se pasa con las flechas.
                tabIndex={activa ? 0 : -1}
                variant="ghost"
                className={cn(
                  "h-9 flex-1 px-4 transition-colors duration-200 sm:flex-none",
                  activa
                    ? "bg-neutral-900 font-semibold text-neutral-50 hover:bg-neutral-800 hover:text-neutral-50"
                    : "text-neutral-700 hover:bg-neutral-100 hover:text-neutral-900",
                )}
                onClick={() => cambiarPestana(id)}
              >
                <Icono aria-hidden="true" />
                {titulo}
              </Button>
            );
          })}
        </div>
      </div>

      {/* Los dos paneles estan siempre montados y el inactivo solo se
          oculta (hidden): asi lo que el usuario haya escrito en el
          formulario no se pierde si se va a mirar su lista y vuelve. */}
      <div
        role="tabpanel"
        id="panel-mis-citas"
        aria-labelledby="pestana-mis-citas"
        hidden={pestana !== "mis-citas"}
      >
        <Card className={TARJETA}>
          <CardHeader>
            <CardTitle className="text-lg font-semibold tracking-tight text-neutral-900">
              Tus citas
            </CardTitle>
            <CardDescription className="text-neutral-600">
              Ordenadas por fecha. Despliega una para ver su detalle.
            </CardDescription>
            {citas && citas.length > 0 && (
              <CardAction className="text-sm text-neutral-600">
                {citas.length} {citas.length === 1 ? "cita" : "citas"}
              </CardAction>
            )}
          </CardHeader>

          <CardContent className="space-y-4">
            {aviso && (
              <p
                role={aviso.tipo === "error" ? "alert" : "status"}
                className={cn(
                  aviso.tipo === "error" ? AVISO_ERROR : AVISO_OK,
                  "flex gap-2",
                )}
              >
                {aviso.tipo === "ok" && (
                  <CircleCheck
                    aria-hidden="true"
                    className="mt-0.5 size-4 shrink-0 text-sky-700"
                  />
                )}
                {aviso.texto}
              </p>
            )}

            {errorCarga && (
              <p role="alert" className={AVISO_ERROR}>
                {errorCarga}
              </p>
            )}

            {citas === null && !errorCarga && (
              <p role="status" className="text-sm text-neutral-600">
                Cargando tus citas...
              </p>
            )}

            {citas?.length === 0 && (
              <div className="rounded-xl border border-dashed border-neutral-300 px-6 py-10 text-center">
                <p className="text-sm font-medium text-neutral-900">
                  Todavia no tienes citas
                </p>
                <p className="mt-1 text-sm text-neutral-600">
                  Agenda la primera desde la pestaña Agendar.
                </p>
              </div>
            )}

            {citas && citas.length > 0 && (
              <ul className="space-y-3">
                {citas.map((cita) => (
                  <ItemCita
                    key={cita.id}
                    cita={cita}
                    onCancelar={cancelarCita}
                  />
                ))}
              </ul>
            )}
          </CardContent>
        </Card>
      </div>

      <div
        role="tabpanel"
        id="panel-agendar"
        aria-labelledby="pestana-agendar"
        hidden={pestana !== "agendar"}
      >
        <Card className={TARJETA}>
          <CardHeader>
            <CardTitle className="text-lg font-semibold tracking-tight text-neutral-900">
              Agendar una cita
            </CardTitle>
            <CardDescription className="text-neutral-600">
              Elige el dia, la hora y cuentanos el motivo.
            </CardDescription>
          </CardHeader>
          <CardContent>
            <FormularioCita onAgendada={alAgendar} />
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
