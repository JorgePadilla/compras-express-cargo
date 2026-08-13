import { Controller } from "@hotwired/stimulus"

// El switch de recolecta en /entrega_personal.
//
// A7-22. Yusef: "acá en la entrega personal le podés dar una opción que diga
// que va a ser una recolecta. **Antes de proveedores**". Es la misma pantalla:
// lo único que cambia es que aparecen los datos de la visita —a quién buscar, a
// qué teléfono, en qué horario— y que los pesos y medidas son aproximados.
//
// Los campos arrancan ocultos porque la mayoría de las entregas personales NO
// son recolectas: el cliente ya trajo la carga al mostrador.
export default class extends Controller {
  static targets = ["switch", "detalle"]

  connect() {
    this.alternar()
  }

  alternar() {
    if (!this.hasDetalleTarget || !this.hasSwitchTarget) return
    this.detalleTarget.classList.toggle("hidden", !this.switchTarget.checked)
  }
}
