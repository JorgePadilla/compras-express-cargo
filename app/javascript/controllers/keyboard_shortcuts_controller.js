import { Controller } from "@hotwired/stimulus"

// Global keyboard shortcuts handler. Mounted en <body> via
// data-controller="keyboard-shortcuts".
//
// Cualquier elemento con `data-shortcut="F7"` en la página recibe un
// click cuando se presiona la tecla. Funciona con <a>, <button>,
// <input type="submit">.
//
// Convenciones del sistema (alineadas con f2_clear, paquetes_shortcuts,
// pre_alerta_editor, etiquetar):
//   F2  → Cancelar / Limpiar / Volver
//   F4  → Imprimir
//   F6  → Editar (entrar a edit)
//   F7  → Nuevo / Crear nuevo recurso
//   F8  → Excel export
//   F9  → PDF export
//   F10 → Guardar (submit form)
//
// Reglas:
// - Si el foco está en un input/textarea editable y la tecla NO es F2,
//   se ignora (evita interferir con la escritura).
// - F2 siempre dispara, aunque esté tipeando (consistente con
//   f2_clear_controller existente).
// - preventDefault para que el browser no abra menús nativos
//   (algunos navegadores usan F-keys para devtools / context menus).
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

    const target = document.querySelector(`[data-shortcut="${e.key}"]`)
    if (!target) return

    // Si está editando y la tecla NO es F2, no interrumpir.
    if (e.key !== "F2" && this.isEditing(e.target)) return

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
