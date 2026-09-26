import { registerSchema } from "./src/lib/validations/auth.ts";
const casos: Array<[string, unknown]> = [
  ["valido + normaliza email/nombre", { name: "  Dair Plaza  ", email: "  DAIR@Ejemplo.COM ", password: "ClaveSegura1!" }],
  ["valido simple",                   { name: "Ana", email: "ana@ejemplo.com", password: "OtraClave9#" + "x" }],
  ["email invalido",                  { name: "Dair", email: "no-es-correo", password: "ClaveSegura1!" }],
  ["email sin dominio",               { name: "Dair", email: "dair@", password: "ClaveSegura1!" }],
  ["password corta (11)",             { name: "Dair", email: "a@b.com", password: "Clave1!abcd" }],
  ["password sin mayuscula",          { name: "Dair", email: "a@b.com", password: "clavesegura1!" }],
  ["password sin minuscula",          { name: "Dair", email: "a@b.com", password: "CLAVESEGURA1!" }],
  ["password sin numero",             { name: "Dair", email: "a@b.com", password: "ClaveSegura!!" }],
  ["password sin simbolo",            { name: "Dair", email: "a@b.com", password: "ClaveSegura12" }],
  ["password > 72 bytes",             { name: "Dair", email: "a@b.com", password: "Aa1!" + "ñ".repeat(40) }],
  ["clave extra role=admin",          { name: "Dair", email: "a@b.com", password: "ClaveSegura1!", role: "admin" }],
  ["nombre de 1 caracter",            { name: "D", email: "a@b.com", password: "ClaveSegura1!" }],
  ["body no es objeto",               "soy un string"],
];
for (const [etiqueta, entrada] of casos) {
  const r = registerSchema.safeParse(entrada);
  if (r.success) console.log(`OK       | ${etiqueta.padEnd(32)} -> ${JSON.stringify(r.data)}`);
  else console.log(`RECHAZA  | ${etiqueta.padEnd(32)} -> ${r.error.issues.map(i=>`${i.path.join(".")||"(raiz)"}: ${i.message}`).join(" ; ")}`);
}
