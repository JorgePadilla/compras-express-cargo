// C30-10 · Enfocar **de verdad** un campo después de cerrar un `<dialog>`.
//
// Medido en Chrome el 2026-10-09: cuando un modal se cierra con el **dedo** o
// el mouse, el navegador le devuelve el foco al campo que lo tenía antes de
// abrirse, y `document.activeElement` dice que es ese campo… pero lo que
// teclea la pistola **no entra**. Con Enter no pasa, y por eso los tests que
// cierran los modales con Enter daban verde con el bug puesto.
//
// Yusef, en la PESA: *"la nota del cliente, al darle entendido acá, no
// regresas"*. La PESA es táctil (C27-13): el dedo es el camino normal. Y el
// mismo bug estaba en el escaneo del manifiesto, en /empacar y en /etiquetar
// (PR-C30.8).
//
// PR-C30.8 · El porqué, medido: el clic deja la **selección** del documento
// afuera, en un texto de la página, y el teclado escribe donde está la
// selección, no donde está el foco. Un `focus()` sobre el campo que ya figura
// enfocado no la mueve. La primera versión (PR-C30.5) soltaba el foco y lo
// volvía a tomar; eso dispara `blur`, y en /etiquetar el `blur` del tracking
// sale a buscarlo (`checkTracking`). Vaciar la selección no dispara nada.
export function enfocar(campo) {
  if (!campo) return
  window.getSelection()?.removeAllRanges()
  campo.focus()
}
