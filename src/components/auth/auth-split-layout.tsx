import { KeyRound, Lock, LogOut, ShieldCheck, UserLock } from "lucide-react";

/**
 * Los tres pilares del sistema, resumidos en el panel de marca.
 *
 * No son un adorno de relleno: cada linea corresponde a un control
 * implementado y defendible. Contar al usuario que existen es parte de
 * la transparencia que se le debe despues de un incidente como el de
 * la DIAN, y para el tribunal son el indice de lo que se va a mostrar.
 */
const PILARES = [
  {
    icono: KeyRound,
    titulo: "Contrasenas cifradas",
    descripcion: "Nunca se guardan en texto plano.",
  },
  {
    icono: LogOut,
    titulo: "Sesiones revocables",
    descripcion: "Cerrar sesion invalida el acceso en el servidor.",
  },
  {
    icono: UserLock,
    titulo: "Acceso minimo",
    descripcion: "Cada usuario ve unicamente sus propios datos.",
  },
];

/**
 * CitaSegura - Marco visual compartido por /login y /registro (CITA-6).
 *
 * Solo presentacion: no tiene estado, no recibe datos del usuario y no
 * toca la base de datos. Se extrae a un componente para que las dos
 * pantallas de autenticacion sean la MISMA pantalla con distinto
 * formulario, y para que la marca se cambie en un unico sitio.
 *
 * Por que importa para la sustentacion: que las dos pantallas se vean
 * identicas no es estetica, es una defensa contra el phishing. Si el
 * usuario esta acostumbrado a un acceso con esta forma exacta, una
 * copia mal hecha le resulta extraña. Una interfaz incoherente entrena
 * a la gente a no fijarse.
 *
 * COMPOSICION: izquierda clara con la marca, derecha oscura con el
 * formulario. El contraste separa de un vistazo las dos mitades: lo
 * que la aplicacion dice de si misma y lo que le pide al usuario.
 */
export function AuthSplitLayout({ children }: { children: React.ReactNode }) {
  return (
    // min-h-dvh y no h-dvh: la ventana marca el alto MINIMO, no el
    // definitivo. Asi los paneles crecen cuando su contenido no cabe
    // -- con el zoom al 200%, o con una ventana muy baja -- y la
    // pagina se desplaza en vertical con normalidad, en lugar de
    // recortar lo que sobresale. El <body> del layout raiz tambien es
    // min-h-dvh, de modo que los dos minimos coinciden y no se suman.
    //
    // overflow-x-hidden: el scroll HORIZONTAL no debe aparecer a
    // ningun nivel de zoom. Se corta aqui, en la raiz de la pantalla,
    // y no panel por panel, para que ningun descuido de maquetacion
    // futuro pueda sacarlo.
    // Una sola columna en movil (paneles apilados), 50/50 desde lg.
    <div className="grid min-h-dvh overflow-x-hidden lg:grid-cols-2">
      {/* ---------------------------------------------------------
          Panel de marca, lado CLARO.
          En moviles queda arriba como una banda; desde lg ocupa la
          mitad izquierda a altura completa.
         --------------------------------------------------------- */}
      {/* items-center + justify-center en lugar de flex-col: asi el
          bloque de contenido queda centrado en los DOS ejes a
          cualquier ancho de ventana. Antes el panel era una columna
          que solo centraba en vertical y estiraba el contenido a todo
          lo ancho, asi que en pantallas muy anchas el texto se
          quedaba pegado al borde izquierdo. */}
      <aside className="relative flex items-center justify-center overflow-hidden border-b border-neutral-200 bg-neutral-50 px-8 py-12 text-neutral-900 lg:border-r lg:border-b-0 lg:px-16 lg:py-16">
        {/* Marca de agua. Es el mismo escudo del logo, gigante y
            desbordando por la esquina inferior derecha: se ve solo un
            trozo, y el overflow-hidden del panel corta el resto.
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

        {/* El contenido, por encima de las marcas de agua.
            w-full max-w-lg mx-auto: ancho propio y centrado, para que
            no se estire ni se pegue al borde en pantallas anchas. */}
        {/* Ancho proporcional con tope, no fijo: crece con el espacio
            disponible hasta 34rem, y hasta 40rem en pantallas muy
            anchas. min(100%, ...) es lo que evita los dos extremos: al
            alejar el zoom ya no se queda un bloque diminuto en medio
            de un hueco enorme, y al acercarlo nunca pide mas ancho que
            el que hay, asi que no puede provocar scroll horizontal. */}
        <div className="relative z-10 mx-auto flex w-[min(100%,34rem)] flex-col gap-8 2xl:w-[min(100%,40rem)]">
          <div className="flex items-center gap-4">
            {/* Icono y titulo escalan juntos: si solo creciera el
                texto, el escudo se quedaria pequeño al lado. */}
            <span className="flex size-12 shrink-0 items-center justify-center rounded-2xl bg-neutral-900 text-neutral-50 sm:size-14">
              <ShieldCheck aria-hidden="true" className="size-6 sm:size-7" />
            </span>
            {/* La marca va en un <span> y no en un <h1>: el encabezado
                principal de la pagina es el titulo del formulario, que
                es la tarea real. Asi el orden de encabezados que
                anuncia un lector de pantalla sigue teniendo sentido. */}
            <span className="text-3xl font-semibold tracking-tight sm:text-4xl">
              CitaSegura
            </span>
          </div>

          <p className="text-pretty text-base leading-relaxed text-neutral-500">
            Agendamiento de citas seguro: tus datos personales quedan a la vista
            de quien debe verlos, y de nadie mas.
          </p>

          <ul className="flex flex-col gap-7">
            {PILARES.map(({ icono: Icono, titulo, descripcion }) => (
              <li key={titulo} className="flex gap-3">
                {/* aria-hidden en el icono: lo que dice ya esta escrito
                    en el texto de al lado, y repetirlo solo haria que
                    un lector de pantalla lea cada punto dos veces. */}
                <Icono
                  aria-hidden="true"
                  className="mt-0.5 size-4 shrink-0 text-neutral-400"
                />
                <div className="space-y-0.5">
                  <p className="text-sm font-medium text-neutral-900">
                    {titulo}
                  </p>
                  {/* neutral-600 y no neutral-500: sobre el fondo
                      neutral-50 el 500 se queda en torno a 4,4:1, por
                      debajo del 4,5:1 que pide WCAG AA para texto
                      normal, y las marcas de agua le restaban todavia
                      un poco mas. El 600 sube a unos 7:1. */}
                  <p className="text-sm leading-relaxed text-neutral-600">
                    {descripcion}
                  </p>
                </div>
              </li>
            ))}
          </ul>
        </div>
      </aside>

      {/* ---------------------------------------------------------
          Panel del formulario, lado OSCURO.
          overflow-hidden recorta el resplandor para que no desborde
          hacia el panel claro.
         --------------------------------------------------------- */}
      {/* overflow-hidden recorta la rejilla y el resplandor, que
          desbordan por los cuatro lados. No recorta nunca el
          formulario: este panel es una celda de la rejilla y su alto es
          el de la fila, que a su vez es el del contenido mas alto de
          las dos columnas. Es decir, el panel ya mide como poco lo que
          mide la tarjeta, asi que lo unico que queda fuera es la
          decoracion. Lo que no cabe en la ventana se alcanza con el
          scroll vertical normal de la pagina.

          NO se usa items-center para centrar la tarjeta, se usa m-auto
          en ella. Es un detalle que importa: cuando el contenido de un
          contenedor flex centrado con items-center es mas alto que el
          contenedor, el sobrante se reparte ARRIBA y ABAJO, y la parte
          de arriba se vuelve inalcanzable porque no se puede desplazar
          hacia atras del origen. Con margenes automaticos el navegador
          solo reparte el espacio que sobra, y si no sobra no inventa
          margen negativo: la tarjeta se queda entera y alcanzable. */}
      <main className="relative flex justify-center overflow-hidden bg-gradient-to-br from-[#0a0a0a] to-[#09090b] px-6 py-16 sm:px-10 lg:px-16">
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

        {/* La tarjeta de cristal: una lamina de vidrio flotando.
            relative + z-10 para quedar por encima de la rejilla y del
            resplandor, y overflow-hidden para que el brillo del canto y
            el reflejo interno respeten las esquinas redondeadas.
            IMPORTANTE para que el backdrop-blur funcione: ningun
            antepasado de esta tarjeta puede llevar filter, opacity,
            transform ni mask. Cualquiera de esas propiedades crea un
            'backdrop root' y el navegador deja de ver mas alla de el,
            asi que la tarjeta difuminaria la nada en lugar de la
            rejilla. Por eso la mascara radial va en la rejilla, que es
            su HERMANA, y no en el <main> que las contiene a las dos.
            El borde se simula en dos capas, porque CSS no admite un
            degradado en border-color: el border-white/10 marca el
            contorno completo y el ring interior al 5% le añade un
            segundo filo por dentro, que es lo que da el grosor de una
            lamina en lugar de una linea pintada. */}
        <div className="relative z-10 m-auto w-[min(100%,30rem)] overflow-hidden rounded-2xl border border-white/10 bg-white/[0.07] p-10 shadow-2xl shadow-black/60 ring-1 ring-white/5 ring-inset backdrop-blur-xl sm:p-12 2xl:w-[min(100%,34rem)]">
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

          {/* El formulario, por encima de las dos capas decorativas. */}
          <div className="relative">{children}</div>
        </div>
      </main>
    </div>
  );
}
