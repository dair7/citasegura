/**
 * CitaSegura - Fondo oscuro del lado del formulario en /login y
 * /registro.
 *
 * Extraido de auth-split-layout.tsx (CITA-6) en CITA-11, cuando el
 * panel de /inicio iba a usarlo tambien. El panel acabo en claro y no
 * lo usa; se mantiene aparte junto al resto de la identidad visual. Es
 * el <main> de la pantalla: quien lo usa solo decide su disposicion y
 * sus margenes con className.
 *
 * overflow-hidden recorta la rejilla y el resplandor, que desbordan por
 * los cuatro lados. No recorta nunca el contenido: el <main> mide lo que
 * mide lo que lleva dentro, y lo que no cabe en la ventana se alcanza
 * con el scroll vertical normal de la pagina.
 */
export function FondoOscuro({
  className,
  children,
}: {
  className: string;
  children: React.ReactNode;
}) {
  return (
    <main
      className={`relative overflow-hidden bg-gradient-to-br from-[#0a0a0a] to-[#09090b] ${className}`}
    >
      {/* LA REJILLA. Es la pieza que hacia falta para que el vidrio
          se vea.
          backdrop-blur difumina lo que hay DETRAS del elemento, y
          detras de la tarjeta solo habia negro: negro difuminado
          sigue siendo negro, asi que el efecto no se notaba por
          mucho que se subiera el blur. Hace falta algo con DETALLE
          FINO debajo, y una cuadricula de lineas de 1px es el patron
          que mas acusa el desenfoque.
          Se dibuja con dos linear-gradient repetidos (uno vertical y
          otro horizontal) en vez de un SVG: son dos declaraciones de
          CSS, no hay peticion de red que pueda fallar ni fichero que
          mantener.
          Va en style y no en clases porque un linear-gradient con
          comas dentro de un valor arbitrario de Tailwind obliga a
          escribir las comas y los espacios codificados: el resultado
          es una clase de 200 caracteres que nadie puede leer ni
          corregir. Aqui el CSS se lee tal cual. */}
      <div
        aria-hidden="true"
        className="pointer-events-none absolute inset-0"
        style={{
          backgroundImage:
            "linear-gradient(to right, rgba(255,255,255,0.07) 1px, transparent 1px), linear-gradient(to bottom, rgba(255,255,255,0.07) 1px, transparent 1px)",
          backgroundSize: "56px 56px",
          // La mascara radial desvanece la rejilla hacia los bordes,
          // para que no termine cortada en seco contra el panel
          // claro. El prefijo -webkit sigue haciendo falta para
          // Safari, que no soporta mask-image sin el.
          maskImage:
            "radial-gradient(ellipse 85% 75% at 50% 45%, #000 40%, transparent 100%)",
          WebkitMaskImage:
            "radial-gradient(ellipse 85% 75% at 50% 45%, #000 40%, transparent 100%)",
        }}
      />

      {/* UN solo resplandor, por encima de la rejilla y por debajo de
          la tarjeta, para que la cuadricula no se lea plana: la luz
          cae en diagonal desde arriba a la izquierda y deja la
          esquina opuesta mas apagada.
          Es una elipse girada y no un circulo, para que el reflejo
          cruce la rejilla en diagonal y no la ilumine por anillos.
          aria-hidden y pointer-events-none porque es decoracion pura:
          no debe anunciarse a un lector de pantalla ni interceptar
          clics destinados al formulario. */}
      <div
        aria-hidden="true"
        className="pointer-events-none absolute top-[-8rem] left-[-10rem] h-[24rem] w-[38rem] -rotate-12 rounded-full bg-sky-500/15 blur-[100px]"
      />

      {children}
    </main>
  );
}
