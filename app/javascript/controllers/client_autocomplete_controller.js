import { Controller } from "@hotwired/stimulus"

// Autocomplete de Cliente con keyboard nav.
//
// Markup esperado:
//   <div data-controller="client-autocomplete"
//        data-client-autocomplete-url-value="<%= buscar_clientes_path %>">
//     <input data-client-autocomplete-target="input"
//            data-action="input->client-autocomplete#search
//                         keydown->client-autocomplete#onKeydown">
//     <input type="hidden" name="cliente_id"
//            data-client-autocomplete-target="clienteId">
//     <div data-client-autocomplete-target="dropdown" class="hidden …"></div>
//     <span data-client-autocomplete-target="nombre" class="hidden …"></span>
//   </div>
//
// Keyboard:
//   ArrowDown / ArrowUp → navega entre opciones (highlight visual).
//   Enter             → selecciona la opción highlighted (si dropdown abierto).
//   Escape            → cierra dropdown sin seleccionar.
//   Tab               → comportamiento default del browser (cierra dropdown).
export default class extends Controller {
  static targets = ["input", "clienteId", "dropdown", "nombre"]
  static values  = { url: String }

  connect() {
    this._timeout = null
    this._activeIndex = -1
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

  onKeydown(e) {
    if (this.dropdownTarget.classList.contains("hidden")) return

    const items = this.itemButtons()
    if (items.length === 0) return

    switch (e.key) {
      case "ArrowDown":
        e.preventDefault()
        this._activeIndex = (this._activeIndex + 1) % items.length
        this.applyHighlight(items)
        break
      case "ArrowUp":
        e.preventDefault()
        this._activeIndex = this._activeIndex <= 0 ? items.length - 1 : this._activeIndex - 1
        this.applyHighlight(items)
        break
      case "Enter":
        if (this._activeIndex >= 0 && this._activeIndex < items.length) {
          e.preventDefault()
          items[this._activeIndex].click()
        }
        // Si no hay highlight, deja que Enter submitee el form (default).
        break
      case "Escape":
        e.preventDefault()
        this.hideDropdown()
        break
      case "Tab":
        this.hideDropdown()
        break
    }
  }

  itemButtons() {
    return Array.from(this.dropdownTarget.querySelectorAll("button[data-action*='client-autocomplete#select']"))
  }

  applyHighlight(items) {
    items.forEach((btn, i) => {
      btn.classList.toggle("bg-cec-teal/10", i === this._activeIndex)
      btn.classList.toggle("dark:bg-cec-teal/20", i === this._activeIndex)
      if (i === this._activeIndex) btn.scrollIntoView({ block: "nearest" })
    })
  }

  renderDropdown(clientes) {
    this.dropdownTarget.replaceChildren()
    this._activeIndex = -1

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
      btn.className = "w-full text-left px-4 py-2 hover:bg-gray-100 dark:hover:bg-gray-700 flex items-center justify-between"
      btn.dataset.action = "click->client-autocomplete#select"
      btn.dataset.id = c.id
      btn.dataset.codigo = c.codigo
      btn.dataset.nombre = c.nombre

      const wrapper = document.createElement("div")
      const codigoSpan = document.createElement("span")
      codigoSpan.className = "font-mono text-sm font-medium text-cec-navy dark:text-cec-gold"
      codigoSpan.textContent = c.codigo

      const nombreSpan = document.createElement("span")
      nombreSpan.className = "ml-2 text-sm text-gray-700 dark:text-gray-300"
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
    this.inputTarget.value = `${btn.dataset.codigo} — ${btn.dataset.nombre}`
    if (this.hasNombreTarget) {
      this.nombreTarget.textContent = btn.dataset.nombre
      this.nombreTarget.classList.remove("hidden")
    }
    this.hideDropdown()
  }

  hideDropdown() {
    this.dropdownTarget.classList.add("hidden")
    this._activeIndex = -1
  }

  showDropdown() {
    this.dropdownTarget.classList.remove("hidden")
  }
}
