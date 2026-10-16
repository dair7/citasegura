"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { LogOut } from "lucide-react";

import { Button } from "@/components/ui/button";

/**
 * CitaSegura - Boton de cerrar sesion (CITA-6).
 *
 * Corre en el navegador, como el panel de citas de CITA-11
 * (panel-citas.tsx, formulario-cita.tsx, item-cita.tsx): son las piezas
 * de /inicio que necesitan interactividad. La pagina en si NO lo es.
 * Si fuera un Client Component, la comprobacion de la sesion habria
 * tenido que hacerse desde el cliente, que es exactamente lo que no se
 * quiere. Asi que se parte: la pagina es un Server Component que decide
 * quien entra antes de enviar nada, y al navegador solo llegan los
 * componentes interactivos, que piden sus datos a una API que vuelve a
 * exigir la sesion.
 */
export function BotonCerrarSesion() {
  const router = useRouter();

  const [cerrando, setCerrando] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function cerrarSesion() {
    setCerrando(true);
    setError(null);

    try {
      // POST y no GET, y no es un detalle de estilo: el endpoint solo
      // responde a POST porque con GET bastaria un <img src=...> en
      // cualquier pagina para desconectar a quien la visitara (CSRF).
      // La interfaz tiene que usar el metodo que el control espera.
      const respuesta = await fetch("/api/auth/logout", { method: "POST" });

      if (!respuesta.ok) {
        throw new Error("el servidor no confirmo el cierre de sesion");
      }

      // El orden importa. La sesion ya esta muerta en el SERVIDOR: el
      // endpoint borro la fila de sessions, no solo la cookie. Aqui
      // solo queda sacar al usuario de la pantalla privada.
      router.replace("/login");

      // refresh() descarta la copia en memoria del cliente de las
      // pantallas ya renderizadas. Sin esto, volver atras podria
      // mostrar el contenido antiguo de /inicio durante un instante,
      // leido de la cache del navegador y no del servidor. No es un
      // agujero (la sesion ya no vale para pedir nada), pero es
      // confuso: parece que la sesion sigue abierta.
      router.refresh();
    } catch {
      // Si el cierre no se confirmo, se dice. Lo peligroso seria lo
      // contrario: dar por cerrada una sesion que sigue viva en el
      // servidor, y que el usuario se vaya del equipo creyendolo.
      setError("No se pudo cerrar la sesion. Intentalo de nuevo.");
      setCerrando(false);
    }
  }

  return (
    <div className="w-full space-y-2">
      <Button
        type="button"
        variant="outline"
        size="lg"
        className="h-10 w-full"
        disabled={cerrando}
        onClick={cerrarSesion}
      >
        <LogOut aria-hidden="true" />
        {cerrando ? "Cerrando sesion..." : "Cerrar sesion"}
      </Button>

      {error && (
        <p role="alert" className="text-sm text-destructive">
          {error}
        </p>
      )}
    </div>
  );
}
