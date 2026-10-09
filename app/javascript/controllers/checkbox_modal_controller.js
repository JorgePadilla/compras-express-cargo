import { Controller } from "@hotwired/stimulus"

// Patrón "checkbox que abre un modal" usado en el form del paquete
// (Recolecta, Retener Miami, Cambio de Servicio). El checkbox queda
// como flag visible en el form, y al marcarlo se abre un modal con
// los campos relacionados (zona, motivos, etc.). Cancelar desmarca
// el check; Confirmar lo mantiene marcado.
//
// Markup:
//   <div data-controller="checkbox-modal">
//     <input type="checkbox"
//            data-checkbox-modal-target="checkbox"
//            data-action="change->checkbox-modal#onChange">
//     <dialog data-checkbox-modal-target="dialog" class="rounded-lg p-0 ...">
//       <!-- contenido del modal -->
//       <button data-action="checkbox-modal#cancel">Cancelar</button>
//       <button data-action="checkbox-modal#confirm">Confirmar</button>
//     </dialog>
//   </div>
//
// Si el checkbox arranca marcado (ya estaba flagged en DB), el dialog
// NO se abre solo. Solo cuando el usuario lo marca explícitamente.
//
// La excepción es explícita y por valor: `abrir-al-cargar-value="true"`, para
// cuando la pantalla se abrió *para* eso. PR-C6.23: el modal de duplicado de
// /etiquetar tiene un botón "Cambio de servicio", y Yusef pidió que "me tire
// aquí de un solo a esto" — o sea que llegar y tener que marcar el check otra
// vez es el clic que él estaba contando.
export default class extends Controller {
  static targets = ["checkbox", "dialog"]
  static values = { abrirAlCargar: Boolean }

  connect() {
    if (!this.abrirAlCargarValue) return
    if (!this.hasCheckboxTarget) return

    this.checkboxTarget.checked = true
    this.openDialog()
  }

  onChange() {
    if (this.checkboxTarget.checked) {
      this.openDialog()
    }
    // Si lo desmarcó manualmente, no hacemos nada — los campos del
    // modal pueden quedar con valores y el usuario los limpia si quiere.
  }

  cancel(e) {
    e?.preventDefault()
    this.checkboxTarget.checked = false
    this.closeDialog()
  }

  confirm(e) {
    e?.preventDefault()
    this.closeDialog()
  }

  openDialog() {
    if (!this.hasDialogTarget) return
    if (this.dialogTarget.showModal) {
      this.dialogTarget.showModal()
    } else {
      this.dialogTarget.classList.remove("hidden")
    }
    // Foco en el primer input del modal para que se pueda usar con teclado.
    const firstInput = this.dialogTarget.querySelector("input, select, textarea, button")
    firstInput?.focus()
  }

  closeDialog() {
    if (!this.hasDialogTarget) return
    if (this.dialogTarget.close) {
      this.dialogTarget.close()
    } else {
      this.dialogTarget.classList.add("hidden")
    }
  }
}
