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
  static targets = ["row", "selectAll", "bar", "counter", "footerBar", "footerCounter", "footerPreview"]
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
    const selected = this.rowTargets.filter(cb => cb.checked)
    const count = selected.length

    // Top sticky bar.
    if (this.hasCounterTarget) this.counterTarget.textContent = count
    if (this.hasBarTarget) this.barTarget.classList.toggle("hidden", count === 0)

    // Footer bar (debajo de la paginación).
    if (this.hasFooterCounterTarget) this.footerCounterTarget.textContent = count
    if (this.hasFooterBarTarget) this.footerBarTarget.classList.toggle("hidden", count === 0)
    if (this.hasFooterPreviewTarget) this._renderFooterPreview(selected)
  }

  _renderFooterPreview(selected) {
    const MAX_CHIPS = 10
    const trackings = selected.map(cb => cb.dataset.tracking).filter(Boolean)
    const visible = trackings.slice(0, MAX_CHIPS)
    const overflow = trackings.length - visible.length

    const chips = visible.map(t =>
      `<span class="inline-flex items-center px-2 py-0.5 rounded bg-cec-teal/10 text-cec-teal-dark dark:bg-cec-teal/20 dark:text-cec-teal-light font-mono text-[11px] ring-1 ring-cec-teal/30">${this._escapeHtml(t)}</span>`
    )
    if (overflow > 0) {
      chips.push(`<span class="inline-flex items-center px-2 py-0.5 rounded bg-gray-100 dark:bg-gray-700 text-gray-600 dark:text-gray-300 text-[11px]">+${overflow} más</span>`)
    }
    this.footerPreviewTarget.innerHTML = chips.join("")
  }

  _escapeHtml(s) {
    return String(s).replace(/[&<>"']/g, c => ({
      "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;"
    }[c]))
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

  // Imprimir: si hay selección abre el listado HTML imprimible en una
  // pestaña nueva (auto-dispara window.print() al cargar). Si no hay
  // selección, window.print() de la vista actual.
  print(event) {
    if (event) event.preventDefault()
    const ids = this._selectedIds()
    if (ids.length > 0) {
      this._submitPost(this.bulkPrintUrlValue, { paquete_ids: ids }, "_blank")
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
  // `target` opcional: pasar "_blank" para abrir la respuesta en pestaña
  // nueva (usado por print → ver el preview de impresión sin perder la
  // página actual).
  _submitPost(url, params, target = null) {
    if (!url) return
    const form = document.createElement("form")
    form.method = "post"
    form.action = url
    if (target) form.target = target
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
