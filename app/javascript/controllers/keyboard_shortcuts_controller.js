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
// ── Cuáles valen con el foco en un campo ──────────────────────────────────
//
// Las teclas F no escriben nada: la regla de «no interrumpir al que escribe»
// está para que una tecla no se lleve lo tecleado a otra pantalla sin querer.
// Éstas valen aunque el foco esté en un input/select/textarea:
//
//   F1 → la Ayuda del navegador se frena siempre (arriba).
//   F2 → volver / limpiar, por consistencia con `f2_clear_controller`.
//   F8 → **guardar**: el gesto natural es *«lleno el último campo y aprieto
//        F8»*. Con la regla vieja eso no hacía nada en ningún formulario
//        genérico —en silencio—, y Yusef lo iba a leer como roto (C30-02).
//
// F9 **no**, y es a propósito. Las F9 que este handler aprieta son «Descargar
// PDF» de las fichas y el «PDF» de /paquetes, que exporta el filtro **ya
// aplicado**: desde adentro de la búsqueda, a medio escribir, bajaría el PDF
// de un filtro que no es el que se ve en el campo, y un link sin `_blank`
// se llevaría lo escrito. Donde F9 es «guardar e imprimir» desde un campo
// —/etiquetar, /entrega_personal, medición, las casas del manifiesto— la
// pantalla la escucha con su propio handler, que ya vale en los campos.
//
// Las demás (F4, F5, F6) siguen sin disparar mientras se escribe.
//
// Y F8 no aprieta nada **detrás** de un modal abierto: con el foco en el PIN
// del supervisor, por ejemplo, guardaría el formulario de atrás. Antes lo
// frenaba la regla del campo; ahora lo frena esto. F1 tampoco: «Nuevo» detrás
// de un modal se lleva la pantalla con el modal a medio contestar.
//
// PR-C30.11 · «Modal abierto» no es solo `<dialog open>`. La app tiene modales
// hechos con un `div` fijo que se muestra sacándole `hidden` —el «Confirmar»
// compartido, buscar y mover paquetes en el portal, el duplicado de
// /etiquetar—, y con ésos F8 apretaba el «Guardar» de atrás. Los dos tipos
// llevan ahora la misma marca: `<dialog open>`, o `aria-modal="true"` **y
// visible** (sin `hidden`, que en ellos es lo que los cierra). Un modal nuevo
// hecho con `div` tiene que llevar `role="dialog" aria-modal="true"`.
//
// ── PR-C30.15 · El alcance: un formulario que se queda con las teclas ─────
//
// Un `[data-teclas-alcance]` **visible** es dueño de las teclas F mientras
// está a la vista: la tecla se busca **solo adentro** de él, y si ahí no hay
// botón con esa tecla, se frena (`preventDefault`) y no pasa nada. Nace en la
// ficha del manifiesto, donde la tarjeta de detalles se abre en formulario en
// el lugar (Jorge, 2026-10-10: *"I want to edit the current view"*) y la ficha
// ya tenía sus propias teclas, más arriba en el DOM:
//
//   F8 → «Guardar» de la tarjeta, no «Solo Finalizar» (que también es F8).
//   F2 → «Cancelar» de la tarjeta, no «Volver» a la lista.
//   F5 → no recarga la página y se lleva lo tecleado.
//   F6 → no vuelve a pedir el formulario (ni reabre nada) encima del abierto.
//
// La regla del modal sigue valiendo **después**: con «Eliminar paquetes»
// abierto, F8 no guarda la tarjeta de atrás.
//
// ⚠️ Una pantalla que escucha F8 ella misma (/etiquetar, medición, el editor
// de pre-alertas) **no puede** tener un botón con `data-shortcut="F8"`: el
// global le haría click además y guardaría dos veces. Sus botones van con
// `shortcut_label_only`, y `teclas_propias_sin_doble_disparo_test` lo traba.
//
// Reglas:
// - preventDefault para que el browser no abra menús nativos
//   (algunos navegadores usan F-keys para devtools / context menus).
// Las que disparan aunque el foco esté en un campo.
const SIEMPRE = [ "F1", "F2", "F8" ]
// Las que no aprietan nada que esté detrás de un modal abierto.
const DETRAS_DE_UN_MODAL_NO = [ "F1", "F8" ]

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

    // PR-C30.15 · Con un alcance a la vista, la tecla es de él o de nadie.
    const alcance = this.alcanceVisible()
    const target = (alcance || document).querySelector(`[data-shortcut="${e.key}"]`)
    if (!target) {
      if (alcance) e.preventDefault()
      return
    }

    // Si está editando y la tecla no es de las que siempre valen, no interrumpir.
    if (!SIEMPRE.includes(e.key) && this.isEditing(e.target)) return

    // F8 y F1 no aprietan lo de atrás de un modal abierto.
    const modal = this.modalAbierto()
    if (DETRAS_DE_UN_MODAL_NO.includes(e.key) && modal && !modal.contains(target)) return

    e.preventDefault()
    target.click()
  }

  // `<dialog open>`, o un modal hecho con `div` (`aria-modal="true"`) que se
  // está viendo. `getClientRects()` y no `offsetParent`: estos modales son
  // `position: fixed`, y un fijo visible tiene `offsetParent` en null igual
  // que uno escondido. Con `hidden` (`display: none`) no tiene rectángulos.
  modalAbierto() {
    const candidatos = document.querySelectorAll("dialog[open], [aria-modal='true']")
    return Array.from(candidatos).find((el) => el.getClientRects().length > 0)
  }

  // El primer `[data-teclas-alcance]` que se está viendo. Visible por
  // `getClientRects()`, igual que `modalAbierto()`.
  alcanceVisible() {
    const candidatos = document.querySelectorAll("[data-teclas-alcance]")
    return Array.from(candidatos).find((el) => el.getClientRects().length > 0)
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
