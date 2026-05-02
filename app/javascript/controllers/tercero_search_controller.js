import { Controller } from "@hotwired/stimulus"

// PR-D3.c — Lupa de búsqueda para asignar un "tercero" al paquete.
// Reusa el mismo endpoint de búsqueda de clientes (clientes#buscar).
//
// Markup esperado:
//   <div data-controller="tercero-search"
//        data-tercero-search-url-value="<%= buscar_clientes_path %>">
//     <input data-tercero-search-target="input"
//            data-action="input->tercero-search#search">
//     <input type="hidden" name="paquete[tercero_id]"
//            data-tercero-search-target="terceroId">
//     <div data-tercero-search-target="dropdown" class="hidden …"></div>
//     <span data-tercero-search-target="nombre" class="hidden …"></span>
//     <button data-action="tercero-search#clear">Quitar tercero</button>
//   </div>
export default class extends Controller {
  static targets = ["input", "terceroId", "dropdown", "nombre", "clearButton"]
  static values = { url: String }

  connect() {
    this._timeout = null
    this.toggleClearButton()
  }

  disconnect() {
    if (this._timeout) clearTimeout(this._timeout)
  }

  search() {
    if (this._timeout) clearTimeout(this._timeout)

    const query = this.inputTarget.value.trim()
    if (query.length === 0) {
      this.hideDropdown()
      return
    }

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
      btn.dataset.action = "click->tercero-search#select"
      btn.dataset.id = c.id
      btn.dataset.codigo = c.codigo
      btn.dataset.nombre = c.nombre

      const codigoSpan = document.createElement("span")
      codigoSpan.className = "font-mono text-sm font-medium text-cec-navy"
      codigoSpan.textContent = c.codigo

      const nombreSpan = document.createElement("span")
      nombreSpan.className = "ml-2 text-sm text-gray-700"
      nombreSpan.textContent = c.nombre

      const wrapper = document.createElement("div")
      wrapper.appendChild(codigoSpan)
      wrapper.appendChild(nombreSpan)
      btn.appendChild(wrapper)
      this.dropdownTarget.appendChild(btn)
    })
    this.showDropdown()
  }

  select(e) {
    const btn = e.currentTarget
    this.terceroIdTarget.value = btn.dataset.id
    this.inputTarget.value = `${btn.dataset.codigo} — ${btn.dataset.nombre}`
    if (this.hasNombreTarget) {
      this.nombreTarget.textContent = btn.dataset.nombre
      this.nombreTarget.classList.remove("hidden")
    }
    this.hideDropdown()
    this.toggleClearButton()
  }

  clear(event) {
    event.preventDefault()
    this.terceroIdTarget.value = ""
    this.inputTarget.value = ""
    if (this.hasNombreTarget) {
      this.nombreTarget.textContent = ""
      this.nombreTarget.classList.add("hidden")
    }
    this.toggleClearButton()
  }

  toggleClearButton() {
    if (!this.hasClearButtonTarget) return
    const hasValue = this.terceroIdTarget.value.toString().length > 0
    this.clearButtonTarget.classList.toggle("hidden", !hasValue)
  }

  hideDropdown() {
    this.dropdownTarget.classList.add("hidden")
  }

  showDropdown() {
    this.dropdownTarget.classList.remove("hidden")
  }
}
