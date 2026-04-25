import { Controller } from "@hotwired/stimulus"

// Anima el texto del elemento de 0 → target en una duración corta.
// Uso:
//   <span data-controller="count-up"
//         data-count-up-target-value="1234"
//         data-count-up-decimals-value="0"
//         data-count-up-prefix-value="L "
//         data-count-up-suffix-value="">0</span>
//
// Respeta `prefers-reduced-motion`: si está activo, salta directo al valor
// final sin animar.
export default class extends Controller {
  static values = {
    target:   { type: Number, default: 0 },
    decimals: { type: Number, default: 0 },
    duration: { type: Number, default: 800 },
    prefix:   { type: String, default: "" },
    suffix:   { type: String, default: "" }
  }

  connect() {
    const reduce = window.matchMedia?.("(prefers-reduced-motion: reduce)").matches
    if (reduce) {
      this.element.textContent = this._format(this.targetValue)
      return
    }

    const start = performance.now()
    const end   = this.targetValue
    const dur   = this.durationValue

    const step = (now) => {
      const t = Math.min(1, (now - start) / dur)
      const eased = 1 - Math.pow(1 - t, 3) // easeOutCubic
      const value = end * eased
      this.element.textContent = this._format(value)
      if (t < 1) this._raf = requestAnimationFrame(step)
    }
    this._raf = requestAnimationFrame(step)
  }

  disconnect() {
    if (this._raf) cancelAnimationFrame(this._raf)
  }

  _format(num) {
    const n = Number(num).toFixed(this.decimalsValue)
    const withThousands = Number(n).toLocaleString("es-HN", {
      minimumFractionDigits: this.decimalsValue,
      maximumFractionDigits: this.decimalsValue
    })
    return `${this.prefixValue}${withThousands}${this.suffixValue}`
  }
}
