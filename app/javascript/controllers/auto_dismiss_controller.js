import { Controller } from "@hotwired/stimulus"

// Un aviso que se va solo.
//
// PR-A11Y.5 · Se iban todos a los 3 segundos, los errores también, y no había
// cómo frenarlos: quien lee despacio, o con zoom, se quedaba sin el mensaje
// (WCAG 2.2.1, tiempo suficiente). Ahora:
//   · con el mouse o el foco encima, espera; al salir, vuelve a contar
//   · los errores llevan 10 s (`data-auto-dismiss-delay-value="10000"` en los
//     layouts y en `shared/_flash`); los avisos de «listo» siguen en 3
// El lector de pantalla ya lo oyó al aparecer (`anunciar.js`, regiones fijas),
// así que irse no le quita nada.
export default class extends Controller {
  static values = { delay: { type: Number, default: 3000 } }

  connect() {
    this._pausar = () => this._cancelar()
    this._reanudar = (e) => {
      if (e.type === "focusout" && this.element.contains(e.relatedTarget)) return
      this._programar()
    }
    this.element.addEventListener("mouseenter", this._pausar)
    this.element.addEventListener("focusin", this._pausar)
    this.element.addEventListener("mouseleave", this._reanudar)
    this.element.addEventListener("focusout", this._reanudar)
    this._programar()
  }

  disconnect() {
    this._cancelar()
    this.element.removeEventListener("mouseenter", this._pausar)
    this.element.removeEventListener("focusin", this._pausar)
    this.element.removeEventListener("mouseleave", this._reanudar)
    this.element.removeEventListener("focusout", this._reanudar)
  }

  _programar() {
    this._cancelar()
    this.timeout = setTimeout(() => {
      this.element.style.transition = "opacity 0.3s ease-out"
      this.element.style.opacity = "0"
      this.timeout = setTimeout(() => this.element.remove(), 300)
    }, this.delayValue)
  }

  _cancelar() {
    if (this.timeout) clearTimeout(this.timeout)
    this.timeout = null
    this.element.style.opacity = ""
  }
}
