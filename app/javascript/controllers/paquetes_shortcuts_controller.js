import { Controller } from "@hotwired/stimulus"

// Atajos de teclado para el listado /paquetes:
//   F4  → Imprimir vista actual (window.print)
//   F8  → Descargar Excel del scope filtrado
//   F9  → Descargar PDF del scope filtrado
//
// F2 (limpiar filtros + reload) lo maneja el controller universal
// `f2-clear` adjunto al form de filtros (ver f2_clear_controller.js).
export default class extends Controller {
  static values = {
    exportXlsxUrl: String,
    exportPdfUrl: String
  }

  connect() {
    this._onKey = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this._onKey)
  }

  disconnect() {
    document.removeEventListener("keydown", this._onKey)
  }

  handleKeydown(e) {
    // Los atajos solo cuando NO se está editando un input.
    if (this._isTyping(e.target)) return

    if (e.key === "F4") {
      e.preventDefault()
      this._clickAction("bulk-selection#print")
    } else if (e.key === "F8") {
      e.preventDefault()
      this._clickAction("bulk-selection#exportXlsx")
    } else if (e.key === "F9") {
      e.preventDefault()
      this._clickAction("bulk-selection#exportPdf")
    }
  }

  // Triggers un click en el primer elemento que tenga el data-action dado.
  // Asi el atajo de teclado se comporta exactamente igual que el click del
  // boton del header (incluyendo la logica smart de bulk-selection).
  _clickAction(action) {
    const btn = document.querySelector(`[data-action*="${action}"]`)
    if (btn) btn.click()
  }

  _isTyping(el) {
    if (!el) return false
    const tag = (el.tagName || "").toUpperCase()
    return tag === "INPUT" || tag === "TEXTAREA" || tag === "SELECT" || el.isContentEditable
  }
}
