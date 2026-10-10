import { Controller } from "@hotwired/stimulus"

// PR-F1.3 · Mientras se carga un CAI, muestra los dos números completos de 16
// dígitos que va a cubrir —`EEE-PPP-TT-NNNNNNNN`, Acuerdo 481-2017 Art. 10
// num. 7— y cuántos documentos son. Es lo que se compara contra la resolución
// de la SAR: un dígito mal tipeado en el rango se ve acá antes de guardar.
//
// El `EEE-PPP` sale del `data-prefijo` de la opción elegida del punto; el
// servidor vuelve a validar todo, esto solo muestra.
export default class extends Controller {
  static targets = ["punto", "tipo", "inicio", "fin", "desde", "hasta", "cantidad"]

  connect() { this.actualizar() }

  actualizar() {
    const opcion = this.puntoTarget.selectedOptions[0]
    const prefijo = opcion && opcion.dataset.prefijo
    const tipo = this.tipoTarget.value
    const inicio = this.entero(this.inicioTarget.value)
    const fin = this.entero(this.finTarget.value)

    this.desdeTarget.textContent = this.numero(prefijo, tipo, inicio)
    this.hastaTarget.textContent = this.numero(prefijo, tipo, fin)
    this.cantidadTarget.textContent = (inicio && fin && fin >= inicio)
      ? `${(fin - inicio + 1).toLocaleString("es-HN")} documentos`
      : "—"
  }

  entero(valor) {
    const n = Number.parseInt(valor, 10)
    return Number.isInteger(n) && n >= 1 && n <= 99999999 ? n : null
  }

  numero(prefijo, tipo, secuencia) {
    if (!prefijo || !tipo || !secuencia) return "—"
    return `${prefijo}-${tipo}-${String(secuencia).padStart(8, "0")}`
  }
}
