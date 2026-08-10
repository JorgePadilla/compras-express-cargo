import BusquedaAutocomplete from "controllers/busqueda_autocomplete"

// Buscar y elegir un CLIENTE. Especializa `BusquedaAutocomplete` con la fila
// del dropdown (código · nombre · categoría) y los targets que usan
// /etiquetar y /entrega_personal.
//
// PR-C6.32 la creó para esas dos pantallas; PR-C6.33 le sacó todo lo que era
// genérico a la base, que ahora comparten también los autocompletes de
// tercero, proveedor, manifiesto y pre-alerta.
//
// No es un controller registrado: el archivo no termina en `_controller`.
export default class ClienteAutocomplete extends BusquedaAutocomplete {
  static targets = [ "clienteInput", "clienteId", "clienteDropdown", "clienteNombre" ]
  static values = { buscarUrl: { type: String, default: "/clientes/buscar" } }

  get _campo() { return this.clienteInputTarget }
  get _lista() { return this.clienteDropdownTarget }
  get _oculto() { return this.hasClienteIdTarget ? this.clienteIdTarget : null }
  get _etiqueta() { return this.hasClienteNombreTarget ? this.clienteNombreTarget : null }
  get _url() { return this.buscarUrlValue }

  _textoVacio() { return "No se encontraron clientes" }

  _filaHtml(c) {
    return `data-id="${c.id}"
            data-codigo="${c.codigo}"
            data-nombre="${c.nombre}"
            data-notas="${c.notas_miami || ""}"
            data-categoria="${c.categoria_precio || ""}"
            data-sucursal-retiro="${c.sucursal_retiro || ""}"
            data-solo-volumetrico-en="${(c.solo_volumetrico_en || []).join(",")}">
        <div>
          <span class="font-mono text-sm font-medium text-cec-navy dark:text-cec-gold">${c.codigo}</span>
          <span class="ml-2 text-sm text-gray-700 dark:text-gray-200">${c.nombre}</span>
        </div>
        ${c.categoria_precio ? `<span class="text-xs text-gray-500">${c.categoria_precio}</span>` : ""}`
  }

  // ── Alias en el idioma viejo ──
  // Las vistas de /etiquetar y /entrega_personal cablean estos nombres. Se
  // mantienen para no tocar markup que ya funciona y está cubierto por tests.
  searchCliente() { this.buscar() }
  clienteKeydown(e) { this.teclado(e) }
  selectCliente(e) { this.elegir(e) }
  hoverCliente(e) { this.sobrevolar(e) }
  hideDropdown() { this.cerrar() }
  showDropdown() { this.abrir() }
  clickOutsideDropdown(e) { this.clickAfuera(e) }
  renderDropdown(items) { this.pintar(items) }

  _alSeleccionar(datos) {
    this._marcarCobroVolumetrico(datos.soloVolumetricoEn)
    this._alSeleccionarCliente(datos)
  }
  _alSeleccionarCliente(_datos) {}

  // PR-C6.41 · RP-04b: le avisa al panel de cálculo en qué servicios este
  // cliente paga SOLO el volumétrico ("mayoristas o clientes grandes", Yusef).
  //
  // Va acá, en la base, y no en cada pantalla: /etiquetar y /entrega_personal
  // harían exactamente lo mismo, y la duplicación entre esas dos gemelas ya
  // mordió cuatro veces en este proyecto. Así ninguna se puede olvidar.
  _marcarCobroVolumetrico(lista) {
    const calc = this.element.querySelector("[data-controller~='calc-volumetrico']")
    if (!calc) return

    const ids = (lista || "").split(",").filter(Boolean).map(Number)
    calc.dataset.calcVolumetricoSoloVolumetricoEnValue = JSON.stringify(ids)
  }
}
