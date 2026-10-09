import { Controller } from "@hotwired/stimulus"

// C17-02: el mini-form de la franja lleva el tracking que había en pantalla
// cuando la franja cargó — y la franja solo recarga al elegir cliente o al
// limpiar. Si el operario corrigió el tracking después, lo que viaja es viejo.
// Al enviar, se copia el del formulario grande. En /entrega_personal no hay
// campo de tracking (se genera al guardar): queda vacío y la tarea del cliente.
export default class extends Controller {
  static targets = ["tracking"]

  refrescarTracking() {
    if (!this.hasTrackingTarget) return

    const campo = document.getElementById("paquete_tracking")
    const valor = campo ? campo.value.trim().toUpperCase() : ""
    if (valor !== "") this.trackingTarget.value = valor
  }
}
