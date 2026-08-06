import { Controller } from "@hotwired/stimulus"

// PR-13.e: el modal donde un supervisor autoriza la emisión de una nota.
//
// Reemplaza al `turbo_confirm` que había antes: un "¿continuar?" no deja
// registro de quién dijo que sí ni por qué, y emitir una nota de crédito es
// devolverle plata al cliente.
export default class extends Controller {
  static targets = ["dialog"]

  abrir() {
    this.dialogTarget.showModal()
  }

  cerrar() {
    this.dialogTarget.close()
  }
}
