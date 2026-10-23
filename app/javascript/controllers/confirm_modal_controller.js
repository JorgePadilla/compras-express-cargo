import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["root", "title", "message", "confirmBtn", "cancelBtn", "icon"]

  connect() {
    this._pending = null
    // PR-A11Y.1 · Enter no confirma desde el documento: lo aprieta el botón
    // que tiene el foco, como cualquier botón. Antes un Enter en «Cancelar»
    // (donde abre el foco, justamente para no confirmar sin querer)
    // confirmaba igual, y el botón de confirmar es rojo por defecto.
    //
    // Tab no se escapa a la página de atrás: va y vuelve entre los dos botones.
    this._onKeydown = (e) => {
      if (this.rootTarget.classList.contains("hidden")) return
      if (e.key === "Escape") {
        e.preventDefault()
        this.cancel()
      } else if (e.key === "Tab") {
        e.preventDefault()
        const siguiente = document.activeElement === this.cancelBtnTarget ? this.confirmBtnTarget : this.cancelBtnTarget
        siguiente.focus()
      }
    }
    document.addEventListener("keydown", this._onKeydown)

    // Expose a global helper that returns a Promise<boolean>.
    window.cecConfirm = (message, options = {}) => this.ask(message, options)
  }

  disconnect() {
    document.removeEventListener("keydown", this._onKeydown)
    if (window.cecConfirm && window.cecConfirm.__owner === this) {
      delete window.cecConfirm
    }
  }

  ask(message, { title = "Confirmar", confirmLabel = "Confirmar", cancelLabel = "Cancelar", danger = true } = {}) {
    this.titleTarget.textContent = title
    this.messageTarget.textContent = message
    this.confirmBtnTarget.textContent = confirmLabel
    this.cancelBtnTarget.textContent = cancelLabel

    const confirmClasses = this.confirmBtnTarget.classList
    confirmClasses.remove("bg-red-600", "hover:bg-red-700", "bg-cec-teal", "hover:bg-cec-teal-dark")
    if (danger) {
      confirmClasses.add("bg-red-600", "hover:bg-red-700")
      if (this.hasIconTarget) {
        this.iconTarget.classList.remove("bg-cec-teal/10", "text-cec-teal")
        this.iconTarget.classList.add("bg-red-50", "text-red-600")
      }
    } else {
      confirmClasses.add("bg-cec-teal", "hover:bg-cec-teal-dark")
      if (this.hasIconTarget) {
        this.iconTarget.classList.remove("bg-red-50", "text-red-600")
        this.iconTarget.classList.add("bg-cec-teal/10", "text-cec-teal")
      }
    }

    // Al cerrar, el foco vuelve al que abrió el modal y no se pierde en el body.
    this._previo = document.activeElement
    this.rootTarget.classList.remove("hidden")
    // Focus the cancel button by default to avoid accidental confirms.
    setTimeout(() => this.cancelBtnTarget.focus(), 0)

    return new Promise((resolve) => {
      this._pending = resolve
    })
  }

  confirm() {
    this._resolveAndClose(true)
  }

  cancel() {
    this._resolveAndClose(false)
  }

  _resolveAndClose(value) {
    this.rootTarget.classList.add("hidden")
    if (this._previo?.isConnected) this._previo.focus()
    this._previo = null
    const resolve = this._pending
    this._pending = null
    if (resolve) resolve(value)
  }
}
