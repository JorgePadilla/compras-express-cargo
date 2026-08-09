import { Controller } from "@hotwired/stimulus"

// PR-6: flow separado para entrega personal. Versión simplificada del
// etiquetar_controller — no necesita lookup de duplicado de tracking
// (el tracking se genera automático EP-YYYY-SUC-PROV-NNNNNN) ni
// detección de pre-alerta. Reutiliza el patrón de modal cantidad cajas.
export default class extends Controller {
  static targets = [
    "form", "clienteInput", "clienteId", "clienteDropdown", "clienteNombre",
    "event", "panel"
  ]

  connect() {
    this._searchTimeout = null
    this._handleGlobalKeydown = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this._handleGlobalKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this._handleGlobalKeydown)
    if (this._searchTimeout) clearTimeout(this._searchTimeout)
  }

  handleKeydown(e) {
    if (e.key === "F2") {
      e.preventDefault()
      this.clearForm()
    } else if (e.key === "F9") {
      e.preventDefault()
      this.submitFormWithPrint()
    }
  }

  // Client autocomplete — mismo patrón que etiquetar.
  searchCliente() {
    if (this._searchTimeout) clearTimeout(this._searchTimeout)

    const query = this.clienteInputTarget.value.trim()
    if (query.length < 2) {
      this.hideDropdown()
      return
    }

    this._searchTimeout = setTimeout(() => {
      fetch(`/clientes/buscar?q=${encodeURIComponent(query)}`, {
        headers: { "Accept": "application/json" }
      })
        .then(r => r.json())
        .then(clientes => this.renderDropdown(clientes))
        .catch(() => this.hideDropdown())
    }, 300)
  }

  renderDropdown(clientes) {
    if (clientes.length === 0) {
      this.clienteDropdownTarget.innerHTML = `<div class="px-4 py-3 text-sm text-gray-500">No se encontraron clientes</div>`
      this.showDropdown()
      return
    }

    this.clienteDropdownTarget.innerHTML = clientes.map(c => `
      <button type="button"
        class="w-full text-left px-4 py-2 hover:bg-gray-100 dark:hover:bg-gray-700 flex items-center justify-between"
        data-action="click->entrega-personal#selectCliente"
        data-id="${c.id}"
        data-codigo="${c.codigo}"
        data-nombre="${c.nombre}">
        <div>
          <span class="font-mono text-sm font-medium text-cec-navy dark:text-cec-gold">${c.codigo}</span>
          <span class="ml-2 text-sm text-gray-700 dark:text-gray-200">${c.nombre}</span>
        </div>
      </button>
    `).join("")
    this.showDropdown()
  }

  selectCliente(e) {
    const btn = e.currentTarget
    this.clienteIdTarget.value = btn.dataset.id
    this.clienteInputTarget.value = btn.dataset.codigo
    this.clienteNombreTarget.textContent = btn.dataset.nombre
    this.clienteNombreTarget.classList.remove("hidden")
    // PR-9.b: jalar tareas + notas del cliente a la franja de la derecha.
    this.loadPanel(btn.dataset.id)
    this.hideDropdown()
  }

  // Recarga el turbo-frame de la franja. Sin tracking que pasar: en entrega
  // personal el tracking lo genera el sistema al guardar (EP-AÑO-SUC-PROV-N).
  loadPanel(clienteId) {
    if (!this.hasPanelTarget) return

    const frame = this.panelTarget.querySelector("turbo-frame#panel_contexto")
    if (!frame) return

    const base = this.panelTarget.dataset.panelUrl
    const url = clienteId ? `${base}?cliente_id=${encodeURIComponent(clienteId)}` : base
    if (frame.getAttribute("src") !== url) frame.setAttribute("src", url)
  }

  hideDropdown() { this.clienteDropdownTarget.classList.add("hidden") }
  showDropdown() { this.clienteDropdownTarget.classList.remove("hidden") }

  // Submit + modal de cajas (mismo patrón de PR-4 etiquetar).
// PR-C6.31: F9 guarda e imprime, y nada mas.
//
// Antes abria un modal "cuantas cajas?" que preguntaba lo MISMO que el campo
// visible "Cant. Cajas" del formulario — y peor: lo reseteaba a 1 antes de
// preguntar, asi que pisaba lo que el operario acababa de escribir. Es el
// mismo modal que se saco de /etiquetar cuando Jorge dijo que "el F9 era
// como confuso".
submitFormWithPrint() {
  this._submitWithPrint()
}

  _submitWithPrint() {
    this._removePrintField()
    const input = document.createElement("input")
    input.type = "hidden"
    input.name = "print"
    input.value = "true"
    input.dataset.printField = "true"
    this.formTarget.appendChild(input)
    this.formTarget.requestSubmit()
  }

  _removePrintField() {
    const existing = this.formTarget.querySelector("[data-print-field]")
    if (existing) existing.remove()
  }

  clearForm() {
    this.formTarget.reset()
    if (this.hasClienteIdTarget) this.clienteIdTarget.value = ""
    if (this.hasClienteNombreTarget) {
      this.clienteNombreTarget.textContent = ""
      this.clienteNombreTarget.classList.add("hidden")
    }
    // PR-9.b: la franja vuelve a su estado vacío junto con el formulario.
    this.loadPanel(null)
  }

  // Handle turbo stream events después del save.
  eventTargetConnected(el) {
    if (el.dataset.action !== "paquete-saved") return
    this.dispatch("success")
    if (el.dataset.print === "true") {
      // PR-10.d: la ETIQUETA (Dymo 2.25x1.25), no el Warehouse Receipt.
        // Yusef: "aqui esta tirando el warehouse, no la etiqueta".
        // `hermanas=1` saca una por caja cuando el tracking se dividio.
        window.open(`/paquetes/${el.dataset.paqueteId}/etiqueta?hermanas=1&print=true`, "_blank")
    }
    setTimeout(() => this.clearForm(), 100)
    el.remove()
  }
}
