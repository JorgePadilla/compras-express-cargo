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
  static targets = ["button", "iconIdle", "iconOk", "iconErr"]

  copy(event) {
    event.preventDefault()
    const text = this.textValue
    if (!text) return

    navigator.clipboard.writeText(text).then(
      () => this.showFeedback("ok"),
      () => this.showFeedback("err")
    )
  }

  // PR-D4.c follow-up v3: los 3 íconos viven SIEMPRE en el DOM
  // (idle/ok/err). El controller solo toggle-ea su visibilidad con CSS
  // (clases `hidden` / `inline-flex`) — cero re-render del innerHTML del
  // button → cero reflow → cero shift de los elementos vecinos.
  showFeedback(state) {
    if (!this.hasIconIdleTarget || !this.hasIconOkTarget || !this.hasIconErrTarget) return

    const showKey = state === "ok" ? "ok" : "err"
    this.iconIdleTarget.classList.add("hidden")
    this.iconOkTarget.classList.toggle("hidden", showKey !== "ok")
    this.iconErrTarget.classList.toggle("hidden", showKey !== "err")

    if (this.hasButtonTarget) {
      this.buttonTarget.setAttribute("title", state === "ok" ? "Copiado" : "Error al copiar")
    }

    setTimeout(() => {
      this.iconIdleTarget.classList.remove("hidden")
      this.iconOkTarget.classList.add("hidden")
      this.iconErrTarget.classList.add("hidden")
      if (this.hasButtonTarget) this.buttonTarget.setAttribute("title", "Copiar")
    }, this.feedbackDurationValue)
  }
}
