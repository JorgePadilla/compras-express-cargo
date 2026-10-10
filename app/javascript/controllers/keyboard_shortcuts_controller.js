import { Controller } from "@hotwired/stimulus"

// Global keyboard shortcuts handler. Mounted en <body> via
// data-controller="keyboard-shortcuts".
//
// Cualquier elemento con `data-shortcut="F1"` en la página recibe un
// click cuando se presiona la tecla. Funciona con <a>, <button>,
// <input type="submit">.
//
// ── La convención: la hoja de Yusef (C30-02, 2026-10-09) ──────────────────
//
// Yusef la escribió a mano en una hoja y se la dio a Jorge: *"F8 → Guardar ·
// F9 → Guardar e Imprimir · F2 → Limpiar · F5 → Agregar · F4 → Imprimir ·
// F1 → Crear"*. Y en voz alta: *"el F10 a guardar, te lo cambio también, es
// la F8… en casi todo es F8 guardar, F9 guardar e imprimir, F2 es limpiar…
// F5 es agregar… crear puede ser F1 en todo, F4 imprimir en casi que todo"*.
//
//   F1  → Nuevo / Crear: abre el formulario de uno nuevo  (antes F7)
//   F2  → Cancelar / Limpiar / Volver
//   F3  → solo /etiquetar: el tracking secundario (handler propio)
//   F4  → Imprimir el documento de esta pantalla
//   F5  → Agregar una línea (la casa del manifiesto, el paquete de la pre-alerta)
//   F6  → Editar (entrar a edit)
//   F8  → Guardar: y también finalizar, confirmar, aplicar  (antes F10)
//   F9  → Imprimir, y «hacer algo **e imprimir**»
//   F11 → Finalizar la sesión de /etiquetar (la eligió Yusef, `C22-02`)
//
// **Cambia `C23-13`**, que había ordenado la app leyendo lo que hacía —F7
// nuevo, F8 Excel, F10 guardar— y que esta hoja corrige con el uso de ellos:
// F8 deja de ser Excel (**el Excel queda sin tecla**, `RP-75`), F10 y F7
// quedan libres. Lo demás no se movió.
//
// `C23-13` sigue valiendo en lo otro que dejó: **F4 y F9 imprimen las dos**
// —F4 el documento de la pantalla (el manifiesto, el Warehouse Receipt), F9 el
// de la acción que uno acaba de hacer— y F11 se probó a mano en /etiquetar.
//
// `test/lint/teclas_por_familia_test.rb` lo traba: una tecla no puede
// significar dos cosas distintas.
//
// ── F1 y el navegador ─────────────────────────────────────────────────────
//
// En Windows, F1 abre la **Ayuda de Chrome** si nadie le hace
// `preventDefault()` en el `keydown`. Por eso F1 se frena **siempre**, haya o
// no un botón «Nuevo» en la pantalla y esté o no el foco en un campo — igual
// que F2. ⚠️ Esto hay que verificarlo **a mano** en las máquinas Windows del
// equipo: el Chrome de los tests no abre la Ayuda, así que un test verde no lo
// prueba. Y en Mac las teclas F se aprietan con `fn` (o con la opción «usar
// F1, F2… como teclas de función» del sistema).
//
// Reglas:
// - Si el foco está en un input/textarea editable y la tecla no es F1 ni F2,
//   se ignora (evita interferir con la escritura).
// - F2 y F1 siempre disparan, aunque esté tipeando: F2 por consistencia con
//   f2_clear_controller, y F1 porque es la que el navegador se roba.
// - preventDefault para que el browser no abra menús nativos
//   (algunos navegadores usan F-keys para devtools / context menus).
// Las que disparan aunque el foco esté en un campo.
const SIEMPRE = [ "F1", "F2" ]

export default class extends Controller {
  connect() {
    this.handler = this.handle.bind(this)
    document.addEventListener("keydown", this.handler)
  }

  disconnect() {
    document.removeEventListener("keydown", this.handler)
  }

  handle(e) {
    if (!/^F\d{1,2}$/.test(e.key)) return

    // F1: la Ayuda del navegador se frena siempre, antes de mirar nada más.
    if (e.key === "F1") e.preventDefault()

    const target = document.querySelector(`[data-shortcut="${e.key}"]`)
    if (!target) return

    // Si está editando y la tecla no es de las que siempre valen, no interrumpir.
    if (!SIEMPRE.includes(e.key) && this.isEditing(e.target)) return

    e.preventDefault()
    target.click()
  }

  isEditing(el) {
    if (!el) return false
    if (el.isContentEditable) return true
    const tag = el.tagName
    if (tag !== "INPUT" && tag !== "TEXTAREA" && tag !== "SELECT") return false
    if (tag === "INPUT" && [ "checkbox", "radio", "button", "submit" ].includes(el.type)) return false
    return true
  }
}
