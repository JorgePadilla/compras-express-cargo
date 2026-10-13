// C31-03 · Un formulario que guarda sale **una vez**.
//
// Yusef, en la prueba del 2026-10-12: *"Le di muy rápido dos veces… y mandó la
// versión dos veces"*. En el manifiesto aparecieron dos cajas. Y lo que pidió:
// un botón que guarda queda trabado al primer clic.
//
// Turbo ya deshabilita el botón mientras manda, pero quedan dos agujeros:
//
// - los formularios que van **sin Turbo** (`data-turbo=false`, como «Agregar e
//   imprimir» del manifiesto): ahí nadie deshabilita nada, y el segundo clic
//   sale antes de que cargue la página nueva;
// - `requestSubmit(boton)` desde una tecla: no mira si el botón está
//   deshabilitado. La tecla sostenida repite (`e.repeat`), y eso lo frenan los
//   handlers de teclas; esto es la red de abajo.
//
// Así que acá: el primer `submit` de un formulario lo marca «en vuelo», y uno
// nuevo del mismo formulario se cancela hasta que la respuesta llega
// (`turbo:submit-end`), la página vuelve del historial (`pageshow`) o pasan
// cinco segundos —por si algo se cortó en el medio y no avisó—.
//
// Lo que **no** se toca, a propósito:
//
// - los GET (buscar, filtrar, exportar): no crean nada, y volver a apretar
//   «Buscar» es legítimo;
// - los que abren otra pestaña (`target=_blank`): la impresión, que se puede
//   querer dos veces y no navega la página;
// - los que piden confirmación (`data-turbo-confirm`): el modal ya frena el
//   segundo clic, y si se contesta «no» Turbo no avisa nada —el formulario
//   quedaría trabado cinco segundos sin razón—;
// - los `method="dialog"`, que solo cierran un modal.
//
// Y si otro handler cancela el envío (una validación propia de la pantalla),
// la marca se suelta al toque: ahí no salió nada.

const ESPERA_MAXIMA_MS = 5000
const enVuelo = new Map()

function soltar(form) {
  clearTimeout(enVuelo.get(form))
  enVuelo.delete(form)
}

function metodo(form, submitter) {
  return (submitter?.getAttribute("formmethod") || form.getAttribute("method") || "get").toLowerCase()
}

function seCuida(form, submitter) {
  if (metodo(form, submitter) !== "post") return false  // PATCH y DELETE de Rails van como POST
  if ((submitter?.getAttribute("formtarget") || form.target) === "_blank") return false
  if (submitter?.hasAttribute("data-turbo-confirm") || form.hasAttribute("data-turbo-confirm")) return false
  return true
}

// Captura: corre antes que Turbo y que cualquier controller.
document.addEventListener("submit", (e) => {
  const form = e.target
  if (!(form instanceof HTMLFormElement) || !seCuida(form, e.submitter)) return

  if (enVuelo.has(form)) {
    e.preventDefault()
    e.stopImmediatePropagation()
    return
  }

  enVuelo.set(form, setTimeout(() => enVuelo.delete(form), ESPERA_MAXIMA_MS))
}, true)

// Burbuja en `window`, lo último que corre. Turbo frena la propagación de los
// que manda él, así que acá solo llegan los que van sin Turbo: si alguien les
// canceló el envío, no salió nada y la marca se va.
window.addEventListener("submit", (e) => {
  if (e.defaultPrevented && e.target instanceof HTMLFormElement) soltar(e.target)
})

document.addEventListener("turbo:submit-end", (e) => {
  if (e.target instanceof HTMLFormElement) soltar(e.target)
})

// Volver con «atrás» trae la página del bfcache tal como quedó, con la marca
// puesta: se suelta todo.
window.addEventListener("pageshow", () => {
  enVuelo.forEach((timer) => clearTimeout(timer))
  enVuelo.clear()
})
