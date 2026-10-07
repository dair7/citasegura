import type { Metadata } from "next";
import { Geist_Mono, Inter } from "next/font/google";
import "./globals.css";

/**
 * Tipografia de la aplicacion.
 *
 * next/font descarga la fuente EN EL BUILD y la sirve desde el propio
 * dominio: el navegador del usuario no pide nada a fonts.googleapis.com
 * al abrir la pagina. Ademas de ser mas rapido, evita que un tercero
 * reciba la IP y la cabecera Referer de cada visitante.
 *
 * La variable se llama --font-inter y globals.css la enchufa al token
 * --font-sans del tema. Antes --font-sans se definia como
 * var(--font-sans), una autorreferencia que dejaba la variable sin
 * valor valido: por eso toda la interfaz se veia con la serif por
 * defecto del navegador aunque la fuente si se estuviera cargando.
 */
const inter = Inter({
  variable: "--font-inter",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "CitaSegura",
  description: "Sistema de agendamiento de citas seguro",
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html
      lang="es"
      className={`${inter.variable} ${geistMono.variable} h-full font-sans antialiased`}
    >
      {/* min-h-dvh: la ventana marca el alto MINIMO de la pagina, no
          el definitivo. Con h-dvh el alto quedaba clavado y cualquier
          contenido que no cupiera -- zoom alto, ventana baja -- habia
          que recortarlo o desplazarlo por dentro de un panel. Con el
          minimo, la pagina ocupa la ventana cuando el contenido es
          corto y crece cuando no lo es, con el scroll vertical normal
          del navegador.
          Sin overflow-hidden a ningun ancho, por lo mismo: lo que no
          cabe tiene que poder alcanzarse. El scroll horizontal se
          corta en cada pantalla, no aqui. */}
      <body className="flex min-h-dvh flex-col">{children}</body>
    </html>
  );
}
