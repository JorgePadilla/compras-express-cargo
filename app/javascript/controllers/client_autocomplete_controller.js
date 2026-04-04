import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "clienteId", "dropdown", "nombre"]
  static values = { url: String }

  connect() {
    this._timeout = null
  }

  disconnect() {
    if (this._timeout) clearTimeout(this._timeout)
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
    if (clientes.length === 0) {
      this.dropdownTarget.innerHTML = `<div class="px-4 py-3 text-sm text-gray-500">No se encontraron clientes</div>`
      this.showDropdown()
      return
    }

    this.dropdownTarget.innerHTML = clientes.map(c => `
      <button type="button"
        class="w-full text-left px-4 py-2 hover:bg-gray-100 flex items-center justify-between"
        data-action="click->client-autocomplete#select"
        data-id="${c.id}" data-codigo="${c.codigo}" data-nombre="${c.nombre}">
        <div>
          <span class="font-mono text-sm font-medium text-cec-navy">${c.codigo}</span>
          <span class="ml-2 text-sm text-gray-700">${c.nombre}</span>
        </div>
      </button>
    `).join("")
    this.showDropdown()
  }

  select(e) {
    const btn = e.currentTarget
    this.clienteIdTarget.value = btn.dataset.id
    this.inputTarget.value = btn.dataset.codigo
    this.nombreTarget.textContent = btn.dataset.nombre
    this.nombreTarget.classList.remove("hidden")
    this.hideDropdown()
  }

  hideDropdown() {
    this.dropdownTarget.classList.add("hidden")
  }

  showDropdown() {
    this.dropdownTarget.classList.remove("hidden")
  }
}
