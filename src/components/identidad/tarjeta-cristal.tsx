/**
 * CitaSegura - La tarjeta de cristal: una lamina de vidrio flotando
 * sobre el FondoOscuro.
 *
 * Es la tarjeta del formulario de /login y /registro. Extraida de
 * auth-split-layout.tsx (CITA-6) en CITA-11, cuando el panel de /inicio
 * iba a usarla tambien; el panel acabo en claro y usa la Card de
 * shadcn, porque el vidrio sobre blanco no se ve. Quien la usa decide
 * su ancho, su margen y su relleno con className.
 *
 * relative para quedar por encima de la rejilla y del resplandor, y
 * overflow-hidden para que el brillo del canto y el reflejo interno
 * respeten las esquinas redondeadas.
 *
 * IMPORTANTE para que el backdrop-blur funcione: ningun antepasado de
 * esta tarjeta puede llevar filter, opacity, transform ni mask.
 * Cualquiera de esas propiedades crea un 'backdrop root' y el navegador
 * deja de ver mas alla de el, asi que la tarjeta difuminaria la nada en
 * lugar de la rejilla. Por eso la mascara radial va en la rejilla, que
 * es su HERMANA, y no en el <main> que las contiene.
 *
 * El borde se simula en dos capas, porque CSS no admite un degradado en
 * border-color: el border-white/10 marca el contorno completo y el ring
 * interior al 5% le añade un segundo filo por dentro, que es lo que da
 * el grosor de una lamina en lugar de una linea pintada.
 */
export function TarjetaCristal({
  className,
  children,
}: {
  className: string;
  children: React.ReactNode;
}) {
  return (
    <div
      className={`relative overflow-hidden rounded-2xl border border-white/10 bg-white/[0.07] shadow-2xl shadow-black/60 ring-1 ring-white/5 ring-inset backdrop-blur-xl ${className}`}
    >
      {/* Reflejo interno: la luz que entra por arriba se apaga
          hacia la mitad de la tarjeta. */}
      <div
        aria-hidden="true"
        className="pointer-events-none absolute inset-x-0 top-0 h-1/2 bg-gradient-to-b from-white/[0.08] to-transparent"
      />

      {/* El canto iluminado: 1px que se enciende en el centro y se
          apaga hacia los extremos. Es el detalle que hace leer el
          borde como el grosor del vidrio y no como un marco. */}
      <div
        aria-hidden="true"
        className="pointer-events-none absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-white/25 to-transparent"
      />

      {/* El contenido, por encima de las dos capas decorativas. */}
      <div className="relative">{children}</div>
    </div>
  );
}
