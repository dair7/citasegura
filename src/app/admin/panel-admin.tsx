"use client";

import { useRef, useState } from "react";
import { CalendarDays, Users } from "lucide-react";

import type { CitaAdmin, UsuarioAdmin } from "@/app/admin/tipos";
import { ESTADOS } from "@/app/inicio/item-cita";
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

// ZONA HORARIA FIJA, a diferencia de /inicio. Aqui las fechas se pintan
// tambien en el servidor (llegan en las props, no por fetch), y si cada
// lado usara su propia zona el HTML del servidor y el del navegador no
// coincidirian. Ademas, quien supervisa necesita una referencia unica,
// no la de su equipo.
const FECHA = new Intl.DateTimeFormat("es-CO", {
  dateStyle: "medium",
  timeStyle: "short",
  timeZone: "America/Bogota",
});
const SOLO_FECHA = new Intl.DateTimeFormat("es-CO", {
  dateStyle: "medium",
  timeZone: "America/Bogota",
});

/**
 * Las dos pestañas. Como en /inicio, SON ESTADO DEL CLIENTE, NO RUTAS:
 * la comprobacion de rol de /admin se hace una vez en page.tsx y cubre
 * a las dos.
 */
const PESTANAS = [
  { id: "citas", titulo: "Citas", icono: CalendarDays },
  { id: "usuarios", titulo: "Usuarios", icono: Users },
] as const;

type Pestana = (typeof PESTANAS)[number]["id"];

const TARJETA =
  "shadow-md [--card-spacing:--spacing(5)] sm:[--card-spacing:--spacing(8)]";

/** Cabeceras de tabla y celdas, con el contraste de /inicio. */
const TH = "px-3 py-2 text-left font-medium whitespace-nowrap text-neutral-600";
const TD = "px-3 py-3 align-top text-neutral-900";

/**
 * CitaSegura - Pestañas de la vista de administrador (CITA-19).
 *
 * Client Component solo por las pestañas. NO PIDE NADA AL SERVIDOR: no
 * hay ningun fetch, ni de lectura ni de escritura. Los datos le llegan
 * ya filtrados por columnas desde page.tsx, y no hay ningun boton que
 * actue sobre una cita o una cuenta.
 *
 * Los textos (nombres, correos, motivos) los escribieron los usuarios y
 * se pintan con {...}, que React escapa siempre, igual que el motivo en
 * el panel de citas (CITA-14, evidencia 7.4). Un motivo malicioso
 * apunta ahora a una pantalla mas valiosa, la del administrador, y se
 * ve como texto igual que en /inicio.
 */
export function PanelAdmin({
  citas,
  usuarios,
}: {
  citas: CitaAdmin[];
  usuarios: UsuarioAdmin[];
}) {
  const [pestana, setPestana] = useState<Pestana>("citas");
  const botonesPestana = useRef<Record<Pestana, HTMLButtonElement | null>>({
    citas: null,
    usuarios: null,
  });

  function cambiarPestana(nueva: Pestana, enfocar = false) {
    setPestana(nueva);
    if (enfocar) botonesPestana.current[nueva]?.focus();
  }

  // El mismo teclado de pestañas de WAI-ARIA que en /inicio.
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

  return (
    <div className="flex flex-col gap-6 rounded-2xl border border-neutral-200 bg-neutral-100 p-4 sm:gap-8 sm:p-8 lg:p-10">
      <div className="flex flex-col gap-6 sm:flex-row sm:items-end sm:justify-between">
        <div className="space-y-2">
          <h1 className="text-2xl font-semibold tracking-tight text-neutral-900">
            Administracion
          </h1>
          <p className="text-sm text-neutral-600">
            Consulta de todas las citas y de las cuentas registradas. Esta
            vista es solo de lectura.
          </p>
        </div>

        <div
          role="tablist"
          aria-label="Secciones de administracion"
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

      {/* Los dos paneles van siempre en el HTML y el inactivo solo se
          oculta, como en /inicio. */}
      <div
        role="tabpanel"
        id="panel-citas"
        aria-labelledby="pestana-citas"
        hidden={pestana !== "citas"}
      >
        <Card className={TARJETA}>
          <CardHeader>
            <CardTitle className="text-lg font-semibold tracking-tight text-neutral-900">
              Todas las citas
            </CardTitle>
            <CardDescription className="text-neutral-600">
              De todas las cuentas, ordenadas por fecha. Hora de Colombia.
            </CardDescription>
            <CardAction className="text-sm text-neutral-600">
              {citas.length} {citas.length === 1 ? "cita" : "citas"}
            </CardAction>
          </CardHeader>
          <CardContent>
            {citas.length === 0 ? (
              <p className="text-sm text-neutral-600">No hay citas.</p>
            ) : (
              // La tabla se desplaza por dentro en pantallas estrechas,
              // sin provocar scroll horizontal en la pagina.
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead className="border-b border-neutral-200">
                    <tr>
                      <th scope="col" className={TH}>Fecha y hora</th>
                      <th scope="col" className={TH}>Titular</th>
                      <th scope="col" className={TH}>Motivo</th>
                      <th scope="col" className={TH}>Estado</th>
                      <th scope="col" className={TH}>Agendada el</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-neutral-200">
                    {/* Sin id que usar como clave: la vista no los
                        recibe (tipos.ts). La lista no se reordena ni
                        cambia en el cliente, asi que el indice basta. */}
                    {citas.map((cita, indice) => (
                      <tr key={indice}>
                        <td className={cn(TD, "whitespace-nowrap")}>
                          {FECHA.format(new Date(cita.scheduledAt))}
                        </td>
                        <td className={TD}>
                          <p>{cita.titularNombre}</p>
                          <p className="text-neutral-600">
                            {cita.titularCorreo}
                          </p>
                        </td>
                        <td
                          className={cn(
                            TD,
                            "max-w-xs whitespace-pre-wrap break-words",
                          )}
                        >
                          {cita.reason}
                        </td>
                        <td className={TD}>
                          <span
                            className={cn(
                              "rounded-full border px-2.5 py-0.5 text-xs font-medium whitespace-nowrap",
                              ESTADOS[cita.status].clases,
                            )}
                          >
                            {ESTADOS[cita.status].texto}
                          </span>
                        </td>
                        <td className={cn(TD, "whitespace-nowrap")}>
                          {FECHA.format(new Date(cita.createdAt))}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </CardContent>
        </Card>
      </div>

      <div
        role="tabpanel"
        id="panel-usuarios"
        aria-labelledby="pestana-usuarios"
        hidden={pestana !== "usuarios"}
      >
        <Card className={TARJETA}>
          <CardHeader>
            <CardTitle className="text-lg font-semibold tracking-tight text-neutral-900">
              Usuarios registrados
            </CardTitle>
            <CardDescription className="text-neutral-600">
              Por fecha de registro. El rol solo se cambia en la base de
              datos, no desde la aplicacion.
            </CardDescription>
            <CardAction className="text-sm text-neutral-600">
              {usuarios.length} {usuarios.length === 1 ? "cuenta" : "cuentas"}
            </CardAction>
          </CardHeader>
          <CardContent>
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead className="border-b border-neutral-200">
                  <tr>
                    <th scope="col" className={TH}>Nombre</th>
                    <th scope="col" className={TH}>Correo</th>
                    <th scope="col" className={TH}>Rol</th>
                    <th scope="col" className={TH}>Registro</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-neutral-200">
                  {/* El correo es UNIQUE en la tabla: sirve de clave. */}
                  {usuarios.map((usuario) => (
                    <tr key={usuario.email}>
                      <td className={TD}>{usuario.name}</td>
                      <td className={cn(TD, "break-all")}>{usuario.email}</td>
                      <td className={TD}>
                        {usuario.role === "admin" ? "Administrador" : "Usuario"}
                      </td>
                      <td className={cn(TD, "whitespace-nowrap")}>
                        {SOLO_FECHA.format(new Date(usuario.createdAt))}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
