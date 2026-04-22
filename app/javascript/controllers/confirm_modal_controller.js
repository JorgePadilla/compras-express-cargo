import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["root", "title", "message", "confirmBtn", "cancelBtn", "icon"]

  connect() {
    this._pending = null
    this._onKeydown = (e) => {
      if (this.rootTarget.classList.contains("hidden")) return
      if (e.key === "Escape") this.cancel()
      if (e.key === "Enter") this.confirm()
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
      this.iconTarget.classList.remove("bg-cec-teal/10", "text-cec-teal")
      this.iconTarget.classList.add("bg-red-50", "text-red-600")
    } else {
      confirmClasses.add("bg-cec-teal", "hover:bg-cec-teal-dark")
      this.iconTarget.classList.remove("bg-red-50", "text-red-600")
      this.iconTarget.classList.add("bg-cec-teal/10", "text-cec-teal")
    }

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
    const resolve = this._pending
    this._pending = null
    if (resolve) resolve(value)
  }
}
