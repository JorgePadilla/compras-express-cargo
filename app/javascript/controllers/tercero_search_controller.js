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
    this._activeIndex = -1
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

    clientes.forEach((c, i) => {
      const btn = document.createElement("button")
      btn.type = "button"
      btn.className = "w-full text-left px-4 py-2 hover:bg-gray-100 flex items-center justify-between"
      btn.dataset.action = "click->tercero-search#select mousemove->tercero-search#hover"
      btn.dataset.index = i
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
    // Cargar el primer ítem como activo para confirmarlo con Enter sin mouse.
    this._activeIndex = 0
    this._highlightActive()
  }

  // ── Navegación por teclado ──
  _items() {
    return Array.from(this.dropdownTarget.querySelectorAll("[data-index]"))
  }

  _highlightActive() {
    this._items().forEach((el, i) => {
      const active = i === this._activeIndex
      el.classList.toggle("bg-cec-teal/10", active)
      if (active) el.scrollIntoView({ block: "nearest" })
    })
  }

  _move(delta) {
    const items = this._items()
    if (items.length === 0) return
    this._activeIndex = Math.max(0, Math.min(items.length - 1, this._activeIndex + delta))
    this._highlightActive()
  }

  hover(e) {
    const idx = parseInt(e.currentTarget.dataset.index, 10)
    if (Number.isFinite(idx) && idx !== this._activeIndex) {
      this._activeIndex = idx
      this._highlightActive()
    }
  }

  keydown(e) {
    if (this.dropdownTarget.classList.contains("hidden")) return
    const items = this._items()

    if (e.key === "ArrowDown") {
      e.preventDefault()
      this._move(1)
    } else if (e.key === "ArrowUp") {
      e.preventDefault()
      this._move(-1)
    } else if (e.key === "Enter") {
      const active = items[this._activeIndex]
      if (active) {
        e.preventDefault() // no enviar el form: solo seleccionar el tercero
        this._selectEl(active)
      }
    } else if (e.key === "Escape") {
      e.preventDefault()
      this.hideDropdown()
    } else if (e.key === "Tab") {
      this.hideDropdown()
    }
  }

  select(e) {
    this._selectEl(e.currentTarget)
  }

  _selectEl(btn) {
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
    this._activeIndex = -1
  }

  showDropdown() {
    this.dropdownTarget.classList.remove("hidden")
  }
}
