// C30-10 · Enfocar **de verdad** un campo después de cerrar un `<dialog>`.
//
// Medido en Chrome el 2026-10-09: cuando un modal se cierra con el **dedo** o
// el mouse, el navegador le devuelve el foco al campo que lo tenía antes de
// abrirse, y `document.activeElement` dice que es ese campo… pero lo que
// teclea la pistola **no entra**. Con Enter no pasa, y por eso los tests que
// cierran los modales con Enter daban verde con el bug puesto.
//
// Un `focus()` sobre el elemento que ya figura enfocado no hace nada, así que
// el arreglo de siempre —`requestAnimationFrame(() => campo.focus())` al
// cerrarse el modal— no arreglaba: hay que soltarlo y volver a tomarlo.
//
// Yusef, en la PESA: *"la nota del cliente, al darle entendido acá, no
// regresas"*. La PESA es táctil (C27-13): el dedo es el camino normal.
export function enfocar(campo) {
  if (!campo) return
  if (document.activeElement === campo) campo.blur()
  campo.focus()
}
