"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { useForm, useWatch } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";

import { AVISO_ERROR, BOTON_PRIMARIO, CAMPO } from "@/app/inicio/estilos";
import { Button } from "@/components/ui/button";
import {
  Field,
  FieldError,
  FieldGroup,
  FieldLabel,
} from "@/components/ui/field";
import { Input } from "@/components/ui/input";
import { cn } from "@/lib/utils";
import {
  crearCitaSchema,
  MOTIVO_MAX_CARACTERES,
  type CrearCitaInput,
  type CrearCitaRawInput,
} from "@/lib/validations/citas";

/**
 * El <textarea> no tiene componente de shadcn en el proyecto, asi que
 * repite las clases por defecto del Input (src/components/ui/input.tsx)
 * para que el motivo se vea como los otros dos campos.
 */
const AREA_TEXTO =
  "min-h-28 w-full min-w-0 resize-y rounded-lg border border-input bg-white px-2.5 py-2 text-base text-neutral-900 transition-colors outline-none placeholder:text-muted-foreground focus-visible:border-ring focus-visible:ring-3 focus-visible:ring-ring/50 aria-invalid:border-destructive aria-invalid:ring-3 aria-invalid:ring-destructive/20 md:text-sm";

/** Rojo de los errores: red-700 supera el 4,5:1 sobre blanco. */
const TEXTO_ERROR = "text-red-700";

/**
 * Une el dia y la hora del formulario en un ISO 8601 CON EL
 * DESPLAZAMIENTO de la zona del navegador: "2026-10-20" + "15:30" ->
 * "2026-10-20T15:30:00-05:00".
 *
 * Por que: la columna es TIMESTAMPTZ y el esquema exige la zona
 * explicita. Una hora suelta ("2026-10-20T15:30") la interpretaria el
 * servidor con SU zona, y la cita quedaria a otra hora si el servidor y
 * el usuario no estan en la misma. Los <input type="date"> y "time" no
 * llevan zona, asi que se añade aqui: es la hora que el usuario ve en
 * su reloj.
 *
 * El desplazamiento se calcula para ESA fecha, no para hoy, por si la
 * zona tiene horario de verano. Con algun campo vacio devuelve "", y
 * el esquema lo rechaza con su propio mensaje.
 */
function componerFechaHora(fecha: string, hora: string): string {
  if (!fecha || !hora) return "";

  // Sin zona, el navegador interpreta esta cadena como hora LOCAL.
  const local = new Date(`${fecha}T${hora}:00`);
  if (Number.isNaN(local.getTime())) return "";

  const minutos = -local.getTimezoneOffset();
  const signo = minutos >= 0 ? "+" : "-";
  const horas = String(Math.floor(Math.abs(minutos) / 60)).padStart(2, "0");
  const resto = String(Math.abs(minutos) % 60).padStart(2, "0");

  return `${fecha}T${hora}:00${signo}${horas}:${resto}`;
}

/**
 * CitaSegura - Formulario de agendar cita (CITA-11).
 *
 * IMPORTANTE PARA LA SUSTENTACION: igual que en /registro y /login, lo
 * que valida este formulario es COMODIDAD, no seguridad. Corre en el
 * navegador y se salta con curl. El control real es POST /api/citas,
 * que vuelve a ejecutar crearCitaSchema (CITA-14, evidencia 7.1).
 *
 * Se valida con ESE MISMO esquema, importado de
 * src/lib/validations/citas.ts, para que cliente y servidor no puedan
 * divergir: el limite de 500 caracteres del motivo, que coincide con el
 * CHECK de la tabla, y la fecha futura con zona, son una sola regla
 * escrita en un solo sitio.
 */
export function FormularioCita({
  onAgendada,
}: {
  onAgendada: () => Promise<void>;
}) {
  const router = useRouter();

  // Dia y hora van en dos campos porque asi los pide el usuario, pero
  // el esquema (y la API) esperan UN valor, scheduledAt. Estos dos
  // estados solo existen para componerlo.
  const [fecha, setFecha] = useState("");
  const [hora, setHora] = useState("");
  const [errorEnvio, setErrorEnvio] = useState<string | null>(null);

  const {
    register,
    handleSubmit,
    setValue,
    getValues,
    setError,
    reset,
    control,
    formState: { errors, isSubmitting, isSubmitted },
  } = useForm<CrearCitaRawInput, unknown, CrearCitaInput>({
    resolver: zodResolver(crearCitaSchema),
    mode: "onTouched",
    defaultValues: { scheduledAt: "", reason: "" },
  });

  const motivo = useWatch({ control, name: "reason" });
  const caracteres = motivo?.length ?? 0;

  function actualizarFechaHora(nuevaFecha: string, nuevaHora: string) {
    setFecha(nuevaFecha);
    setHora(nuevaHora);
    // Se valida en cuanto los dos campos tienen valor (o tras el primer
    // envio), no antes: avisar de "fecha invalida" mientras el usuario
    // todavia esta eligiendo la hora solo estorba.
    setValue("scheduledAt", componerFechaHora(nuevaFecha, nuevaHora), {
      shouldValidate: isSubmitted || (nuevaFecha !== "" && nuevaHora !== ""),
    });
  }

  // Enter en la fecha o en la hora pasa al campo siguiente en vez de
  // enviar. Es el gesto natural para "ya he elegido la hora", pero en
  // un <input> dentro de un <form> el navegador lo trata como enviar: el
  // formulario se mandaba a medias y el motivo, sin tocar todavia,
  // aparecia en rojo. Asi, el error del motivo solo sale al salir de
  // el o al pulsar "Agendar cita", como en el registro de CITA-6.
  function pasarAlSiguiente(evento: React.KeyboardEvent, siguiente: string) {
    if (evento.key !== "Enter") return;
    evento.preventDefault();
    document.getElementById(siguiente)?.focus();
  }

  // handleSubmit solo llama a esta funcion si el esquema valida.
  async function onSubmit(datos: CrearCitaInput) {
    setErrorEnvio(null);

    try {
      const respuesta = await fetch("/api/citas", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        // SOLO las dos claves del esquema: el servidor rechaza el cuerpo
        // entero si llega cualquier otra (z.strictObject).
        //
        // scheduledAt se envia como el texto que valido el esquema, con
        // el desplazamiento del usuario. datos.scheduledAt ya es un Date
        // (el esquema lo transforma), y JSON lo convertiria a UTC: seria
        // el mismo instante, pero la peticion dejaria de mostrar la zona
        // en la que el usuario eligio la hora.
        body: JSON.stringify({
          scheduledAt: getValues("scheduledAt"),
          reason: datos.reason,
        }),
      });

      if (respuesta.status === 401) {
        router.replace("/login");
        return;
      }

      const cuerpo: { message?: string; errors?: Record<string, string[]> } =
        await respuesta.json().catch(() => ({}));

      if (respuesta.ok) {
        reset();
        setFecha("");
        setHora("");
        await onAgendada();
        return;
      }

      // Si el servidor rechazo algun campo, sus mensajes MANDAN sobre
      // los locales: puede saber algo que el navegador no (por ejemplo,
      // que la hora elegida ya paso segun SU reloj).
      if (cuerpo.errors) {
        for (const [campo, mensajes] of Object.entries(cuerpo.errors)) {
          if (campo === "scheduledAt" || campo === "reason") {
            setError(campo, { message: mensajes[0] });
          }
        }
      }

      setErrorEnvio(cuerpo.message ?? "No se pudo agendar la cita.");
    } catch {
      setErrorEnvio("No se pudo conectar con el servidor. Intentalo de nuevo.");
    }
  }

  return (
    <div className="space-y-6">
      {/* noValidate: todos los errores vienen del esquema Zod, no de los
          mensajes nativos del navegador. */}
      <form onSubmit={handleSubmit(onSubmit)} noValidate>
        <FieldGroup className="gap-6">
          {/* El valor que de verdad se valida y se envia. */}
          <input type="hidden" {...register("scheduledAt")} />

          {/* Fecha y hora comparten fila y un solo error debajo: el
              esquema valida el instante completo, no el dia y la hora
              por separado. Las dos columnas son iguales, asi que los dos
              campos empiezan y terminan alineados con el motivo y el
              boton, que ocupan todo el ancho. */}
          <div className="space-y-2">
            <div className="grid gap-4 sm:grid-cols-2">
              <Field>
                <FieldLabel htmlFor="cita-fecha">Fecha</FieldLabel>
                <Input
                  id="cita-fecha"
                  type="date"
                  className={CAMPO}
                  value={fecha}
                  aria-invalid={Boolean(errors.scheduledAt)}
                  aria-describedby="cita-fecha-error"
                  onChange={(e) => actualizarFechaHora(e.target.value, hora)}
                  onKeyDown={(e) => pasarAlSiguiente(e, "cita-hora")}
                />
              </Field>

              <Field>
                <FieldLabel htmlFor="cita-hora">Hora</FieldLabel>
                <Input
                  id="cita-hora"
                  type="time"
                  className={CAMPO}
                  value={hora}
                  aria-invalid={Boolean(errors.scheduledAt)}
                  aria-describedby="cita-fecha-error"
                  onChange={(e) => actualizarFechaHora(fecha, e.target.value)}
                  onKeyDown={(e) => pasarAlSiguiente(e, "cita-motivo")}
                />
              </Field>
            </div>
            <FieldError
              id="cita-fecha-error"
              errors={[errors.scheduledAt]}
              className={TEXTO_ERROR}
            />
          </div>

          <Field>
            <FieldLabel htmlFor="cita-motivo">Motivo</FieldLabel>
            {/* <textarea> nativo: un motivo de hasta 500 caracteres no
                cabe en una sola linea. */}
            <textarea
              id="cita-motivo"
              rows={4}
              placeholder="Por ejemplo: renovacion de documento"
              className={AREA_TEXTO}
              aria-invalid={Boolean(errors.reason)}
              aria-describedby="cita-motivo-contador"
              {...register("reason")}
            />
            {/* El contador usa el MISMO limite que el esquema y el CHECK.
                No se pone maxLength en el campo: asi, quien pegue un
                texto largo ve el mensaje del esquema en lugar de que el
                navegador recorte su texto en silencio. */}
            <div className="flex items-start justify-between gap-4">
              <FieldError errors={[errors.reason]} className={TEXTO_ERROR} />
              <p
                id="cita-motivo-contador"
                className={cn(
                  "ml-auto shrink-0 text-xs tabular-nums",
                  caracteres > MOTIVO_MAX_CARACTERES
                    ? TEXTO_ERROR
                    : "text-neutral-600",
                )}
              >
                {caracteres}/{MOTIVO_MAX_CARACTERES}
              </p>
            </div>
          </Field>

          {/* Deshabilitado mientras se envia: un doble clic no debe
              agendar dos citas iguales. */}
          <Button
            type="submit"
            size="lg"
            className={cn(BOTON_PRIMARIO, "w-full")}
            disabled={isSubmitting}
          >
            {isSubmitting ? "Agendando..." : "Agendar cita"}
          </Button>
        </FieldGroup>
      </form>

      {/* Solo errores: el exito lo confirma el panel, que vuelve a "Mis
          citas" con la cita nueva ya en la lista. */}
      {errorEnvio && (
        <p role="alert" className={AVISO_ERROR}>
          {errorEnvio}
        </p>
      )}
    </div>
  );
}
