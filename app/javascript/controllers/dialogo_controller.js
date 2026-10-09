import { Controller } from "@hotwired/stimulus"

// Abrir y cerrar un `<dialog>`. Nada más.
//
// PR-C6.42. En el proyecto ya hay seis controllers de modal, y todos repiten
// estas cuatro líneas envueltas en la lógica de su pantalla. Este no sabe de
// ninguna: se le pone al contenedor, el botón dispara `abrir`, y adentro va
// cualquier form.
//
//   <div data-controller="dialogo">
//     <button data-action="dialogo#abrir">…</button>
//     <dialog data-dialogo-target="dialogo">…</dialog>
//   </div>
//
// El fallback a `.hidden` es porque `showModal()` no existe en jsdom ni en
// navegadores viejos, y los system tests no deberían depender de eso.
export default class extends Controller {
  static targets = ["dialogo"]

  abrir() {
    if (!this.hasDialogoTarget) return

    if (this.dialogoTarget.showModal) this.dialogoTarget.showModal()
    else this.dialogoTarget.classList.remove("hidden")
  }

  cerrar() {
    if (!this.hasDialogoTarget) return

    if (this.dialogoTarget.close) this.dialogoTarget.close()
    else this.dialogoTarget.classList.add("hidden")
  }
}
