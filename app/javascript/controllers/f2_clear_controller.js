import { Controller } from "@hotwired/stimulus"

// PR-D1.e: F2 universal — limpia parámetros del elemento al que está
// adjunto este controller. Yusef pidió (2026-04-29 6:54pm) que F2
// sirva para limpiar parámetros en TODOS los módulos del sistema.
//
// Uso:
//   <form data-controller="f2-clear" ...>                                (modo form)
//   <form data-controller="f2-clear" data-f2-clear-submit-value="true">  (modo form + reload)
//   <div data-controller="f2-clear">                                     (modo "scope manual")
//     <input data-f2-clear-target="field" ...>
//   </div>
//
// Comportamiento:
//   - F2 → resetea inputs/selects/checkboxes via `form.reset()` (modo form)
//     o limpia los `data-f2-clear-target="field"` declarados (modo scope).
//   - Modo form + `submit_value=true`: además submitea el form (útil para
//     listados con filtros GET → "limpiar y recargar").
//
// SEGURIDAD (review feedback):
//   `data-f2-clear-submit-value` debe ser SIEMPRE renderizado server-side
//   (en una vista ERB), nunca derivado de user input. El submit auto
//   invoca `form.requestSubmit()` que respeta el CSRF token de Rails
//   (incluido por `form_with`), pero sigue siendo una acción originada en
//   el cliente. NO exponer este atributo a parámetros controlables por
//   el usuario (URL params, content del cliente reflejado en HTML, etc.).
//
// El controller intencionalmente NO escanea el DOM en modo "scope" — solo
// limpia los `[data-f2-clear-target="field"]` explícitos para evitar
// limpiar inputs no relacionados (review feedback: "could lead to
// unexpected behavior if the controller is placed on an element that has
// many descendants").
export default class extends Controller {
  static targets = [ "field" ]
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
      const firstInput = root.querySelector("input:not([type='hidden']), textarea, select")
      firstInput?.focus()
      if (this.submitValue) root.requestSubmit?.()
      return
    }

    // Modo scope manual: limpia ÚNICAMENTE los `field` targets declarados
    // explícitamente. No scanea descendientes para evitar el caso edge
    // donde el root tiene muchos inputs no relacionados.
    if (this.hasFieldTarget) {
      this.fieldTargets.forEach(el => this._clearField(el))
      this.fieldTargets[0]?.focus()
    }
  }

  _clearField(el) {
    if (el.tagName === "SELECT") {
      el.selectedIndex = 0
    } else if (el.type === "checkbox" || el.type === "radio") {
      el.checked = false
    } else {
      el.value = ""
    }
  }
}
