import { Controller } from "@hotwired/stimulus"

// Selector editable del Cliente dueño del paquete. Reemplaza el banner
// read-only en el form de edición. Yusef pidió poder corregir mal
// asignados directo desde edit sin tener que ir a "Mover a Pre-Alerta".
//
// Patrón: pill con cliente actual + botón "Cambiar" que expande búsqueda
// inline. Al seleccionar otro cliente, pill se actualiza con badge
// "Modificado"; "Cancelar cambio" revierte sin guardar. El save real
// pasa via el hidden field clienteId y el submit normal del form.
export default class extends Controller {
  static targets = [
    "clienteId", "codigoDisplay", "nombreDisplay",
    "changedBadge", "toggleButton", "cancelButton",
    "searchPanel", "input", "dropdown"
  ]
  static values = {
    url: String,
    originalId: Number,
    originalCodigo: String,
    originalNombre: String
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
    this.clienteIdTarget.value = this.originalIdValue
    this.codigoDisplayTarget.textContent = this.originalCodigoValue
    this.nombreDisplayTarget.textContent = this.originalNombreValue
    this.changedBadgeTarget.classList.add("hidden")
    this.searchPanelTarget.classList.add("hidden")
    this.toggleButtonTarget.classList.remove("hidden")
    this.cancelButtonTarget.classList.add("hidden")
    this.inputTarget.value = ""
    this.hideDropdown()
  }

  search() {
    if (this._timeout) clearTimeout(this._timeout)

    const query = this.inputTarget.value.trim()
    if (query.length < 2) {
      this.hideDropdown()
      return
    }

    this._timeout = setTimeout(() => {
      fetch(`${this.urlValue}?q=${encodeURIComponent(query)}`, {
        headers: { "Accept": "application/json" }
      })
        .then(r => r.json())
        .then(clientes => this.renderDropdown(clientes))
        .catch(() => this.hideDropdown())
    }, 300)
  }

  renderDropdown(clientes) {
    this.dropdownTarget.replaceChildren()

    if (clientes.length === 0) {
      const empty = document.createElement("div")
      empty.className = "px-4 py-3 text-sm text-gray-500 italic"
      empty.textContent = "No se encontraron clientes."
      this.dropdownTarget.appendChild(empty)
      this.showDropdown()
      return
    }

    clientes.forEach(c => {
      const btn = document.createElement("button")
      btn.type = "button"
      btn.className = "w-full text-left px-3 py-2 hover:bg-cec-teal/5 dark:hover:bg-cec-teal/15 flex items-center justify-between gap-3 transition-colors group"
      btn.dataset.action = "click->cliente-search#select"
      btn.dataset.id = c.id
      btn.dataset.codigo = c.codigo
      btn.dataset.nombre = c.nombre

      const left = document.createElement("div")
      left.className = "min-w-0 flex items-baseline gap-2"
      left.innerHTML = `
        <span class="font-mono text-sm font-bold text-cec-navy dark:text-cec-gold shrink-0">${c.codigo}</span>
        <span class="text-sm text-gray-700 dark:text-gray-200 truncate">${c.nombre}</span>
      `

      const right = document.createElement("span")
      right.className = "opacity-0 group-hover:opacity-100 transition-opacity text-[10px] font-semibold uppercase tracking-wider text-cec-teal shrink-0"
      right.textContent = "Seleccionar →"

      btn.appendChild(left)
      btn.appendChild(right)
      this.dropdownTarget.appendChild(btn)
    })
    this.showDropdown()
  }

  select(e) {
    const btn = e.currentTarget
    const newId = btn.dataset.id
    const newCodigo = btn.dataset.codigo
    const newNombre = btn.dataset.nombre

    this.clienteIdTarget.value = newId
    this.codigoDisplayTarget.textContent = newCodigo
    this.nombreDisplayTarget.textContent = newNombre

    const isSameAsOriginal = String(newId) === String(this.originalIdValue)
    if (isSameAsOriginal) {
      this.changedBadgeTarget.classList.add("hidden")
      this.cancelButtonTarget.classList.add("hidden")
      this.toggleButtonTarget.classList.remove("hidden")
    } else {
      this.changedBadgeTarget.classList.remove("hidden")
      this.cancelButtonTarget.classList.remove("hidden")
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
