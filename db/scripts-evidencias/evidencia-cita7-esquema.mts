// ---------------------------------------------------------------
//  CitaSegura - Evidencia de CITA-7: el esquema de registro, sin servidor
//  Uso (con NODE, no con bash):
//    node db/scripts-evidencias/evidencia-cita7-esquema.mts | tee db/scripts-evidencias/salida-cita7-esquema.txt
//  Requiere: node 22.6 o posterior (ejecuta TypeScript directamente).
//
//  Pasa 13 entradas por registerSchema, el mismo esquema que usan el
//  formulario de /registro y POST /api/auth/register, y muestra que
//  acepta o rechaza cada una y con que mensaje. Prueba la regla, no el
//  endpoint: evidencia-cita7.sh ya prueba el endpoint con curl, pero
//  solo con una contrasena debil ("123"). Aqui se ve cada regla de la
//  politica de contrasenas por separado, el tope de 72 bytes de bcrypt,
//  la normalizacion del correo y el rechazo de la clave sobrante 'role'.
//
//  Fue una prueba puntual del 25 de septiembre (probe-auth.mts, en la
//  raiz). Se trajo aqui el 16 de octubre porque cubre casos que ningun
//  otro guion prueba. Esta excluido del type-check en tsconfig.json:
//  importa el .ts con su extension, que es lo que node necesita y tsc
//  no admite sin allowImportingTsExtensions.
// ---------------------------------------------------------------
import { execSync } from "node:child_process";

import { registerSchema } from "../../src/lib/validations/auth.ts";

const commit = execSync("git log -1 --format=\"%h %s\"").toString().trim();
console.log("===============================================================");
console.log(" CITA-7  Esquema de registro (registerSchema), sin servidor");
console.log(` Fecha: ${new Date().toLocaleString("sv-SE")}`);
console.log(` Commit: ${commit}`);
console.log("===============================================================");
console.log("");

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

console.log("");
console.log("===============================================================");
console.log(" Esperado:");
console.log("   los dos primeros OK; el primero con el nombre recortado y el");
console.log("   correo en minusculas y sin espacios");
console.log("   los otros once RECHAZA, cada uno con el mensaje de su regla;");
console.log("   'role' rechazado como clave no reconocida (z.strictObject)");
console.log("===============================================================");
