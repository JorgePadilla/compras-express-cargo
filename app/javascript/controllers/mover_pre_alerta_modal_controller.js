import { Controller } from "@hotwired/stimulus"

// PR-D4.a.2 — Modal para mover un paquete a una pre-alerta existente.
// Yusef: "se permite mover a pre-alerta de cualquier cliente (caso
// típico: corregir asignación equivocada)".
//
// Markup:
//   <div data-controller="mover-pre-alerta-modal"
//        data-mover-pre-alerta-modal-search-url-value="/pre_alertas/buscar"
//        data-mover-pre-alerta-modal-paquete-id-value="123">
//     <button data-action="mover-pre-alerta-modal#open">Mover…</button>
//     <dialog data-mover-pre-alerta-modal-target="dialog">
//       <input data-action="input->mover-pre-alerta-modal#search"
//              data-mover-pre-alerta-modal-target="input">
//       <ul data-mover-pre-alerta-modal-target="results"></ul>
//       <form data-mover-pre-alerta-modal-target="form" method="post">
//         <input type="hidden" name="pre_alerta_id"
//                data-mover-pre-alerta-modal-target="hiddenId">
//       </form>
//     </dialog>
//   </div>
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

    items.forEach(pa => {
      const li = document.createElement("li")
      const btn = document.createElement("button")
      btn.type = "button"
      btn.className = "w-full text-left px-4 py-3 hover:bg-gray-100 dark:hover:bg-gray-700/50 flex items-start justify-between gap-3 transition-colors"
      btn.dataset.action = "click->mover-pre-alerta-modal#select"
      btn.dataset.id = pa.id
      btn.dataset.numero = pa.numero
      btn.dataset.titulo = pa.titulo
      btn.dataset.cliente = pa.cliente

      const left = document.createElement("div")
      left.className = "min-w-0"
      left.innerHTML = `
        <div class="font-mono text-sm font-semibold text-cec-navy dark:text-cec-gold">${pa.numero}</div>
        <div class="text-xs text-gray-700 dark:text-gray-200 truncate">${pa.titulo}</div>
        <div class="text-xs text-gray-500 dark:text-gray-400 truncate">${pa.cliente}</div>
      `

      const right = document.createElement("div")
      right.className = "shrink-0 flex flex-col items-end gap-1"
      const estadoBadge = document.createElement("span")
      estadoBadge.className = "text-[10px] uppercase tracking-wider font-bold px-1.5 py-0.5 rounded bg-gray-100 dark:bg-gray-700 text-gray-700 dark:text-gray-200"
      estadoBadge.textContent = pa.estado
      right.appendChild(estadoBadge)
      if (pa.consolidado) {
        const consolidadoBadge = document.createElement("span")
        consolidadoBadge.className = "text-[10px] uppercase tracking-wider font-bold px-1.5 py-0.5 rounded bg-cec-gold/15 text-cec-gold-dark"
        consolidadoBadge.textContent = "Consolidado"
        right.appendChild(consolidadoBadge)
      }

      btn.appendChild(left)
      btn.appendChild(right)
      li.appendChild(btn)
      this.resultsTarget.appendChild(li)
    })
  }

  select(e) {
    const btn = e.currentTarget
    this.hiddenIdTarget.value = btn.dataset.id
    if (this.hasSelectedSummaryTarget) {
      this.selectedSummaryTarget.innerHTML = `
        <div class="px-4 py-2 bg-cec-teal/10 dark:bg-cec-teal/20 ring-1 ring-cec-teal/30 rounded-lg">
          <p class="text-xs font-semibold uppercase tracking-wider text-cec-teal-dark dark:text-cec-teal-light">Seleccionada:</p>
          <p class="font-mono text-sm font-semibold text-cec-navy dark:text-cec-gold">${btn.dataset.numero}</p>
          <p class="text-xs text-gray-700 dark:text-gray-200 truncate">${btn.dataset.titulo}</p>
          <p class="text-xs text-gray-500 dark:text-gray-400 truncate">${btn.dataset.cliente}</p>
        </div>
      `
      this.selectedSummaryTarget.classList.remove("hidden")
    }
    if (this.hasFormTarget) {
      const submitBtn = this.formTarget.querySelector("button[type=submit]")
      if (submitBtn) submitBtn.disabled = false
    }
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
