import { Controller } from "@hotwired/stimulus"

// Atajos de teclado para el listado /paquetes:
//   F4  → Imprimir vista actual (window.print)
//   F8  → Descargar Excel del scope filtrado
//   F9  → Descargar PDF del scope filtrado
//   F2  → Limpiar búsqueda (foco en el campo de búsqueda)
//
// Los atajos solo se disparan cuando el foco NO está en un input/textarea
// editable (excepto F2, que sí limpia el campo de búsqueda).
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
    // F2 limpia búsqueda y enfoca el campo (siempre disponible).
    if (e.key === "F2") {
      e.preventDefault()
      const input = document.querySelector("input[name='q']")
      if (input) {
        input.value = ""
        input.focus()
      }
      return
    }

    // Las demás solo cuando NO se está editando un input.
    if (this._isTyping(e.target)) return

    if (e.key === "F4") {
      e.preventDefault()
      this.print()
    } else if (e.key === "F8") {
      e.preventDefault()
      if (this.hasExportXlsxUrlValue) window.location.href = this.exportXlsxUrlValue
    } else if (e.key === "F9") {
      e.preventDefault()
      if (this.hasExportPdfUrlValue) window.location.href = this.exportPdfUrlValue
    }
  }

  print(event) {
    if (event) event.preventDefault()
    window.print()
  }

  _isTyping(el) {
    if (!el) return false
    const tag = (el.tagName || "").toUpperCase()
    return tag === "INPUT" || tag === "TEXTAREA" || tag === "SELECT" || el.isContentEditable
  }
}
