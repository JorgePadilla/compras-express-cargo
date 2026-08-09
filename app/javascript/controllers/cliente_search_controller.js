import BusquedaAutocomplete from "controllers/busqueda_autocomplete"

// Cambiar el CLIENTE de un paquete ya guardado, desde su formulario.
//
// No es un autocomplete suelto: es un panel que arranca cerrado, muestra el
// cliente actual, y solo al apretar "Cambiar" abre la búsqueda. Al elegir otro
// marca el cambio con un badge y ofrece cancelar — porque reasignar un paquete
// a otro cliente es una operación que conviene poder deshacer antes de guardar.
//
// PR-C6.33: la búsqueda de adentro era una de las ocho copias, y de las más
// pobres — 2 caracteres, sin preselección y sin flechas. Ahora hereda de
// `BusquedaAutocomplete`; lo que queda acá es el panel, que sí es propio.
export default class extends BusquedaAutocomplete {
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

  get _oculto() { return this.clienteIdTarget }

  _textoVacio() { return "No se encontraron clientes." }

  _filaHtml(c) {
    return `data-id="${c.id}"
            data-codigo="${c.codigo}"
            data-nombre="${c.nombre}">
        <div class="min-w-0 flex items-baseline gap-2">
          <span class="font-mono text-sm font-bold text-cec-navy dark:text-cec-gold shrink-0">${c.codigo}</span>
          <span class="text-sm text-gray-700 dark:text-gray-200 truncate">${c.nombre}</span>
        </div>
        <span class="text-[10px] font-semibold uppercase tracking-wider text-cec-teal shrink-0">Seleccionar →</span>`
  }

  _alSeleccionar({ id, codigo, nombre }) {
    this.codigoDisplayTarget.textContent = codigo
    this.nombreDisplayTarget.textContent = nombre
    this._marcarCambio(String(id) !== String(this.originalIdValue))
    this.searchPanelTarget.classList.add("hidden")
  }

  // ── El panel, que sí es propio de esta pantalla ──

  toggle(e) {
    e?.preventDefault()
    this.searchPanelTarget.classList.toggle("hidden")
    if (!this.searchPanelTarget.classList.contains("hidden")) this.inputTarget.focus()
  }

  cancelChange(e) {
    e?.preventDefault()
    this.clienteIdTarget.value = this.originalIdValue
    this.codigoDisplayTarget.textContent = this.originalCodigoValue
    this.nombreDisplayTarget.textContent = this.originalNombreValue
    this._marcarCambio(false)
    this.searchPanelTarget.classList.add("hidden")
    this.cerrar()
  }

  _marcarCambio(cambiado) {
    this.changedBadgeTarget.classList.toggle("hidden", !cambiado)
    this.cancelButtonTarget.classList.toggle("hidden", !cambiado)
    this.toggleButtonTarget.classList.toggle("hidden", cambiado)
  }

  // ── Alias en el idioma viejo, para no tocar markup que ya funciona ──
  search() { this.buscar() }
  onKeydown(e) { this.teclado(e) }
  select(e) { this.elegir(e) }
  renderDropdown(items) { this.pintar(items) }
  hideDropdown() { this.cerrar() }
  showDropdown() { this.abrir() }
}
