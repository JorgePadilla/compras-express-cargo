import { Controller } from "@hotwired/stimulus"

// PR-D3.a — Autocomplete de proveedores (Amazon, Walmart, drivers
// privados…). Misma UX que client_autocomplete: el operador escribe
// código o nombre, ve un dropdown filtrado server-side, y al elegir
// se popula un hidden field con el id y se muestra el nombre.
//
// Markup esperado:
//   <div data-controller="proveedor-autocomplete"
//        data-proveedor-autocomplete-url-value="<%= buscar_proveedores_path %>">
//     <input data-proveedor-autocomplete-target="input"
//            data-action="input->proveedor-autocomplete#search">
//     <input type="hidden" name="paquete[proveedor_id]"
//            data-proveedor-autocomplete-target="proveedorId">
//     <div data-proveedor-autocomplete-target="dropdown" class="hidden …"></div>
//     <span data-proveedor-autocomplete-target="nombre" class="hidden …"></span>
//   </div>
export default class extends Controller {
  static targets = ["input", "proveedorId", "dropdown", "nombre"]
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
    // Si el operador limpia el campo, se desvincula del catálogo.
    if (query.length === 0) {
      this.proveedorIdTarget.value = ""
      if (this.hasNombreTarget) {
        this.nombreTarget.textContent = ""
        this.nombreTarget.classList.add("hidden")
      }
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
        .then(items => this.renderDropdown(items))
        .catch(() => this.hideDropdown())
    }, 300)
  }

  renderDropdown(items) {
    this.dropdownTarget.replaceChildren()

    if (items.length === 0) {
      const empty = document.createElement("div")
      empty.className = "px-4 py-3 text-sm text-gray-500"
      empty.textContent = "Sin resultados — pedile a admin que cree el proveedor"
      this.dropdownTarget.appendChild(empty)
      this.showDropdown()
      return
    }

    items.forEach(p => {
      const btn = document.createElement("button")
      btn.type = "button"
      btn.className = "w-full text-left px-4 py-2 hover:bg-gray-100 flex items-center gap-2"
      btn.dataset.action = "click->proveedor-autocomplete#select"
      btn.dataset.id = p.id
      btn.dataset.codigo = p.codigo
      btn.dataset.nombre = p.nombre
      btn.dataset.tipo = p.tipo

      const codigoSpan = document.createElement("span")
      codigoSpan.className = "font-mono text-sm font-medium text-cec-navy"
      codigoSpan.textContent = p.codigo

      const nombreSpan = document.createElement("span")
      nombreSpan.className = "text-sm text-gray-700"
      nombreSpan.textContent = p.nombre

      btn.appendChild(codigoSpan)
      btn.appendChild(nombreSpan)

      if (p.tipo === "entrega_personal") {
        const tag = document.createElement("span")
        tag.className = "ml-auto px-1.5 py-0.5 rounded text-[10px] font-medium bg-amber-100 text-amber-900"
        tag.textContent = "EP"
        btn.appendChild(tag)
      }

      this.dropdownTarget.appendChild(btn)
    })
    this.showDropdown()
  }

  select(e) {
    const btn = e.currentTarget
    this.proveedorIdTarget.value = btn.dataset.id
    this.inputTarget.value = btn.dataset.nombre
    if (this.hasNombreTarget) {
      this.nombreTarget.textContent = `(${btn.dataset.codigo})`
      this.nombreTarget.classList.remove("hidden")
    }
    this.hideDropdown()
  }

  hideDropdown() {
    this.dropdownTarget.classList.add("hidden")
  }

  showDropdown() {
    this.dropdownTarget.classList.remove("hidden")
  }
}
