import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "error"]

  connect() { this._hideTimer = null }
  disconnect() { clearTimeout(this._hideTimer) }

  sanitize() {
    const original = this.inputTarget.value
    const cleaned = original.replace(/[^A-Za-z0-9\-]/g, "")

    if (cleaned !== original) {
      const caret = this.inputTarget.selectionStart
      this.inputTarget.value = cleaned
      const newCaret = Math.max(0, caret - (original.length - cleaned.length))
      try { this.inputTarget.setSelectionRange(newCaret, newCaret) } catch (_) {}
      this._showError()
      return
    }

    if (cleaned === "") this._hideError()
  }

  _showError() {
    if (!this.hasErrorTarget) return
    this.errorTarget.textContent = "Solo letras, números y guiones. No se permiten espacios ni símbolos."
    this.errorTarget.classList.remove("hidden")
    clearTimeout(this._hideTimer)
    this._hideTimer = setTimeout(() => this._hideError(), 3000)
  }

  _hideError() {
    if (!this.hasErrorTarget) return
    this.errorTarget.classList.add("hidden")
  }
}
