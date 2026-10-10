// Los avisos del navegador, en español.
//
// Jorge, 2026-10-10: la validación de la descripción (C30-03) salía en
// inglés. No era nuestra: un `required` vacío lo frena el navegador con *su*
// texto («Please fill out this field.»), y ese texto sale en el idioma de
// Chrome, no en el de la página — `lang="es"` no lo cambia. Pasaba igual en
// los ~80 `required` del sistema; esto los cubre a todos de una vez.
//
// Un campo puede traer el suyo con `data-mensaje-obligatorio` (el contenido
// en /etiquetar dice qué escribir).
//
// La trampa de `setCustomValidity`: mientras tenga texto, el campo es inválido
// **aunque esté lleno**, y el formulario no sale. Por eso el mensaje se suelta:
//
// - en el campo que muestra el globo, al escribir, cambiar o salir de él;
// - en los demás inválidos del mismo intento, enseguida. El navegador muestra
//   un solo globo (en el primero, al que le da el foco), y a esos otros los
//   puede llenar la pantalla por JS sin un `input` — en /etiquetar el cliente
//   sale de la pre-alerta al escanear el tracking — y el F9 siguiente se
//   trabaría con un campo lleno que dice «obligatorio».
//
// Un mensaje propio de una pantalla (`setCustomValidity` que no puso este
// archivo) se respeta.

const nuestros = new Set()

function mensaje(el) {
  const v = el.validity
  if (v.valueMissing) {
    if (el.dataset.mensajeObligatorio) return el.dataset.mensajeObligatorio
    if (el.type === "checkbox") return "Marcá esta casilla para seguir."
    if (el.type === "radio" || el.tagName === "SELECT") return "Elegí una opción."
    if (el.type === "file") return "Elegí un archivo."
    return "Completá este campo."
  }
  if (v.typeMismatch) {
    if (el.type === "email") return "Escribí un correo válido, como nombre@dominio.com."
    if (el.type === "url") return "Escribí una dirección web completa, con https://."
    return "Revisá el formato."
  }
  if (v.badInput) return el.type === "number" ? "Escribí solo un número." : "Revisá el valor: está incompleto."
  if (v.patternMismatch) return el.title ? `Revisá el formato: ${el.title}` : "Revisá el formato."
  if (v.tooShort) return `Escribí al menos ${el.minLength} caracteres (van ${el.value.length}).`
  if (v.tooLong) return `Son ${el.maxLength} caracteres como máximo.`
  if (v.rangeUnderflow) return `Tiene que ser ${el.min} o más.`
  if (v.rangeOverflow) return `Tiene que ser ${el.max} o menos.`
  if (v.stepMismatch) return el.step === "1" ? "Tiene que ser un número entero." : `Va de ${el.step} en ${el.step}.`
  return null
}

function soltar(el) {
  if (nuestros.delete(el)) el.setCustomValidity("")
}

function soltarLosQueNoSeVen() {
  for (const el of nuestros) if (el !== document.activeElement) soltar(el)
}

document.addEventListener("invalid", (event) => {
  const el = event.target
  if (typeof el.setCustomValidity !== "function") return
  if (el.validity.customError && !nuestros.has(el)) return

  el.setCustomValidity("")
  nuestros.delete(el)
  const texto = mensaje(el)
  if (!texto) return

  el.setCustomValidity(texto)
  nuestros.add(el)
  setTimeout(soltarLosQueNoSeVen, 0)
}, true)

for (const tipo of ["input", "change", "focusout"]) {
  document.addEventListener(tipo, (event) => soltar(event.target), true)
}

document.addEventListener("turbo:before-render", () => nuestros.clear())
