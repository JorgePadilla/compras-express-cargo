import { Controller } from "@hotwired/stimulus"

// PR-13.d: el modal donde el supervisor autoriza un cambio en una línea.
//
// Un solo modal para toda la tabla: al abrirlo se le apunta la acción del form
// a la línea que corresponde. Renderizar uno por fila sería el mismo markup
// repetido N veces por cada pre-factura.
export default class extends Controller {
  static targets = [
    "dialog", "form", "concepto", "actual",
    "accion", "campoValor", "etiquetaValor", "valor", "modo"
  ]
  static values = { urlTemplate: String }

  abrir(event) {
    const p = event.params

    this.formTarget.action = this.urlTemplateValue.replace("ITEM_ID", p.itemId)
    this.conceptoTarget.textContent = p.concepto
    this.actualTarget.textContent =
      `Hoy: ${p.peso} lb · L. ${p.precio}/lb · L. ${p.subtotal}`

    this.formTarget.reset()
    // `reset()` devuelve el radio a su default del HTML, así que la etiqueta y
    // la visibilidad del campo se recalculan después.
    this.cambiarAccion()
    this.dialogTarget.showModal()
  }

  cerrar() {
    this.dialogTarget.close()
  }

  cambiarAccion() {
    const accion = this.accionTargets.find((r) => r.checked)?.value

    // Quitar la línea no lleva valor: el monto es el que ya tiene.
    this.campoValorTarget.hidden = accion === "eliminar"
    this.valorTarget.required = accion !== "eliminar"

    // El selector %/L. solo tiene sentido para el descuento.
    this.modoTarget.hidden = accion !== "descuento"

    this.etiquetaValorTarget.textContent = {
      descuento: "Descuento",
      precio: "Precio por libra nuevo",
      peso: "Peso a cobrar nuevo",
      eliminar: ""
    }[accion]
  }
}
