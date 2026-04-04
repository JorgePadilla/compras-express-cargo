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
    this.dropdownTarget.replaceChildren()

    if (clientes.length === 0) {
      const empty = document.createElement("div")
      empty.className = "px-4 py-3 text-sm text-gray-500"
      empty.textContent = "No se encontraron clientes"
      this.dropdownTarget.appendChild(empty)
      this.showDropdown()
      return
    }

    clientes.forEach(c => {
      const btn = document.createElement("button")
      btn.type = "button"
      btn.className = "w-full text-left px-4 py-2 hover:bg-gray-100 flex items-center justify-between"
      btn.dataset.action = "click->client-autocomplete#select"
      btn.dataset.id = c.id
      btn.dataset.codigo = c.codigo
      btn.dataset.nombre = c.nombre

      const wrapper = document.createElement("div")
      const codigoSpan = document.createElement("span")
      codigoSpan.className = "font-mono text-sm font-medium text-cec-navy"
      codigoSpan.textContent = c.codigo

      const nombreSpan = document.createElement("span")
      nombreSpan.className = "ml-2 text-sm text-gray-700"
      nombreSpan.textContent = c.nombre

      wrapper.appendChild(codigoSpan)
      wrapper.appendChild(nombreSpan)
      btn.appendChild(wrapper)
      this.dropdownTarget.appendChild(btn)
    })
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
