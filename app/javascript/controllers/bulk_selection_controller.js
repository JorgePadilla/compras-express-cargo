import { Controller } from "@hotwired/stimulus"

// Stimulus controller para selección múltiple en el listado de paquetes.
// Los botones del header (Excel, PDF, Imprimir) son SMART:
//   - Si hay ≥ 1 fila seleccionada → POST a bulk_export/bulk_print con
//     los IDs seleccionados.
//   - Si no hay selección → GET a /paquetes/export con los filtros
//     actuales (URL pasada via data-value).
// La barra flotante (data-bulk-selection-target="bar") muestra el contador
// y un botón "Limpiar".
export default class extends Controller {
  static targets = ["row", "selectAll", "bar", "counter"]
  static values = {
    bulkPrintUrl:  String,
    bulkExportUrl: String,
    exportXlsxUrl: String,
    exportPdfUrl:  String
  }

  connect() {
    this.updateUI()
  }

  toggleAll(event) {
    const checked = event.currentTarget.checked
    this.rowTargets.forEach(cb => { cb.checked = checked })
    this.updateUI()
  }

  toggleRow() {
    this.syncSelectAll()
    this.updateUI()
  }

  syncSelectAll() {
    if (!this.hasSelectAllTarget) return
    const total = this.rowTargets.length
    const selected = this._selectedIds().length
    this.selectAllTarget.checked = total > 0 && selected === total
    this.selectAllTarget.indeterminate = selected > 0 && selected < total
  }

  updateUI() {
    const count = this._selectedIds().length
    if (this.hasCounterTarget) this.counterTarget.textContent = count
    if (this.hasBarTarget) this.barTarget.classList.toggle("hidden", count === 0)
  }

  clear() {
    this.rowTargets.forEach(cb => { cb.checked = false })
    if (this.hasSelectAllTarget) {
      this.selectAllTarget.checked = false
      this.selectAllTarget.indeterminate = false
    }
    this.updateUI()
  }

  // ── Acciones smart de los botones del header ──

  exportXlsx(event) {
    event.preventDefault()
    const ids = this._selectedIds()
    if (ids.length > 0) {
      this._submitPost(this.bulkExportUrlValue, { paquete_ids: ids, formato: "xlsx" })
    } else if (this.hasExportXlsxUrlValue) {
      window.location.href = this.exportXlsxUrlValue
    }
  }

  exportPdf(event) {
    event.preventDefault()
    const ids = this._selectedIds()
    if (ids.length > 0) {
      this._submitPost(this.bulkExportUrlValue, { paquete_ids: ids, formato: "pdf" })
    } else if (this.hasExportPdfUrlValue) {
      window.location.href = this.exportPdfUrlValue
    }
  }

  // Imprimir: si hay selección genera PDF de los seleccionados; si no,
  // window.print() de la vista actual.
  print(event) {
    if (event) event.preventDefault()
    const ids = this._selectedIds()
    if (ids.length > 0) {
      this._submitPost(this.bulkPrintUrlValue, { paquete_ids: ids })
    } else {
      window.print()
    }
  }

  // ── Helpers ──

  _selectedIds() {
    return this.rowTargets.filter(cb => cb.checked).map(cb => cb.value)
  }

  _csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content || ""
  }

  // Construye y envía un form POST dinámico con los params dados. Usado
  // por las acciones bulk del header para evitar GET con URLs gigantes
  // y reusar las rutas POST del controller.
  _submitPost(url, params) {
    if (!url) return
    const form = document.createElement("form")
    form.method = "post"
    form.action = url
    form.style.display = "none"

    const csrf = document.createElement("input")
    csrf.type = "hidden"
    csrf.name = "authenticity_token"
    csrf.value = this._csrfToken()
    form.appendChild(csrf)

    Object.entries(params).forEach(([key, val]) => {
      if (Array.isArray(val)) {
        val.forEach(v => {
          const input = document.createElement("input")
          input.type = "hidden"
          input.name = `${key}[]`
          input.value = v
          form.appendChild(input)
        })
      } else {
        const input = document.createElement("input")
        input.type = "hidden"
        input.name = key
        input.value = val
        form.appendChild(input)
      }
    })

    document.body.appendChild(form)
    form.submit()
  }
}
