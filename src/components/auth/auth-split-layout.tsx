import { KeyRound, LogOut, UserLock } from "lucide-react";

import { FondoOscuro } from "@/components/identidad/fondo-oscuro";
import { Logotipo, MarcaDeAgua } from "@/components/identidad/marca";
import { TarjetaCristal } from "@/components/identidad/tarjeta-cristal";

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
        {/* Las marcas de agua (el escudo y el candado). Viven en
            components/identidad/marca.tsx, junto al logotipo. */}
        <MarcaDeAgua />

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
          <Logotipo />

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
          Panel del formulario, lado OSCURO: el FondoOscuro (rejilla,
          resplandor y su overflow-hidden; ver
          components/identidad/fondo-oscuro.tsx).
          No recorta nunca el formulario: este panel es una celda de la
          rejilla y su alto es el de la fila, que a su vez es el del
          contenido mas alto de las dos columnas. Es decir, el panel ya
          mide como poco lo que mide la tarjeta, asi que lo unico que
          queda fuera es la decoracion.

          NO se usa items-center para centrar la tarjeta, se usa m-auto
          en ella. Es un detalle que importa: cuando el contenido de un
          contenedor flex centrado con items-center es mas alto que el
          contenedor, el sobrante se reparte ARRIBA y ABAJO, y la parte
          de arriba se vuelve inalcanzable porque no se puede desplazar
          hacia atras del origen. Con margenes automaticos el navegador
          solo reparte el espacio que sobra, y si no sobra no inventa
          margen negativo: la tarjeta se queda entera y alcanzable.
         --------------------------------------------------------- */}
      <FondoOscuro className="flex justify-center px-6 py-16 sm:px-10 lg:px-16">
        {/* La tarjeta de cristal compartida (ver
            components/identidad/tarjeta-cristal.tsx). z-10 para quedar
            por encima de la rejilla y del resplandor. */}
        <TarjetaCristal className="z-10 m-auto w-[min(100%,30rem)] p-10 sm:p-12 2xl:w-[min(100%,34rem)]">
          {children}
        </TarjetaCristal>
      </FondoOscuro>
    </div>
  );
}
