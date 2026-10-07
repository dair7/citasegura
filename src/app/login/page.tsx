"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { Eye, EyeOff } from "lucide-react";

import { AuthSplitLayout } from "@/components/auth/auth-split-layout";
import { Button } from "@/components/ui/button";
import {
  Field,
  FieldError,
  FieldGroup,
  FieldLabel,
} from "@/components/ui/field";
import { Input } from "@/components/ui/input";
import {
  loginSchema,
  type LoginInput,
  type LoginRawInput,
} from "@/lib/validations/auth";

/**
 * CitaSegura - Formulario de inicio de sesion (CITA-6).
 *
 * IMPORTANTE PARA LA SUSTENTACION: igual que en /registro, lo que
 * valida esta pagina es COMODIDAD, no seguridad. Corre en el navegador
 * y se puede saltar por completo. El control real esta en
 * src/app/api/auth/login/route.ts, que vuelve a ejecutar loginSchema,
 * verifica el hash con bcrypt y aplica el bloqueo de CITA-10.
 *
 * Esta pantalla reutiliza loginSchema, que existia desde CITA-9 sin
 * usarse en ninguna interfaz. Se comparte el esquema para que no haya
 * dos verdades sobre lo que es un cuerpo valido.
 */

/**
 * EL UNICO MENSAJE DE ERROR DE ESTA PANTALLA.
 *
 * Este texto es el mismo si el correo no existe, si la contrasena es
 * incorrecta, si la cuenta esta bloqueada por intentos fallidos
 * (CITA-10) o si el cuerpo ni siquiera paso la validacion del
 * servidor. Es deliberado, y es la mitad de cliente de un control que
 * el endpoint ya aplica por su lado.
 *
 * Por que: cualquier diferencia entre esas respuestas convierte el
 * login en un ORACULO. Con "ese correo no existe" se enumera la base
 * de usuarios probando direcciones; con "cuenta bloqueada" se confirma
 * que una direccion SI tiene cuenta y, de paso, se le avisa al
 * atacante de que su fuerza bruta va por buen camino. En el incidente
 * de la DIAN el dato filtrado era justamente de este tipo: quien tenia
 * un tramite abierto.
 *
 * El mensaje que manda el servidor se IGNORA a proposito (ver abajo).
 */
const MENSAJE_FALLO_LOGIN = "Correo o contrasena incorrectos.";

export default function LoginPage() {
  const router = useRouter();

  const [errorGlobal, setErrorGlobal] = useState<string | null>(null);
  const [verContrasena, setVerContrasena] = useState(false);
  // El boton sigue deshabilitado durante la navegacion a /inicio, no
  // solo durante el fetch: si no, se reactivaria un instante y
  // admitiria un segundo envio con la sesion ya creada.
  const [redirigiendo, setRedirigiendo] = useState(false);

  const {
    register,
    handleSubmit,
    resetField,
    formState: { errors, isSubmitting },
  } = useForm<LoginRawInput, unknown, LoginInput>({
    resolver: zodResolver(loginSchema),
    // Se valida al salir del campo, no mientras se escribe: nadie
    // quiere que le digan que su correo es invalido en la tercera letra.
    mode: "onTouched",
    defaultValues: { email: "", password: "" },
  });

  const procesando = isSubmitting || redirigiendo;

  async function onSubmit(datos: LoginInput) {
    setErrorGlobal(null);

    try {
      const respuesta = await fetch("/api/auth/login", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(datos),
      });

      if (respuesta.ok) {
        // La cookie de sesion ya viaja en esta respuesta: la puso
        // createSession() en el servidor con httpOnly, asi que este
        // JavaScript no la ve ni la necesita. Aqui solo se navega.
        setRedirigiendo(true);

        // replace y no push: el formulario de acceso no queda en el
        // historial, para que el boton Atras no devuelva a una pantalla
        // de login ya usada (y, en un equipo compartido, no deje el
        // correo escrito a la vista del siguiente).
        router.replace("/inicio");
        return;
      }

      // CUALQUIER respuesta de fallo del servidor -- 400, 401, 415, 500
      // -- termina en el mismo mensaje local. No se lee cuerpo.message
      // A PROPOSITO: asi, aunque alguien hiciera el endpoint mas
      // hablador en el futuro, esta pantalla seguiria sin filtrar nada.
      // El control no depende de que el backend se porte bien.
      //
      // Se limpia la contrasena, no el correo: reescribirla es el coste
      // de un fallo, y asi no queda en el formulario de un equipo
      // compartido. El correo se conserva porque reescribirlo no aporta
      // nada y solo estorba a quien se equivoco al teclear.
      resetField("password");
      setErrorGlobal(MENSAJE_FALLO_LOGIN);
    } catch {
      // Fallo de red: no hubo respuesta, asi que esto no es el
      // resultado de un intento de acceso y no revela nada de ninguna
      // cuenta. Por eso si puede tener un texto propio, y conviene que
      // lo tenga: decirle "credenciales incorrectas" a quien se quedo
      // sin conexion es mentirle.
      setErrorGlobal("No se pudo conectar con el servidor. Intentalo de nuevo.");
    }
  }

  return (
    <AuthSplitLayout>
      <div className="space-y-8">
        <header className="space-y-2">
          <h1 className="text-2xl font-semibold tracking-tight text-white">
            Iniciar sesion
          </h1>
          <p className="text-sm text-neutral-400">
            No tienes cuenta?{" "}
            <Link
              href="/registro"
              className="font-medium text-white underline underline-offset-4 transition-colors duration-200 hover:text-sky-300"
            >
              Crear una cuenta
            </Link>
          </p>
        </header>

        {/* noValidate desactiva los mensajes nativos del navegador, que
            cambian de idioma y de redaccion segun el navegador: asi
            todos los errores vienen del esquema Zod. */}
        <form onSubmit={handleSubmit(onSubmit)} noValidate>
          <FieldGroup className="gap-6">
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

              {/* AQUI NO SE LISTAN LOS REQUISITOS DE LA CONTRASENA.
                  Estan en /registro, que es donde ayudan a elegir una.
                  En el acceso solo le describirian al atacante la forma
                  de las contrasenas del sistema, recortandole el
                  espacio de busqueda. Y loginSchema tampoco los aplica:
                  rechazar por politica al entrar dejaria fuera para
                  siempre a las cuentas creadas con reglas anteriores, y
                  seria otro oraculo mas. */}
              <div className="relative">
                <Input
                  id="password"
                  type={verContrasena ? "text" : "password"}
                  // current-password: el gestor de contrasenas ofrece la
                  // ya guardada en lugar de proponer una nueva.
                  autoComplete="current-password"
                  className="h-11 border-white/10 bg-white/5 pr-11 text-white transition-colors duration-200 placeholder:text-neutral-500 focus-visible:border-white/25 focus-visible:ring-1 focus-visible:ring-white/30"
                  aria-invalid={Boolean(errors.password)}
                  {...register("password")}
                />

                {/* Mostrar/ocultar. El riesgo que atiende es el de
                    alrededor: quien escribe a ciegas se equivoca, y
                    poder verificar lo escrito evita intentos fallidos
                    que acercan al bloqueo de CITA-10. Empieza siempre
                    oculto, es el usuario quien decide destaparlo, y la
                    clave no sale del estado del formulario: no se copia
                    a ningun sitio ni se escribe en la consola. */}
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

              <FieldError errors={[errors.password]} className="text-red-300" />
            </Field>

            {/* Deshabilitado mientras procesa para que un doble clic no
                lance dos intentos: dos fallos simultaneos contarian dos
                veces en el contador de bloqueo. */}
            <Button
              type="submit"
              size="lg"
              className="h-11 w-full bg-white text-sm font-semibold text-neutral-950 transition-all duration-200 hover:bg-neutral-200 active:scale-[0.98]"
              disabled={procesando}
            >
              {procesando ? "Comprobando..." : "Iniciar sesion"}
            </Button>
          </FieldGroup>
        </form>

        {/* Zona de mensaje, debajo del formulario. role="alert" para que
            un lector de pantalla lo anuncie en cuanto aparece: sin eso,
            quien no ve la pantalla envia el formulario y no recibe
            ninguna noticia de que algo fallo. */}
        {errorGlobal && (
          <p
            role="alert"
            className="rounded-xl border border-red-400/20 bg-red-400/10 px-4 py-3 text-sm text-red-200"
          >
            {errorGlobal}
          </p>
        )}
      </div>
    </AuthSplitLayout>
  );
}
