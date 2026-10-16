/**
 * CitaSegura - Clases del panel de citas (CITA-11), en claro.
 *
 * El panel usa el lado CLARO de /login y /registro (neutral-50, texto
 * oscuro). Las piezas que alli estan pensadas para el lado oscuro se
 * invierten aqui, con la misma forma:
 *
 *   - Boton primario: el "Crear cuenta" de /registro (h-11, seminegrita,
 *     el mismo active:scale) con los colores al reves, oscuro sobre
 *     claro.
 *   - Campos: el Input de shadcn a la altura de los de las pantallas de
 *     autenticacion (h-11), con su borde y su anillo de foco por defecto.
 *   - Avisos: la misma caja redondeada de los mensajes de error de
 *     CITA-6, en tonos claros.
 *
 * CONTRASTE: ningun texto va por debajo de neutral-600 sobre blanco o
 * neutral-50 (unos 7:1). neutral-400 y neutral-500, que si se leian
 * sobre el fondo oscuro, aqui se quedan por debajo del 4,5:1 que pide
 * WCAG AA para texto normal.
 */

export const BOTON_PRIMARIO =
  "h-11 bg-neutral-900 text-sm font-semibold text-neutral-50 transition-all duration-200 hover:bg-neutral-800 active:scale-[0.98]";

export const CAMPO = "h-11 bg-white text-neutral-900";

export const AVISO_ERROR =
  "rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-800";

export const AVISO_OK =
  "rounded-xl border border-neutral-200 bg-white px-4 py-3 text-sm text-neutral-800";
