import BusquedaAutocomplete from "controllers/busqueda_autocomplete"

// Autocomplete de PRE-ALERTA — para enganchar un paquete a la pre-alerta que
// lo estaba esperando.
//
// Markup esperado:
//   <div data-controller="pre-alerta-search"
//        data-pre-alerta-search-url-value="<%= buscar_pre_alertas_path %>">
//     <input data-pre-alerta-search-target="input"
//            data-action="input->pre-alerta-search#search
//                         keydown->pre-alerta-search#onKeydown">
//     <input type="hidden" data-pre-alerta-search-target="preAlertaId">
//     <div data-pre-alerta-search-target="dropdown" class="hidden …"></div>
//     <span data-pre-alerta-search-target="nombre" class="hidden …"></span>
//   </div>
//
// PR-C6.33: octava y última copia de la misma interacción. Tenía flechas pero
// no preseleccionaba, y pedía 2 caracteres. Ahora hereda de
// `BusquedaAutocomplete`.
//
// Lo propio de esta pantalla: la fila muestra el número de documento, marca
// las consolidadas (que son las que aceptan más de un paquete) y debajo pone
// título y cliente, porque un `PA-000123` suelto no le dice nada a nadie.
export default class extends BusquedaAutocomplete {
  static targets = [ "input", "preAlertaId", "dropdown", "nombre" ]
  static values = { url: String }

  get _oculto() { return this.preAlertaIdTarget }

  _textoVacio() { return "No se encontraron pre-alertas" }

  _filaHtml(pa) {
    return `data-id="${pa.id}"
            data-numero="${pa.numero}"
            data-titulo="${pa.titulo || ""}"
            data-cliente="${pa.cliente || ""}">
        <div>
          <span class="font-mono text-sm font-medium text-cec-navy dark:text-cec-gold">${pa.numero}</span>
          ${pa.consolidado ? `<span class="ml-2 text-[10px] uppercase tracking-wider px-1.5 py-0.5 rounded bg-cec-teal/15 text-cec-teal-dark">Consolidado</span>` : ""}
          ${pa.titulo ? `<span class="block text-sm text-gray-700 dark:text-gray-300">${pa.titulo}</span>` : ""}
          ${pa.cliente ? `<span class="block text-xs text-gray-500">${pa.cliente}</span>` : ""}
        </div>`
  }

  _alSeleccionar(datos) {
    this._campo.value = datos.numero
    if (this.hasNombreTarget) {
      const partes = [ datos.titulo, datos.cliente ].filter(Boolean)
      this.nombreTarget.textContent = partes.join(" · ")
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
