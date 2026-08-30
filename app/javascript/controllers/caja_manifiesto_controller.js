import { Controller } from "@hotwired/stimulus"

// C21-04 · El formulario de una casa del manifiesto.
//
// Dos cosas, las dos dichas por Yusef:
//
//   · Elegir un tamaño pre-definido **pre-llena las medidas y manda el cursor
//     al peso** — *"te ponen solo el cursor a peso, porque es lo que le vas a
//     meter a ingresar, que es lo que hace falta"*.
//   · Las medidas **quedan editables**: *"ellos vienen y marcan EH y le
//     modifican una medida, porque la cortan… le decimos «EH cortada»"*. Por eso
//     el tamaño solo escribe los campos, no los bloquea.
//
// El volumen se muestra en vivo con el mismo divisor que usa el servidor
// (`VolumetricoCalculator::DIVISOR_LB`), para que el operario vea el número que
// le va a reportar al proveedor antes de guardar. La cuenta buena la hace el
// modelo: esto es display.
const DIVISOR_LB = 166.0

export default class extends Controller {
  static targets = ["tamano", "alto", "largo", "ancho", "peso", "volumen"]

  connect() {
    this._recalcular()
  }

  elegirTamano(e) {
    const { alto, largo, ancho } = e.target.dataset
    // Un tamaño sin medidas es «Especificar»: se mide a mano, así que no se
    // pisa lo que el operario ya tecleó.
    if (alto) this.altoTarget.value = alto
    if (largo) this.largoTarget.value = largo
    if (ancho) this.anchoTarget.value = ancho
    this._recalcular()
    if (this.hasPesoTarget) this.pesoTarget.focus()
  }

  medidaCambiada() {
    this._recalcular()
  }

  _recalcular() {
    if (!this.hasVolumenTarget) return
    const n = (t) => (this[`has${t}Target`] ? parseFloat(this[`${t.toLowerCase()}Target`].value) : NaN)
    const alto = n("Alto"), largo = n("Largo"), ancho = n("Ancho")
    const completo = [alto, largo, ancho].every((v) => v > 0)
    this.volumenTarget.textContent = completo
      ? (alto * largo * ancho / DIVISOR_LB).toFixed(2)
      : "—"
  }
}
