"use client";

import { useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";

import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
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
    <main className="flex flex-1 items-center justify-center bg-background p-6">
      <Card className="w-full max-w-md">
        <CardHeader>
          <CardTitle className="text-2xl font-semibold tracking-tight">
            Crear cuenta
          </CardTitle>
          <CardDescription>
            Registrate para agendar y gestionar tus citas.
          </CardDescription>
        </CardHeader>

        <CardContent>
          {/* noValidate desactiva los mensajes nativos del navegador,
              que varian entre navegadores y estan en otro idioma: asi
              todos los errores vienen del esquema Zod. */}
          <form onSubmit={handleSubmit(onSubmit)} noValidate>
            <FieldGroup>
              <Field>
                <FieldLabel htmlFor="name">Nombre</FieldLabel>
                <Input
                  id="name"
                  type="text"
                  autoComplete="name"
                  aria-invalid={Boolean(errors.name)}
                  {...register("name")}
                />
                <FieldError errors={[errors.name]} />
              </Field>

              <Field>
                <FieldLabel htmlFor="email">Correo electronico</FieldLabel>
                <Input
                  id="email"
                  type="email"
                  autoComplete="email"
                  aria-invalid={Boolean(errors.email)}
                  {...register("email")}
                />
                <FieldError errors={[errors.email]} />
              </Field>

              <Field>
                <FieldLabel htmlFor="password">Contrasena</FieldLabel>
                <Input
                  id="password"
                  // type="password" no es decorativo: evita que la
                  // clave quede a la vista de quien mire la pantalla
                  // y que el navegador la sugiera en otros campos.
                  type="password"
                  // new-password le dice al gestor de contrasenas que
                  // es un alta, para que ofrezca generar una robusta
                  // en lugar de autocompletar una antigua.
                  autoComplete="new-password"
                  aria-invalid={Boolean(errors.password)}
                  {...register("password")}
                />
                <FieldDescription>
                  Minimo 12 caracteres, con mayuscula, minuscula, numero y
                  simbolo.
                </FieldDescription>
                <FieldError errors={[errors.password]} />
              </Field>

              <Button type="submit" disabled={isSubmitting}>
                {/* Se deshabilita mientras se envia para que un doble
                    clic no lance dos registros simultaneos. */}
                {isSubmitting ? "Creando cuenta..." : "Crear cuenta"}
              </Button>

              {mensaje && (
                <p
                  role="status"
                  className={
                    mensaje.tipo === "ok"
                      ? "text-sm text-foreground"
                      : "text-sm text-destructive"
                  }
                >
                  {mensaje.texto}
                </p>
              )}
            </FieldGroup>
          </form>
        </CardContent>
      </Card>
    </main>
  );
}
