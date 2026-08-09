import { Controller } from "@hotwired/stimulus"

// Buscar y elegir el cliente con el teclado. Base compartida por /etiquetar y
// /entrega_personal.
//
// PR-C6.32. No es un controller registrado (el archivo no termina en
// `_controller`, así que `eagerLoadControllersFrom` lo ignora): es la clase de
// la que heredan los dos.
//
// **Por qué existe.** Cada pantalla tenía su propia copia del autocomplete, y
// a la de Entrega Personal nunca le llegaron los arreglos que se le hicieron a
// la de etiquetar. Jorge lo reportó: "en entrega personal, cuando seleccionamos
// el cliente es distinto de lo que tenemos en etiquetar; debería ser el mismo
// comportamiento".
//
// Es la tercera vez que esa duplicación muerde — antes fue el peso por caja y
// el modal de F9 (PR-C6.31). Copiar el comportamiento otra vez solo habría
// programado la cuarta.
//
// **Cómo se extiende.** El que hereda sobreescribe `_alSeleccionarCliente`
// para lo suyo (la franja de contexto, el banner de notas). Todo lo demás
// —búsqueda, dropdown, navegación con teclado— es igual en las dos y vive acá.
export default class ClienteAutocomplete extends Controller {
  static targets = [ "clienteInput", "clienteId", "clienteDropdown", "clienteNombre" ]
  static values = { buscarUrl: { type: String, default: "/clientes/buscar" } }

  searchCliente() {
    if (this._searchTimeout) clearTimeout(this._searchTimeout)

    const query = this.clienteInputTarget.value.trim()
    if (!this._buscaCliente(query)) {
      this.hideDropdown()
      return
    }

    this._searchTimeout = setTimeout(() => {
      fetch(`${this.buscarUrlValue}?q=${encodeURIComponent(query)}`, {
        headers: { "Accept": "application/json" }
      })
        .then(r => r.json())
        .then(clientes => this.renderDropdown(clientes))
        .catch(() => this.hideDropdown())
    }, 300)
  }

  // ¿Alcanza lo tecleado para buscar?
  //
  // PR-C6.16. Había un mínimo de 2 caracteres, y eso bloqueaba justo la forma
  // en que Miami trabaja. Yusef:
  //
  //   > "Solo le ponían el dos, ponele que el mío es el seis, solo poníamos el
  //   >  seis o el dos y ya con eso cae."
  //
  // Un dígito suelto es una búsqueda legítima —`2` cae en `CEC-002`, que el
  // backend ya pone primero (PR-C6.14b)— pero una letra suelta no: buscar "a"
  // devolvería la cartera entera y el dropdown sería ruido.
  _buscaCliente(query) {
    if (query.length >= 2) return true

    return /^\d$/.test(query)
  }

  renderDropdown(clientes) {
    if (clientes.length === 0) {
      this.clienteDropdownTarget.innerHTML = `
        <div class="px-4 py-3 text-sm text-gray-500">No se encontraron clientes</div>
      `
      this.showDropdown()
      return
    }

    // `this.identifier` y no un nombre fijo: el mismo markup lo usan dos
    // controllers con identificadores distintos.
    const id = this.identifier

    this.clienteDropdownTarget.innerHTML = clientes.map((c, i) => `
      <button type="button"
        class="w-full text-left px-4 py-2 hover:bg-gray-100 dark:hover:bg-gray-700 flex items-center justify-between"
        data-action="click->${id}#selectCliente mousemove->${id}#hoverCliente"
        data-index="${i}"
        data-id="${c.id}"
        data-codigo="${c.codigo}"
        data-nombre="${c.nombre}"
        data-notas="${c.notas_miami || ''}"
        data-categoria="${c.categoria_precio || ''}">
        <div>
          <span class="font-mono text-sm font-medium text-cec-navy dark:text-cec-gold">${c.codigo}</span>
          <span class="ml-2 text-sm text-gray-700 dark:text-gray-200">${c.nombre}</span>
        </div>
        ${c.categoria_precio ? `<span class="text-xs text-gray-500">${c.categoria_precio}</span>` : ''}
      </button>
    `).join("")
    this.showDropdown()
    // El primero queda activo para confirmarlo con Enter sin tocar el mouse:
    // Miami trabaja solo con teclado, "usamos las manos para trabajar".
    this._clienteActiveIndex = 0
    this._highlightActiveCliente()
  }

  // ── Navegación por teclado del dropdown ──
  _clienteItems() {
    return Array.from(this.clienteDropdownTarget.querySelectorAll("[data-index]"))
  }

  _highlightActiveCliente() {
    this._clienteItems().forEach((el, i) => {
      const active = i === this._clienteActiveIndex
      el.classList.toggle("bg-cec-teal/10", active)
      if (active) el.scrollIntoView({ block: "nearest" })
    })
  }

  _moveCliente(delta) {
    const items = this._clienteItems()
    if (items.length === 0) return

    const next = this._clienteActiveIndex + delta
    this._clienteActiveIndex = Math.max(0, Math.min(items.length - 1, next))
    this._highlightActiveCliente()
  }

  hoverCliente(e) {
    const idx = parseInt(e.currentTarget.dataset.index, 10)
    if (Number.isFinite(idx) && idx !== this._clienteActiveIndex) {
      this._clienteActiveIndex = idx
      this._highlightActiveCliente()
    }
  }

  clienteKeydown(e) {
    if (this.clienteDropdownTarget.classList.contains("hidden")) return
    const items = this._clienteItems()

    if (e.key === "ArrowDown") {
      e.preventDefault()
      this._moveCliente(1)
    } else if (e.key === "ArrowUp") {
      e.preventDefault()
      this._moveCliente(-1)
    } else if (e.key === "Enter") {
      const active = items[this._clienteActiveIndex]
      if (active) {
        e.preventDefault() // no enviar el form: solo seleccionar el cliente
        this._selectClienteEl(active)
      }
    } else if (e.key === "Escape") {
      e.preventDefault()
      this.hideDropdown()
    } else if (e.key === "Tab") {
      this.hideDropdown()
    }
  }

  selectCliente(e) {
    this._selectClienteEl(e.currentTarget)
  }

  _selectClienteEl(btn) {
    const { id, codigo, nombre, categoria } = btn.dataset

    this.clienteIdTarget.value = id
    this.clienteInputTarget.value = codigo
    this.clienteNombreTarget.textContent = `${nombre}${categoria ? ` — ${categoria}` : ""}`
    this.clienteNombreTarget.classList.remove("hidden")

    this._alSeleccionarCliente(btn.dataset)
    this.hideDropdown()
  }

  // Gancho para lo propio de cada pantalla. Por defecto no hace nada.
  _alSeleccionarCliente(_datos) {}

  // Al cerrarlo se olvida cuál estaba activo: si no, el próximo Enter sobre un
  // dropdown recién abierto tomaría el índice de la búsqueda anterior.
  hideDropdown() {
    this.clienteDropdownTarget.classList.add("hidden")
    this._clienteActiveIndex = -1
  }

  showDropdown() { this.clienteDropdownTarget.classList.remove("hidden") }

  clickOutsideDropdown(e) {
    if (!this.clienteDropdownTarget.contains(e.target) && e.target !== this.clienteInputTarget) {
      this.hideDropdown()
    }
  }
}
