"use client";

import { useState } from "react";
import Link from "next/link";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { ArrowRight, CircleCheck, Eye, EyeOff } from "lucide-react";

import { AuthSplitLayout } from "@/components/auth/auth-split-layout";
import { Button } from "@/components/ui/button";
import {
  Field,
  FieldDescription,
  FieldError,
  FieldGroup,
  FieldLabel,
} from "@/components/ui/field";
import { Input } from "@/components/ui/input";
import {
  registerSchema,
  type RegisterInput,
  type RegisterRawInput,
} from "@/lib/validations/auth";

/**
 * CitaSegura - Formulario de registro (CITA-6).
 *
 * IMPORTANTE PARA LA SUSTENTACION: la validacion que ocurre en este
 * archivo es COMODIDAD, no seguridad. Corre en el navegador, donde el
 * usuario es dueño de todo: puede desactivar el JavaScript, editar el
 * DOM o ignorar esta pagina y lanzar la peticion con curl. El control
 * real vive en src/app/api/auth/register/route.ts, que vuelve a
 * ejecutar este MISMO esquema sobre el cuerpo recibido.
 *
 * Se comparte el esquema para que no haya dos verdades: si manana
 * cambia una regla de contrasena, cambia en un solo sitio y cliente y
 * servidor siguen de acuerdo.
 */

type MensajeServidor = { tipo: "ok" | "error"; texto: string };

export default function RegistroPage() {
  const [mensaje, setMensaje] = useState<MensajeServidor | null>(null);
  const [verContrasena, setVerContrasena] = useState(false);

  /**
   * Registro ya completado. Es una lectura del mismo estado de
   * siempre, no un estado nuevo: la bandera existe solo para que la
   * condicion se lea igual en los dos sitios donde se usa.
   */
  const registroCompletado = mensaje?.tipo === "ok";

  const {
    register,
    handleSubmit,
    reset,
    setError,
    formState: { errors, isSubmitting },
  } = useForm<RegisterRawInput, unknown, RegisterInput>({
    resolver: zodResolver(registerSchema),
    // onTouched: no se regaña al usuario mientras escribe la primera
    // vez; se valida al salir del campo y despues en cada cambio.
    mode: "onTouched",
    defaultValues: { name: "", email: "", password: "" },
  });

  // handleSubmit solo llama a esta funcion si el esquema Zod valida.
  // Si hay errores, ni siquiera se envia la peticion: se pintan los
  // mensajes y el formulario se queda quieto.
  async function onSubmit(datos: RegisterInput) {
    setMensaje(null);

    try {
      const respuesta = await fetch("/api/auth/register", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        // 'datos' es la SALIDA del esquema: nombre sin espacios
        // sobrantes y correo ya en minusculas. El servidor lo
        // normalizara otra vez de todos modos.
        body: JSON.stringify(datos),
      });

      const cuerpo: { message?: string; errors?: Record<string, string[]> } =
        await respuesta.json().catch(() => ({}));

      if (respuesta.ok) {
        // La contrasena desaparece de la memoria del formulario en
        // cuanto se usa: no se guarda en estado, ni en localStorage,
        // ni se escribe en la consola. Jamas.
        reset();
        // Tambien se vuelve a ocultar el campo: si el usuario lo habia
        // destapado, no se queda nada visible en pantalla al terminar.
        setVerContrasena(false);
        setMensaje({
          tipo: "ok",
          texto:
            cuerpo.message ?? "Registro completado. Ya puedes iniciar sesion.",
        });
        return;
      }

      // Si el servidor rechazo algun campo (por ejemplo porque se
      // manipulo el cliente), sus mensajes MANDAN sobre los locales.
      if (cuerpo.errors) {
        for (const [campo, mensajes] of Object.entries(cuerpo.errors)) {
          if (campo === "name" || campo === "email" || campo === "password") {
            setError(campo, { message: mensajes[0] });
          }
        }
      }

      setMensaje({
        tipo: "error",
        texto: cuerpo.message ?? "No se pudo completar el registro.",
      });
    } catch {
      // Fallo de red: mensaje generico, sin detalles tecnicos.
      setMensaje({
        tipo: "error",
        texto: "No se pudo conectar con el servidor. Intentalo de nuevo.",
      });
    }
  }

  return (
    <AuthSplitLayout>
      <div className="space-y-8">
        <header className="space-y-2">
          <h1 className="text-2xl font-semibold tracking-tight text-white">
            Crear cuenta
          </h1>
          <p className="text-sm text-neutral-400">
            Ya tienes cuenta?{" "}
            <Link
              href="/login"
              className="font-medium text-white underline underline-offset-4 transition-colors duration-200 hover:text-sky-300"
            >
              Iniciar sesion
            </Link>
          </p>
        </header>

        {/* Cuando el registro sale bien el formulario se RETIRA y en
            su sitio queda la confirmacion. Asi la tarjeta no crece de
            golpe ni deja nada fuera de la ventana, y no se ofrece un
            formulario que ya no hay que rellenar. */}
        {!registroCompletado && (
          /* noValidate desactiva los mensajes nativos del navegador,
             que varian entre navegadores y estan en otro idioma: asi
             todos los errores vienen del esquema Zod. */
          <form onSubmit={handleSubmit(onSubmit)} noValidate>
            <FieldGroup className="gap-6">
              <Field>
                <FieldLabel htmlFor="name" className="text-neutral-200">
                  Nombre
                </FieldLabel>
                <Input
                  id="name"
                  type="text"
                  autoComplete="name"
                  placeholder="Nombre y apellido"
                  className="h-11 border-white/10 bg-white/5 text-white transition-colors duration-200 placeholder:text-neutral-500 focus-visible:border-white/25 focus-visible:ring-1 focus-visible:ring-white/30"
                  aria-invalid={Boolean(errors.name)}
                  {...register("name")}
                />
                <FieldError errors={[errors.name]} className="text-red-300" />
              </Field>

              <Field>
                <FieldLabel htmlFor="email" className="text-neutral-200">
                  Correo electronico
                </FieldLabel>
                <Input
                  id="email"
                  type="email"
                  autoComplete="email"
                  placeholder="nombre@correo.com"
                  className="h-11 border-white/10 bg-white/5 text-white transition-colors duration-200 placeholder:text-neutral-500 focus-visible:border-white/25 focus-visible:ring-1 focus-visible:ring-white/30"
                  aria-invalid={Boolean(errors.email)}
                  {...register("email")}
                />
                <FieldError errors={[errors.email]} className="text-red-300" />
              </Field>

              <Field>
                <FieldLabel htmlFor="password" className="text-neutral-200">
                  Contrasena
                </FieldLabel>

                <div className="relative">
                  <Input
                    id="password"
                    // type="password" no es decorativo: evita que la
                    // clave quede a la vista de quien mire la pantalla
                    // y que el navegador la sugiera en otros campos.
                    type={verContrasena ? "text" : "password"}
                    // new-password le dice al gestor de contrasenas que
                    // es un alta, para que ofrezca generar una robusta
                    // en lugar de autocompletar una antigua.
                    autoComplete="new-password"
                    className="h-11 border-white/10 bg-white/5 pr-11 text-white transition-colors duration-200 placeholder:text-neutral-500 focus-visible:border-white/25 focus-visible:ring-1 focus-visible:ring-white/30"
                    aria-invalid={Boolean(errors.password)}
                    {...register("password")}
                  />

                  {/* Mostrar/ocultar. Empieza oculto y solo el usuario lo
                      destapa. Aqui ayuda mas que en el login: con cuatro
                      clases de caracteres obligatorias, poder leer lo que
                      se escribio evita crear una cuenta con una clave que
                      no es la que se creia haber puesto. */}
                  <Button
                    type="button"
                    variant="ghost"
                    size="icon-sm"
                    className="absolute top-1/2 right-1.5 -translate-y-1/2 text-neutral-400 transition-colors duration-200 hover:bg-white/10 hover:text-white"
                    aria-label={
                      verContrasena ? "Ocultar contrasena" : "Mostrar contrasena"
                    }
                    aria-pressed={verContrasena}
                    onClick={() => setVerContrasena((visible) => !visible)}
                  >
                    {verContrasena ? (
                      <EyeOff aria-hidden="true" />
                    ) : (
                      <Eye aria-hidden="true" />
                    )}
                  </Button>
                </div>

                {/* Los requisitos se muestran ANTES de escribir, no como
                    reproche despues de fallar. Una politica que solo
                    aparece cuando ya te equivocaste empuja a probar
                    variantes de la misma clave debil hasta que una pasa;
                    dicha de entrada, se elige una buena a la primera.
                    Esto es exactamente lo contrario de lo que se hace en
                    /login, donde listarlos solo ayudaria al atacante. */}
                <FieldDescription className="text-neutral-400">
                  Minimo 12 caracteres, con mayuscula, minuscula, numero y
                  simbolo.
                </FieldDescription>
                <FieldError errors={[errors.password]} className="text-red-300" />
              </Field>

              <Button
                type="submit"
                size="lg"
                className="h-11 w-full bg-white text-sm font-semibold text-neutral-950 transition-all duration-200 hover:bg-neutral-200 active:scale-[0.98]"
                disabled={isSubmitting}
              >
                {/* Se deshabilita mientras se envia para que un doble
                    clic no lance dos registros simultaneos. */}
                {isSubmitting ? "Creando cuenta..." : "Crear cuenta"}
              </Button>
            </FieldGroup>
          </form>
        )}

        {registroCompletado && (
          // Se confirma y se ofrece el paso siguiente como ENLACE, sin
          // redirigir automaticamente: el registro no abre sesion (no
          // hay cookie en esta respuesta), asi que llevar a la fuerza a
          // otra pantalla dejaria al usuario sin leer la confirmacion y
          // sin entender que todavia tiene que identificarse.
          <div
            role="status"
            className="space-y-3 rounded-xl border border-white/10 bg-white/5 px-4 py-4 text-sm text-neutral-300"
          >
            <p className="flex gap-2 font-medium text-white">
              <CircleCheck
                aria-hidden="true"
                className="mt-0.5 size-4 shrink-0 text-sky-300"
              />
              {mensaje.texto}
            </p>
            <Link
              href="/login"
              className="inline-flex items-center gap-1.5 font-medium text-white underline underline-offset-4 transition-colors duration-200 hover:text-sky-300"
            >
              Ir a iniciar sesion
              <ArrowRight aria-hidden="true" className="size-4" />
            </Link>
          </div>
        )}

        {mensaje?.tipo === "error" && (
          <p
            role="alert"
            className="rounded-xl border border-red-400/20 bg-red-400/10 px-4 py-3 text-sm text-red-200"
          >
            {mensaje.texto}
          </p>
        )}
      </div>
    </AuthSplitLayout>
  );
}
