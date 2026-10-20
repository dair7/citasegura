import "server-only";

import { notFound } from "next/navigation";

import { getSession, type SesionActiva } from "@/lib/auth/session";

/**
 * CitaSegura - Comprobacion de rol de administrador (CITA-19).
 *
 * ES EL CONTROL QUE DEFIENDE LA VISTA DE ADMINISTRADOR, y vive en un
 * solo sitio a proposito. La pagina /admin lo llama una vez, en el
 * servidor, antes de generar nada; las dos pestañas (citas y usuarios)
 * no lo repiten porque no son rutas, son estado del cliente dentro de
 * esa misma pagina. Si cada pestaña o cada consulta comprobara el rol
 * por su cuenta, habria varios sitios donde olvidarlo, y hoy no hay
 * denegacion por defecto que lo cubra (limitacion 7 de
 * db/EVIDENCIAS-FASE2.md).
 *
 * QUIEN NO ES ADMINISTRADOR RECIBE UN 404. No un 403, ni un "no
 * autorizado", ni una redireccion a /inicio: cualquiera de las tres le
 * confirmaria abiertamente que /admin existe y que hay algo detras que
 * merece la pena atacar. Se aplica igual al anonimo y al usuario normal
 * con sesion. Es el mismo criterio que la cancelacion de una cita ajena
 * en CITA-13 (cita ajena = cita inexistente).
 *
 * LIMITE MEDIDO (limitacion 10 de db/EVIDENCIAS-FASE2.md): el CODIGO
 * coincide con el de una ruta inexistente, pero la respuesta entera no.
 * La 404 de una ruta inexistente es una pagina prerenderizada; la de
 * notFound() aqui se genera al vuelo, con otras cabeceras, y la carga
 * util que Next.js mete en el HTML nombra el segmento "admin". Quien
 * compare las dos respuestas byte a byte puede saber que la ruta
 * existe. Lo que NO puede es ver ningun dato de la vista: notFound()
 * corta antes de cualquier consulta. Se probo a reescribir desde un
 * Proxy; el cuerpo salia identico, pero Next.js añade siempre la
 * cabecera x-middleware-rewrite, que delata la reescritura.
 *
 * EL ROL SE LEE DE LA BASE EN CADA PETICION. getSession() hace el JOIN
 * con users cada vez; el rol no viaja en la cookie ni se guarda en el
 * cliente, asi que no hay nada que el usuario pueda editar para
 * hacerse pasar por administrador. Ademas, si a una cuenta se le
 * retira el rol, lo pierde en la peticion siguiente, sin esperar a que
 * caduque su sesion.
 *
 * LA COMPARACION ES ESTRICTA contra "admin". El tipo de role es string
 * y no se comprueba "distinto de user": si algun dia la columna
 * admitiera un tercer valor, ese valor no obtendria acceso por
 * descuido. Lo que no esta permitido expresamente, esta denegado.
 */
export async function exigirAdministrador(): Promise<SesionActiva> {
  const sesion = await getSession();

  if (!sesion || sesion.user.role !== "admin") {
    // notFound() lanza una excepcion que corta el renderizado: nada de
    // lo que viene despues en la pagina llega a ejecutarse, y menos las
    // consultas. Tiene que llamarse ANTES de que empiece a enviarse la
    // respuesta (sin <Suspense> ni loading.tsx por encima), o el
    // codigo HTTP ya habria salido como 200.
    notFound();
  }

  return sesion;
}
