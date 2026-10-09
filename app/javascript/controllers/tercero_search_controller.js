import BusquedaAutocomplete from "controllers/busqueda_autocomplete"

// Autocomplete del TERCERO — la persona que retira el paquete cuando no es el
// titular. Busca en la misma tabla de clientes pero escribe en otro campo.
//
// Markup esperado:
//   <div data-controller="tercero-search"
//        data-tercero-search-url-value="<%= buscar_clientes_path %>">
//     <input data-tercero-search-target="input"
//            data-action="input->tercero-search#search
//                         keydown->tercero-search#onKeydown">
//     <input type="hidden" data-tercero-search-target="terceroId">
//     <div data-tercero-search-target="dropdown" class="hidden …"></div>
//     <span data-tercero-search-target="nombre" class="hidden …"></span>
//     <button data-tercero-search-target="clearButton"
//             data-action="tercero-search#clear">×</button>
//   </div>
//
// PR-C6.33: era una de ocho copias de la misma interacción. Ya preseleccionaba
// y ya tenía flechas —era de las mejores— pero seguía pidiendo **2
// caracteres**, así que el código de un dígito no la abría. Ahora hereda de
// `BusquedaAutocomplete` y se comporta igual que las demás.
//
// Lo propio de esta pantalla: el botón de limpiar, porque el tercero es
// opcional y hay que poder sacarlo.
export default class extends BusquedaAutocomplete {
  static targets = [ "input", "terceroId", "dropdown", "nombre", "clearButton" ]
  static values = { url: String }

  connect() {
    this.toggleClearButton()
  }

  get _oculto() { return this.terceroIdTarget }
  get _etiqueta() { return this.hasNombreTarget ? this.nombreTarget : null }

  _textoVacio() { return "No se encontraron clientes" }

  _filaHtml(c) {
    return `data-id="${c.id}"
            data-codigo="${c.codigo}"
            data-nombre="${c.nombre}">
        <div>
          <span class="font-mono text-sm font-medium text-cec-navy dark:text-cec-gold">${c.codigo}</span>
          <span class="ml-2 text-sm text-gray-700 dark:text-gray-300">${c.nombre}</span>
        </div>`
  }

  _alSeleccionar(datos) {
    this._campo.value = `${datos.codigo} — ${datos.nombre}`
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
    this.cerrar()
    this.toggleClearButton()
  }

  toggleClearButton() {
    if (!this.hasClearButtonTarget) return

    const hay = this.terceroIdTarget.value !== "" || this.inputTarget.value !== ""
    this.clearButtonTarget.classList.toggle("hidden", !hay)
  }

  // ── Alias en el idioma viejo, para no tocar markup que ya funciona ──
  // Ojo: acá el markup llama `#keydown` y `#hover`, no `#onKeydown` —
  // cada copia había elegido sus propios nombres. Es parte de lo que hacía
  // tan fácil que se fueran separando.
  search() { this.buscar() }
  keydown(e) { this.teclado(e) }
  hover(e) { this.sobrevolar(e) }
  select(e) { this.elegir(e) }
  renderDropdown(items) { this.pintar(items) }
  hideDropdown() { this.cerrar() }
  showDropdown() { this.abrir() }
}
