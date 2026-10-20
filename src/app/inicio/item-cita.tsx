"use client";

import { useId, useState } from "react";
import { ChevronDown, X } from "lucide-react";

import type { Cita } from "@/app/inicio/tipos";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";

// La fecha se muestra en la zona horaria del navegador, que es la de
// quien la agendo: la API la guarda como instante exacto (TIMESTAMPTZ)
// y la devuelve en UTC.
const FECHA_LARGA = new Intl.DateTimeFormat("es-CO", {
  dateStyle: "full",
  timeStyle: "short",
});
const FECHA_CORTA = new Intl.DateTimeFormat("es-CO", {
  weekday: "short",
  day: "numeric",
  month: "short",
  year: "numeric",
  hour: "numeric",
  minute: "2-digit",
});

// Colores con contraste suficiente sobre blanco: el texto de cada
// etiqueta es el 800 de su tono sobre el 50. Los usa tambien la vista
// de administrador (CITA-19), para que una cita se vea igual en las dos.
export const ESTADOS = {
  programada: {
    texto: "Programada",
    clases: "border-sky-200 bg-sky-50 text-sky-800",
  },
  cancelada: {
    texto: "Cancelada",
    clases: "border-neutral-200 bg-neutral-100 text-neutral-700",
  },
} as const;

/**
 * CitaSegura - Una cita de la lista, con su detalle y su cancelacion
 * (CITA-11).
 *
 * EL DETALLE NO SE PIDE AL SERVIDOR. Se despliega aqui mismo con los
 * datos que ya trajo GET /api/citas, sin ninguna peticion mas. Es una
 * decision de seguridad, no de rendimiento: en CITA-12 se decidio no
 * tener un endpoint que devuelva una cita por su id
 * (GET /api/citas/[id]), y CITA-13 verifico que esa ruta no existe
 * (evidencia 6.1). Un endpoint asi es justo la forma clasica de un
 * IDOR: basta cambiar el id de la URL para intentar leer la cita de
 * otra persona. Como la lista ya contiene todo lo que el detalle
 * muestra, crearlo solo añadiria superficie de ataque y haria falsa
 * esa evidencia.
 *
 * EL MOTIVO SE PINTA COMO TEXTO. Es lo que escribio el usuario, y
 * llega crudo desde la API (CITA-14, evidencia 7.3: escapar le toca a
 * quien pinta). Aqui se pinta con {cita.reason}, que React escapa
 * siempre: un motivo como <script>alert(1)</script> se ve tal cual y
 * no se ejecuta. Ninguna de las vias de React o del DOM para insertar
 * HTML sin escapar se usa aqui, ni en ningun otro archivo de src/: la
 * evidencia 7.3 lo cuenta con grep, y este comentario evita nombrarlas
 * para no contar como un uso.
 */
export function ItemCita({
  cita,
  onCancelar,
}: {
  cita: Cita;
  onCancelar: (id: string) => Promise<void>;
}) {
  const [abierto, setAbierto] = useState(false);
  const [confirmando, setConfirmando] = useState(false);
  const [cancelando, setCancelando] = useState(false);
  const idDetalle = useId();

  const estado = ESTADOS[cita.status];
  const fecha = new Date(cita.scheduledAt);

  // Solo una cita programada se puede cancelar. Una cancelada no
  // ofrece el boton: el servidor la rechazaria con 409, y ofrecer una
  // accion que va a fallar es engañar al usuario.
  const cancelable = cita.status === "programada";

  async function confirmarCancelacion() {
    setCancelando(true);
    await onCancelar(cita.id);
    // Si la cancelacion fue bien, la lista se recarga y esta cita
    // vuelve a pintarse como cancelada, sin boton.
    setCancelando(false);
    setConfirmando(false);
  }

  return (
    <li className="rounded-xl border border-neutral-200 bg-white">
      <div className="flex items-start justify-between gap-4 p-4">
        <div className="min-w-0 space-y-1">
          <p className="text-sm font-medium text-neutral-900 first-letter:uppercase">
            {FECHA_CORTA.format(fecha)}
          </p>
          <p className="truncate text-sm text-neutral-600">{cita.reason}</p>
        </div>
        <span
          className={cn(
            "shrink-0 rounded-full border px-2.5 py-0.5 text-xs font-medium",
            estado.clases,
          )}
        >
          {estado.texto}
        </span>
      </div>

      <div className="flex flex-wrap gap-2 px-4 pb-4">
        <Button
          type="button"
          variant="ghost"
          size="sm"
          className="text-neutral-700 hover:bg-neutral-100 hover:text-neutral-900 aria-expanded:bg-neutral-100 aria-expanded:text-neutral-900"
          aria-expanded={abierto}
          aria-controls={idDetalle}
          onClick={() => setAbierto((visible) => !visible)}
        >
          <ChevronDown
            aria-hidden="true"
            className={cn(
              "transition-transform duration-200",
              abierto && "rotate-180",
            )}
          />
          {abierto ? "Ocultar detalle" : "Ver detalle"}
        </Button>

        {cancelable && !confirmando && (
          <Button
            type="button"
            variant="ghost"
            size="sm"
            className="text-red-700 hover:bg-red-50 hover:text-red-800"
            onClick={() => setConfirmando(true)}
          >
            <X aria-hidden="true" />
            Cancelar cita
          </Button>
        )}
      </div>

      {/* Confirmacion en dos pasos: cancelar no tiene vuelta atras (la
          aplicacion no ofrece ninguna forma de reactivar una cita), asi
          que un clic accidental no debe bastar. */}
      {cancelable && confirmando && (
        <div
          role="group"
          aria-label="Confirmar cancelacion"
          className="mx-4 mb-4 space-y-3 rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-900"
        >
          <p>¿Cancelar esta cita? No se puede deshacer.</p>
          <div className="flex flex-wrap gap-2">
            <Button
              type="button"
              size="sm"
              className="bg-red-700 font-semibold text-white transition-all duration-200 hover:bg-red-800 active:scale-[0.98]"
              disabled={cancelando}
              onClick={confirmarCancelacion}
            >
              {cancelando ? "Cancelando..." : "Si, cancelar"}
            </Button>
            <Button
              type="button"
              variant="outline"
              size="sm"
              className="bg-white text-neutral-800"
              disabled={cancelando}
              onClick={() => setConfirmando(false)}
            >
              No, mantenerla
            </Button>
          </div>
        </div>
      )}

      {abierto && (
        <dl
          id={idDetalle}
          className="grid gap-x-6 gap-y-3 border-t border-neutral-200 px-4 py-4 text-sm sm:grid-cols-[9rem_minmax(0,1fr)]"
        >
          <dt className="text-neutral-600">Fecha y hora</dt>
          <dd className="text-neutral-900 first-letter:uppercase">
            {FECHA_LARGA.format(fecha)}
          </dd>

          <dt className="text-neutral-600">Estado</dt>
          <dd className="text-neutral-900">{estado.texto}</dd>

          <dt className="text-neutral-600">Motivo</dt>
          {/* whitespace-pre-wrap respeta los saltos de linea que
              escribio el usuario; break-words evita que una palabra
              larga sin espacios rompa el ancho de la tarjeta. */}
          <dd className="whitespace-pre-wrap break-words text-neutral-900">
            {cita.reason}
          </dd>

          <dt className="text-neutral-600">Agendada el</dt>
          <dd className="text-neutral-900 first-letter:uppercase">
            {FECHA_LARGA.format(new Date(cita.createdAt))}
          </dd>
        </dl>
      )}
    </li>
  );
}
