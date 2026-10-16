import { Lock, ShieldCheck } from "lucide-react";

/**
 * CitaSegura - Identidad visual compartida: logotipo y marca de agua.
 *
 * Extraidos de auth-split-layout.tsx (CITA-6) en CITA-11 para que las
 * tres pantallas -- /login, /registro y el panel de /inicio -- dibujen
 * EXACTAMENTE el mismo logotipo, desde un unico sitio. La marca de agua
 * solo la usan /login y /registro: alli hay un panel dedicado a la
 * marca, y el panel de citas esta lleno de contenido. Que la aplicacion
 * se vea igual en todas partes es parte de la defensa contra el
 * phishing que se explica en auth-split-layout.tsx: una copia mal hecha
 * resulta extraña a quien esta acostumbrado a la original.
 *
 * Solo presentacion: sin estado y sin datos del usuario.
 */

/**
 * El logotipo: escudo en un cuadrado oscuro y el nombre al lado.
 * Pensado para ir sobre un fondo CLARO.
 */
export function Logotipo() {
  return (
    <div className="flex items-center gap-4">
      {/* Icono y titulo escalan juntos: si solo creciera el
          texto, el escudo se quedaria pequeño al lado. */}
      <span className="flex size-12 shrink-0 items-center justify-center rounded-2xl bg-neutral-900 text-neutral-50 sm:size-14">
        <ShieldCheck aria-hidden="true" className="size-6 sm:size-7" />
      </span>
      {/* La marca va en un <span> y no en un <h1>: el encabezado
          principal de cada pagina es su tarea real (el titulo del
          formulario, o "Mis citas" en el panel). Asi el orden de
          encabezados que anuncia un lector de pantalla sigue teniendo
          sentido. */}
      <span className="text-3xl font-semibold tracking-tight sm:text-4xl">
        CitaSegura
      </span>
    </div>
  );
}

/**
 * Las dos marcas de agua del lado claro. Van posicionadas en absoluto:
 * el contenedor tiene que ser 'relative' y 'overflow-hidden', que es lo
 * que recorta la parte que desborda.
 */
export function MarcaDeAgua() {
  return (
    <>
      {/* Marca de agua. Es el mismo escudo del logo, gigante y
          desbordando por la esquina inferior derecha: se ve solo un
          trozo, y el overflow-hidden del contenedor corta el resto.
          strokeWidth bajado a 0.75: los iconos de lucide vienen con
          trazo de 2 sobre un lienzo de 24, asi que a 32rem ese trazo
          se escalaria a unos 40px y el escudo se leeria como un
          dibujo pegado encima. Con el trazo fino se lee como
          textura, que es lo que se busca.
          aria-hidden y pointer-events-none porque es decoracion
          pura: no debe anunciarse a un lector de pantalla ni
          interceptar clics. */}
      <ShieldCheck
        aria-hidden="true"
        strokeWidth={0.75}
        className="pointer-events-none absolute -right-40 -bottom-48 z-0 size-[40rem] text-neutral-900/[0.06]"
      />

      {/* Segunda marca de agua, arriba a la derecha. Mas pequeña y
          mas tenue que el escudo para que no compitan: la de abajo
          manda y esta solo acompaña. */}
      <Lock
        aria-hidden="true"
        strokeWidth={0.75}
        className="pointer-events-none absolute -top-28 -right-24 z-0 size-[24rem] text-neutral-900/[0.035]"
      />
    </>
  );
}
