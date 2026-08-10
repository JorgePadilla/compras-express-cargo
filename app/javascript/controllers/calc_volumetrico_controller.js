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
    "vlbs", "pesoCobrar", "pies", "metros", "in3", "avisoVolumetrico"
  ]

  // PR-C6.41: el trato de mayorista de Yusef — "solo se les cobra volumen, no
  // peso" — es por cliente Y por servicio, y los dos cambian en vivo: el
  // cliente sale del autocomplete y en /entrega_personal el tipo de envío es un
  // select. Por eso son `values` que la pantalla reescribe, no algo estático.
  //
  // Si esto se separara del servidor, el operario vería un peso a cobrar y la
  // pre-factura le cobraría otro — el defecto que PR-10.a vino a cerrar.
  static values = {
    soloVolumetricoEn: { type: Array, default: [] },
    tipoEnvioId: { type: Number, default: 0 }
  }

  soloVolumetricoEnValueChanged() { this.recalcular() }
  tipoEnvioIdValueChanged() { this.recalcular() }

  get _soloVolumetrico() {
    return this.tipoEnvioIdValue > 0 &&
      this.soloVolumetricoEnValue.map(Number).includes(this.tipoEnvioIdValue)
  }

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
      // Sin medidas: solo peso real cuenta como peso a cobrar. Espejo del guard
      // de cero de VolumetricoCalculator — ni con el trato de mayorista se
      // cobra 0 por falta de medidas.
      this._set(this.vlbsTarget, "—")
      this._set(this.piesTarget, "—")
      this._set(this.metrosTarget, "—")
      this._set(this.pesoCobrarTarget, peso > 0 ? this._fmt(peso, 2) : "—")
      this._marcarVolumetrico(false)
      return
    }

    const vlbs = this.halfPound(in3 / this.constructor.DIVISOR_LB)
    const soloVolumetrico = this._soloVolumetrico
    const pesoCobrar = soloVolumetrico ? vlbs : Math.max(peso, vlbs)
    this._marcarVolumetrico(soloVolumetrico)

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

  // Deja ver POR QUÉ el peso a cobrar no es el de la báscula. Sin el aviso, el
  // operario lee un número más bajo y no sabe si el sistema se equivocó.
  _marcarVolumetrico(activo) {
    this.element.dataset.soloVolumetrico = activo
    if (this.hasAvisoVolumetricoTarget) {
      this.avisoVolumetricoTarget.classList.toggle("hidden", !activo)
    }
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
