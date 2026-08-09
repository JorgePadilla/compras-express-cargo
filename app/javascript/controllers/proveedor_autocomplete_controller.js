import BusquedaAutocomplete from "controllers/busqueda_autocomplete"

// Autocomplete de PROVEEDOR (Amazon, Walmart, el driver de entrega personal…).
//
// Markup esperado:
//   <div data-controller="proveedor-autocomplete"
//        data-proveedor-autocomplete-url-value="<%= buscar_proveedores_path %>">
//     <input data-proveedor-autocomplete-target="input"
//            data-action="input->proveedor-autocomplete#search
//                         keydown->proveedor-autocomplete#onKeydown">
//     <input type="hidden" data-proveedor-autocomplete-target="proveedorId">
//     <div data-proveedor-autocomplete-target="dropdown" class="hidden …"></div>
//     <span data-proveedor-autocomplete-target="nombre" class="hidden …"></span>
//   </div>
//
// PR-C6.33. Era de las más pobres de las ocho copias: pedía 2 caracteres, no
// preseleccionaba nada y no respondía a las flechas — o sea que solo se podía
// usar con el mouse. Ahora hereda de `BusquedaAutocomplete`.
//
// Lo propio de esta pantalla: el campo queda con el **nombre** (no el código,
// como en cliente) porque el operario piensa en "Amazon", no en "AMZN"; el
// código va al lado entre paréntesis. Y las filas marcan con una etiqueta los
// proveedores de entrega personal, que es lo que distingue a un driver de una
// tienda.
export default class extends BusquedaAutocomplete {
  static targets = [ "input", "proveedorId", "dropdown", "nombre" ]
  static values = { url: String }

  get _oculto() { return this.proveedorIdTarget }

  _textoVacio() { return "Sin resultados — pedile a admin que cree el proveedor" }

  _filaHtml(p) {
    return `data-id="${p.id}"
            data-codigo="${p.codigo}"
            data-nombre="${p.nombre}"
            data-tipo="${p.tipo || ""}">
        <div>
          <span class="font-mono text-sm font-medium text-cec-navy dark:text-cec-gold">${p.codigo}</span>
          <span class="ml-2 text-sm text-gray-700 dark:text-gray-300">${p.nombre}</span>
        </div>
        ${p.tipo === "entrega_personal" ? `<span class="text-[10px] uppercase tracking-wider px-1.5 py-0.5 rounded bg-cec-gold/20 text-cec-gold-dark">EP</span>` : ""}`
  }

  _alSeleccionar(datos) {
    this._campo.value = datos.nombre
    if (this.hasNombreTarget) {
      this.nombreTarget.textContent = `(${datos.codigo})`
      this.nombreTarget.classList.remove("hidden")
    }
  }

  // ── Alias en el idioma viejo, para no tocar markup que ya funciona ──
  search() { this.buscar() }
  onKeydown(e) { this.teclado(e) }
  select(e) { this.elegir(e) }
  renderDropdown(items) { this.pintar(items) }
  hideDropdown() { this.cerrar() }
  showDropdown() { this.abrir() }
}
