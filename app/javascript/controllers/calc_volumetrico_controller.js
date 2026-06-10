import { Controller } from "@hotwired/stimulus"

// Calculadora en vivo de /etiquetar: a partir de UNA medida (alto × largo ×
// ancho en pulgadas) + peso real, muestra las tres representaciones del
// spreadsheet de Yusef. Espejo de app/services/volumetrico_calculator.rb
// (la fuente de verdad testeada). Solo display — no toca peso_cobrar.
//
//   (A) USA→HN libra/volumen: VLbs = in³/166 con redondeo ½lb (.10/.60),
//       peso a cobrar = max(peso real, VLbs)              ← la más común
//   (B) USA→HN pie³:  ceil(in³/1728)                      (informativo)
//   (C) China→HN m³:  ceilTo2(in³ × 16.387064 / 1e6)      (informativo)
export default class extends Controller {
  static targets = [
    "peso", "alto", "largo", "ancho",
    "vlbs", "pesoCobrar", "pies", "metros", "in3"
  ]

  static DIVISOR_LB = 166
  static IN3_PER_FT3 = 1728
  static CM3_PER_IN3 = 16.387064
  static CM3_PER_M3 = 1_000_000

  connect() {
    // Recalcular tras un reset del form (F2 / limpiar) — reset no dispara input.
    this._form = this.element.closest("form")
    this._onReset = () => requestAnimationFrame(() => this.recalcular())
    if (this._form) this._form.addEventListener("reset", this._onReset)
    this.recalcular()
  }

  disconnect() {
    if (this._form) this._form.removeEventListener("reset", this._onReset)
  }

  recalcular() {
    const alto = this._num(this.altoTarget)
    const largo = this._num(this.largoTarget)
    const ancho = this._num(this.anchoTarget)
    const peso = this._num(this.pesoTarget)
    const in3 = alto * largo * ancho

    if (this.hasIn3Target) this.in3Target.textContent = in3 > 0 ? this._fmt(in3, 0) : "—"

    if (in3 <= 0) {
      // Sin medidas: solo peso real cuenta como peso a cobrar.
      this._set(this.vlbsTarget, "—")
      this._set(this.piesTarget, "—")
      this._set(this.metrosTarget, "—")
      this._set(this.pesoCobrarTarget, peso > 0 ? this._fmt(peso, 2) : "—")
      return
    }

    const vlbs = this.halfPound(in3 / this.constructor.DIVISOR_LB)
    const pesoCobrar = Math.max(peso, vlbs)

    this._set(this.vlbsTarget, this._fmt(vlbs, 1))
    this._set(this.pesoCobrarTarget, this._fmt(pesoCobrar, 2))
    this._set(this.piesTarget, String(this.piesCubicos(in3)))
    this._set(this.metrosTarget, this._fmt(this.metrosCubicos(in3), 2))
  }

  // ½ libra con umbrales .10/.60, en milésimas para evitar ruido de float.
  halfPound(x) {
    const m = Math.round(x * 1000)
    const entero = Math.floor(m / 1000)
    const frac = m - entero * 1000
    if (frac < 100) return entero
    if (frac < 600) return entero + 0.5
    return entero + 1
  }

  // pie³ siempre hacia arriba.
  piesCubicos(in3) {
    return Math.ceil(Number((in3 / this.constructor.IN3_PER_FT3).toFixed(6)))
  }

  // m³ con ceil a 2 decimales (toFixed(6) limpia el ruido antes del ceil).
  metrosCubicos(in3) {
    const m3 = (in3 * this.constructor.CM3_PER_IN3) / this.constructor.CM3_PER_M3
    return Math.ceil(Number((m3 * 100).toFixed(6))) / 100
  }

  _num(target) {
    if (!target) return 0
    const v = parseFloat(target.value)
    return Number.isFinite(v) && v > 0 ? v : 0
  }

  _set(target, text) {
    if (target) target.textContent = text
  }

  _fmt(n, decimals) {
    return Number(n).toLocaleString("en-US", {
      minimumFractionDigits: decimals,
      maximumFractionDigits: decimals
    })
  }
}
