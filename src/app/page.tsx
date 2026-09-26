import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Button } from "@/components/ui/button";

const listo = [
  "Next.js 16 con App Router y TypeScript",
  "Tailwind CSS 4",
  "shadcn/ui (button, input, label, card, field)",
  "ESLint configurado",
];

const pendiente = [
  "Conexion a PostgreSQL local",
  "API Routes en src/app/api/",
  "Autenticacion y gestion de citas",
];

export default function Home() {
  return (
    <main className="flex flex-1 items-center justify-center bg-background p-6">
      <Card className="w-full max-w-lg">
        <CardHeader>
          <CardTitle className="text-3xl font-semibold tracking-tight">
            CitaSegura
          </CardTitle>
          <CardDescription>
            Sistema de agendamiento de citas seguro
          </CardDescription>
        </CardHeader>

        <CardContent className="space-y-6 text-sm">
          <section>
            <h2 className="mb-2 font-medium">Listo</h2>
            <ul className="space-y-1 text-muted-foreground">
              {listo.map((item) => (
                <li key={item} className="flex gap-2">
                  <span aria-hidden="true" className="text-foreground">
                    &#10003;
                  </span>
                  {item}
                </li>
              ))}
            </ul>
          </section>

          <section>
            <h2 className="mb-2 font-medium">Siguiente paso</h2>
            <ul className="space-y-1 text-muted-foreground">
              {pendiente.map((item) => (
                <li key={item} className="flex gap-2">
                  <span aria-hidden="true">&#183;</span>
                  {item}
                </li>
              ))}
            </ul>
          </section>
        </CardContent>

        <CardFooter className="flex-col items-start gap-2">
          <Button disabled>Agendar una cita</Button>
          <p className="text-xs text-muted-foreground">
            Disponible cuando se implemente la base de datos.
          </p>
        </CardFooter>
      </Card>
    </main>
  );
}
