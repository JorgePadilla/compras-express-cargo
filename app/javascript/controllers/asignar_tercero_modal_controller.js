import { Controller } from "@hotwired/stimulus"

// Modal para asignar / cambiar el Tercero (cliente final) de un paquete.
// Mirror del patrón de mover_pre_alerta_modal: search → select → submit.
// Reemplaza el flow viejo de "Asignar → edit mode" que confundía a los
// operadores porque aterrizaban en el form completo sin contexto.
export default class extends Controller {
  static values = { searchUrl: String, paqueteId: Number }
  static targets = ["dialog", "input", "results", "hiddenId", "form", "selectedSummary"]

  open(e) {
    e.preventDefault()
    if (this.hasDialogTarget) {
      if (this.dialogTarget.showModal) this.dialogTarget.showModal()
      else this.dialogTarget.classList.remove("hidden")
      this.inputTarget?.focus()
    }
  }

  close(e) {
    e?.preventDefault()
    if (this.hasDialogTarget) {
      if (this.dialogTarget.close) this.dialogTarget.close()
      else this.dialogTarget.classList.add("hidden")
    }
    this.clearSelection()
  }

  search() {
    if (this._timeout) clearTimeout(this._timeout)

    const query = this.inputTarget.value.trim()
    if (query.length < 2) {
      this.resultsTarget.replaceChildren()
      return
    }

    this._timeout = setTimeout(() => {
      fetch(`${this.searchUrlValue}?q=${encodeURIComponent(query)}`, {
        headers: { "Accept": "application/json" }
      })
        .then(r => r.json())
        .then(items => this.renderResults(items))
        .catch(() => this.renderResults([]))
    }, 300)
  }

  renderResults(items) {
    this.resultsTarget.replaceChildren()
    if (items.length === 0) {
      const empty = document.createElement("li")
      empty.className = "px-4 py-3 text-sm text-gray-500 italic"
      empty.textContent = "Sin resultados — probá con otra búsqueda."
      this.resultsTarget.appendChild(empty)
      return
    }

    items.forEach(c => {
      const li = document.createElement("li")
      const btn = document.createElement("button")
      btn.type = "button"
      btn.className = "w-full text-left px-4 py-3 hover:bg-gray-100 dark:hover:bg-gray-700/50 flex items-start justify-between gap-3 transition-colors"
      btn.dataset.action = "click->asignar-tercero-modal#select"
      btn.dataset.id = c.id
      btn.dataset.codigo = c.codigo
      btn.dataset.nombre = c.nombre

      const left = document.createElement("div")
      left.className = "min-w-0"
      left.innerHTML = `
        <div class="font-mono text-sm font-semibold text-cec-navy dark:text-cec-gold">${c.codigo}</div>
        <div class="text-xs text-gray-700 dark:text-gray-200 truncate">${c.nombre}</div>
      `

      if (c.categoria_precio) {
        const right = document.createElement("div")
        right.className = "shrink-0"
        const badge = document.createElement("span")
        badge.className = "text-[10px] uppercase tracking-wider font-bold px-1.5 py-0.5 rounded bg-cec-purple/10 text-cec-purple-dark"
        badge.textContent = c.categoria_precio
        right.appendChild(badge)
        btn.appendChild(left)
        btn.appendChild(right)
      } else {
        btn.appendChild(left)
      }

      li.appendChild(btn)
      this.resultsTarget.appendChild(li)
    })
  }

  select(e) {
    const btn = e.currentTarget
    this.hiddenIdTarget.value = btn.dataset.id

    // Auto-submit on selection: el feedback de Yusef fue que el paso
    // intermedio "seleccionar + click en botón Asignar" se sentía trabado.
    // Click en cliente = asignar inmediatamente. Si elige mal, "Cambiar"
    // re-abre el modal.
    btn.disabled = true
    btn.classList.add("opacity-60")
    btn.innerHTML = `<span class="text-sm italic text-cec-purple-dark">Asignando ${btn.dataset.codigo} — ${btn.dataset.nombre}…</span>`

    if (this.hasFormTarget) this.formTarget.requestSubmit()
  }

  clearSelection() {
    if (this.hasHiddenIdTarget) this.hiddenIdTarget.value = ""
    if (this.hasSelectedSummaryTarget) {
      this.selectedSummaryTarget.innerHTML = ""
      this.selectedSummaryTarget.classList.add("hidden")
    }
    if (this.hasInputTarget) this.inputTarget.value = ""
    if (this.hasResultsTarget) this.resultsTarget.replaceChildren()
    if (this.hasFormTarget) {
      const submitBtn = this.formTarget.querySelector("button[type=submit]")
      if (submitBtn) submitBtn.disabled = true
    }
  }
}
