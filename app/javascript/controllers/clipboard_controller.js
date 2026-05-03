import { Controller } from "@hotwired/stimulus"

// PR-D4.c — Copy-to-clipboard reusable. Yusef pidió botones de copy
// en varios campos del detalle del paquete (tracking, recepción, guía,
// código de cliente, etc.).
//
// Markup esperado:
//   <div data-controller="clipboard" data-clipboard-text-value="VALOR_A_COPIAR">
//     <span>VALOR_A_COPIAR</span>
//     <button data-action="clipboard#copy"
//             data-clipboard-target="button"
//             title="Copiar">
//       <svg>📋</svg>
//     </button>
//   </div>
//
// Al click, copia `text-value` al clipboard y muestra feedback temporal
// ("Copiado!" durante 1.5s).
export default class extends Controller {
  static values = { text: String, feedbackDuration: { type: Number, default: 1500 } }
  static targets = ["button", "label"]

  copy(event) {
    event.preventDefault()
    const text = this.textValue
    if (!text) return

    navigator.clipboard.writeText(text).then(
      () => this.showFeedback("ok"),
      () => this.showFeedback("error")
    )
  }

  // PR-D4.c follow-up: swap solo el ícono dentro del mismo `w-5 h-5`
  // para NO cambiar el width del botón ni la altura del baseline.
  // Usamos SVGs heroicon (check / x-mark) en w-3.5 h-3.5 — mismas
  // dimensiones que el clipboard-document original → zero layout shift.
  // Versiones con texto unicode "✓" causaban shift de línea base porque
  // el caracter tiene altura distinta al SVG.
  showFeedback(state) {
    if (!this.hasButtonTarget) return

    const original = this.buttonTarget.innerHTML
    const originalTitle = this.buttonTarget.getAttribute("title")
    const newTitle = state === "ok" ? "Copiado" : "Error al copiar"
    const newHTML = state === "ok" ? this.checkSvg() : this.xMarkSvg()

    this.buttonTarget.innerHTML = newHTML
    this.buttonTarget.setAttribute("title", newTitle)
    this.buttonTarget.disabled = true

    setTimeout(() => {
      this.buttonTarget.innerHTML = original
      this.buttonTarget.setAttribute("title", originalTitle || "Copiar")
      this.buttonTarget.disabled = false
    }, this.feedbackDurationValue)
  }

  checkSvg() {
    return '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="2.5" stroke="currentColor" class="w-3.5 h-3.5 text-cec-teal dark:text-cec-teal-light"><path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5" /></svg>'
  }

  xMarkSvg() {
    return '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="2.5" stroke="currentColor" class="w-3.5 h-3.5 text-red-600 dark:text-red-400"><path stroke-linecap="round" stroke-linejoin="round" d="M6 18 18 6M6 6l12 12" /></svg>'
  }
}
