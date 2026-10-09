import BusquedaAutocomplete from "controllers/busqueda_autocomplete"

// Autocomplete de Cliente para /pre_alertas/new y el form de paquete.
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
// PR-C6.33: era una de ocho copias de la misma interacción. Pedía **2
// caracteres** para buscar y **nunca preseleccionaba** el primer resultado, así
// que Enter no hacía nada — que es lo que Yusef reportó como "preseleccionar
// de los dropdown". Ahora hereda de `BusquedaAutocomplete` y se comporta igual
// que la de /etiquetar.
//
// Lo único propio de esta pantalla: al elegir, el campo queda con
// `CODIGO — Nombre` en vez de solo el código. Es un form de captura, no una
// estación de escaneo: acá el operario quiere leer a quién eligió.
export default class extends BusquedaAutocomplete {
  static targets = [ "input", "clienteId", "dropdown", "nombre" ]
  static values = { url: String }

  get _oculto() { return this.clienteIdTarget }
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
  }

  // ── Alias en el idioma viejo, para no tocar markup que ya funciona ──
  search() { this.buscar() }
  onKeydown(e) { this.teclado(e) }
  select(e) { this.elegir(e) }
  hideDropdown() { this.cerrar() }
  showDropdown() { this.abrir() }
}
