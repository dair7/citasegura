import type { NextConfig } from "next";

// Cabeceras de seguridad que acompañan a TODAS las respuestas: paginas,
// rutas de la API y tambien las de error (404, 401). Cada una cierra una
// clase de ataque que el navegador solo bloquea si el servidor se lo pide.
const cabecerasSeguridad = [
  // Impide que el navegador "adivine" el tipo de un contenido y ejecute
  // como script algo que el servidor declaro como otra cosa.
  { key: "X-Content-Type-Options", value: "nosniff" },
  // Ninguna pagina puede mostrarse dentro de un iframe ajeno: corta el
  // clickjacking, en el que otro sitio superpone la aplicacion invisible
  // para que el usuario pulse sin saberlo (por ejemplo, "Cancelar").
  { key: "X-Frame-Options", value: "DENY" },
  // Al seguir un enlace no se envia la URL de origen: que rutas visita
  // un usuario dentro de la aplicacion no sale hacia otros sitios.
  { key: "Referrer-Policy", value: "no-referrer" },
  // La aplicacion no usa camara, microfono ni ubicacion. Negarlos aqui
  // impide que un script inyectado los pida en nombre del sitio.
  {
    key: "Permissions-Policy",
    value: "camera=(), microphone=(), geolocation=()",
  },
  // Un año de HTTPS obligatorio para este dominio, contra la degradacion
  // a HTTP y el robo de la cookie de sesion en una red intermedia.
  // OJO: en local la aplicacion se sirve por HTTP, y el navegador solo
  // obedece esta cabecera cuando la recibe por HTTPS. Aqui viaja, pero
  // no tiene efecto; solo se puede verificar desplegando con TLS.
  { key: "Strict-Transport-Security", value: "max-age=31536000" },
];

// Content-Security-Policy NO esta, a proposito. Next.js inyecta scripts
// en linea para hidratar la pagina, y una CSP fija aqui obligaria a
// permitir 'unsafe-inline' en script-src: es decir, a dejar abierta la
// misma puerta del XSS que la politica deberia cerrar. La forma correcta
// es un nonce distinto en cada peticion, generado en un Proxy, y eso
// exige ademas renderizar dinamicamente las paginas que hoy son
// estaticas. Queda como trabajo pendiente, no como una CSP debil.

const nextConfig: NextConfig = {
  // Sin "X-Powered-By: Next.js": la aplicacion deja de anunciar su
  // framework en una cabecera dedicada a eso, que es lo primero que mira
  // quien busca fallos conocidos de una tecnologia. No basta para
  // ocultarlo: otras cabeceras de Next.js (x-nextjs-*, el Vary con
  // next-router-*) siguen llevando su nombre.
  poweredByHeader: false,

  async headers() {
    return [
      {
        // "/:path*" cubre tambien la raiz "/" (cero o mas segmentos).
        source: "/:path*",
        headers: cabecerasSeguridad,
      },
    ];
  },
};

export default nextConfig;
