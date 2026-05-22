import { Controller } from "@hotwired/stimulus"

// Autocomplete del Manifiesto en el form del paquete. Mismo patrón que
// cliente_search: pill con manifiesto actual + boton "Cambiar" que
// expande input + dropdown. "Cancelar cambio" revierte al original.
// Yusef: al cambiar el manifiesto, las fechas de salida/aduana
// se sincronizan automáticamente (handled en el callback del modelo).
export default class extends Controller {
  static targets = [
    "manifiestoId", "numeroDisplay", "estadoDisplay",
    "changedBadge", "toggleButton", "cancelButton",
    "searchPanel", "input", "dropdown", "emptyState", "pill"
  ]
  static values = {
    url: String,
    originalId: Number,
    originalNumero: String,
    originalEstado: String
  }

  connect() {
    this._timeout = null
  }

  disconnect() {
    if (this._timeout) clearTimeout(this._timeout)
  }

  toggle(e) {
    e?.preventDefault()
    this.searchPanelTarget.classList.remove("hidden")
    this.toggleButtonTarget.classList.add("hidden")
    this.inputTarget.value = ""
    this.hideDropdown()
    this.inputTarget.focus()
  }

  cancelChange(e) {
    e?.preventDefault()
    this.manifiestoIdTarget.value = this.originalIdValue || ""
    if (this.hasNumeroDisplayTarget) this.numeroDisplayTarget.textContent = this.originalNumeroValue
    if (this.hasEstadoDisplayTarget) this.estadoDisplayTarget.textContent = this.originalEstadoValue
    if (this.hasChangedBadgeTarget) this.changedBadgeTarget.classList.add("hidden")
    this.searchPanelTarget.classList.add("hidden")
    this.toggleButtonTarget.classList.remove("hidden")
    if (this.hasCancelButtonTarget) this.cancelButtonTarget.classList.add("hidden")
    this.inputTarget.value = ""
    this.hideDropdown()
  }

  clear(e) {
    e?.preventDefault()
    this.manifiestoIdTarget.value = ""
    if (this.hasNumeroDisplayTarget) this.numeroDisplayTarget.textContent = "Sin manifiesto"
    if (this.hasEstadoDisplayTarget) this.estadoDisplayTarget.textContent = ""
    if (this.hasChangedBadgeTarget) this.changedBadgeTarget.classList.remove("hidden")
    if (this.hasCancelButtonTarget) this.cancelButtonTarget.classList.remove("hidden")
    this.searchPanelTarget.classList.add("hidden")
    this.toggleButtonTarget.classList.add("hidden")
    this.hideDropdown()
  }

  search() {
    if (this._timeout) clearTimeout(this._timeout)
    const query = this.inputTarget.value.trim()
    // En este caso, query vacío también sirve — devuelve los últimos 10.
    this._timeout = setTimeout(() => {
      fetch(`${this.urlValue}?q=${encodeURIComponent(query)}`, {
        headers: { "Accept": "application/json" }
      })
        .then(r => r.json())
        .then(items => this.renderDropdown(items))
        .catch(() => this.renderDropdown([]))
    }, 300)
  }

  renderDropdown(items) {
    this.dropdownTarget.replaceChildren()

    if (items.length === 0) {
      const empty = document.createElement("div")
      empty.className = "px-4 py-3 text-sm text-gray-500 italic"
      empty.textContent = "Sin resultados — probá otro número."
      this.dropdownTarget.appendChild(empty)
      this.showDropdown()
      return
    }

    items.forEach(m => {
      const btn = document.createElement("button")
      btn.type = "button"
      btn.className = "w-full text-left px-3 py-2 hover:bg-cec-teal/5 dark:hover:bg-cec-teal/15 flex items-center justify-between gap-3 transition-colors"
      btn.dataset.action = "click->manifiesto-autocomplete#select"
      btn.dataset.id = m.id
      btn.dataset.numero = m.numero
      btn.dataset.estado = m.estado

      const left = document.createElement("div")
      left.className = "min-w-0 flex-1"
      const enviadoLine = m.fecha_enviado ? `<div class="text-[11px] text-gray-500 dark:text-gray-400">Enviado: ${m.fecha_enviado}</div>` : `<div class="text-[11px] text-gray-400 italic">Aún no enviado</div>`
      left.innerHTML = `
        <div class="font-mono text-sm font-bold text-cec-navy dark:text-cec-gold">${m.numero}</div>
        ${enviadoLine}
      `

      const right = document.createElement("div")
      right.className = "shrink-0 flex flex-col items-end gap-0.5"
      const estadoBadge = document.createElement("span")
      estadoBadge.className = "text-[10px] uppercase tracking-wider font-bold px-1.5 py-0.5 rounded bg-gray-100 dark:bg-gray-700 text-gray-700 dark:text-gray-200"
      estadoBadge.textContent = m.estado
      right.appendChild(estadoBadge)
      if (m.paquetes_count != null) {
        const count = document.createElement("span")
        count.className = "text-[10px] text-gray-500 dark:text-gray-400"
        count.textContent = `${m.paquetes_count} paq.`
        right.appendChild(count)
      }

      btn.appendChild(left)
      btn.appendChild(right)
      this.dropdownTarget.appendChild(btn)
    })
    this.showDropdown()
  }

  select(e) {
    const btn = e.currentTarget
    const newId = btn.dataset.id
    const newNumero = btn.dataset.numero
    const newEstado = btn.dataset.estado

    this.manifiestoIdTarget.value = newId
    if (this.hasNumeroDisplayTarget) this.numeroDisplayTarget.textContent = newNumero
    if (this.hasEstadoDisplayTarget) this.estadoDisplayTarget.textContent = newEstado

    const isSameAsOriginal = String(newId) === String(this.originalIdValue)
    if (isSameAsOriginal) {
      if (this.hasChangedBadgeTarget) this.changedBadgeTarget.classList.add("hidden")
      if (this.hasCancelButtonTarget) this.cancelButtonTarget.classList.add("hidden")
      this.toggleButtonTarget.classList.remove("hidden")
    } else {
      if (this.hasChangedBadgeTarget) this.changedBadgeTarget.classList.remove("hidden")
      if (this.hasCancelButtonTarget) this.cancelButtonTarget.classList.remove("hidden")
      this.toggleButtonTarget.classList.add("hidden")
    }

    this.searchPanelTarget.classList.add("hidden")
    this.hideDropdown()
  }

  hideDropdown() {
    this.dropdownTarget.classList.add("hidden")
  }

  showDropdown() {
    this.dropdownTarget.classList.remove("hidden")
  }
}
