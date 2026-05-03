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
  // para NO cambiar el width del botón ni mover los elementos vecinos.
  // Antes mostrábamos "✓ Copiado" (~70px) → causaba layout shift.
  showFeedback(state) {
    if (!this.hasButtonTarget) return

    const original = this.buttonTarget.innerHTML
    const originalTitle = this.buttonTarget.getAttribute("title")
    const symbol = state === "ok" ? "✓" : "✕"
    const colorClass = state === "ok"
      ? "text-cec-teal dark:text-cec-teal-light"
      : "text-red-600 dark:text-red-400"
    const newTitle = state === "ok" ? "Copiado" : "Error al copiar"

    this.buttonTarget.innerHTML =
      `<span class="text-sm leading-none font-bold ${colorClass}">${symbol}</span>`
    this.buttonTarget.setAttribute("title", newTitle)
    this.buttonTarget.disabled = true

    setTimeout(() => {
      this.buttonTarget.innerHTML = original
      this.buttonTarget.setAttribute("title", originalTitle || "Copiar")
      this.buttonTarget.disabled = false
    }, this.feedbackDurationValue)
  }
}
