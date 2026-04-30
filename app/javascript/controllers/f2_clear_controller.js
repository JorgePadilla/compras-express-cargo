import { Controller } from "@hotwired/stimulus"

// PR-D1.e: F2 universal — limpia parámetros de búsqueda/filtros del scope
// donde se aplica este controller. Yusef pidió (2026-04-29 6:54pm) que F2
// sirva para limpiar parámetros en TODOS los módulos del sistema.
//
// Uso:
//   <form data-controller="f2-clear" ...>
//
// Comportamiento:
//   - F2 → resetea todos los inputs/selects/checkboxes del form al valor
//     default (lo que hace `form.reset()`).
//   - Si el form tiene `data-f2-clear-submit-value="true"`, además
//     submitea el form (útil para listados con filtros vía GET, donde
//     limpiar = recargar sin params).
//   - Si NO está sobre un form, busca todos los inputs descendientes
//     y los vacía (textareas, text fields, selects).
//
// No se activa cuando el foco está en un input del propio scope para
// permitir typing literal de F2 en casos raros (no debería pasar pero
// preservamos el comportamiento del F2 viejo en /etiquetar y /paquetes).
export default class extends Controller {
  static values = { submit: { type: Boolean, default: false } }

  connect() {
    this._onKey = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this._onKey)
  }

  disconnect() {
    document.removeEventListener("keydown", this._onKey)
  }

  handleKeydown(e) {
    if (e.key !== "F2") return
    e.preventDefault()
    this.clear()
  }

  clear() {
    const root = this.element

    if (root.tagName === "FORM") {
      root.reset()
      // Foco al primer input visible para que el usuario siga escribiendo.
      const firstInput = root.querySelector("input:not([type='hidden']), textarea, select")
      firstInput?.focus()
      if (this.submitValue) root.requestSubmit?.()
    } else {
      // Limpia inputs descendientes individuales.
      root.querySelectorAll("input[type='text'], input[type='search'], input[type='number'], textarea")
          .forEach(el => { el.value = "" })
      root.querySelectorAll("select").forEach(el => { el.selectedIndex = 0 })
      root.querySelectorAll("input[type='checkbox'], input[type='radio']")
          .forEach(el => { el.checked = false })
      const firstInput = root.querySelector("input, textarea, select")
      firstInput?.focus()
    }
  }
}
