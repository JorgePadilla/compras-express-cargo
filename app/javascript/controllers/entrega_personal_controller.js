import { Controller } from "@hotwired/stimulus"

// PR-6: flow separado para entrega personal. Versión simplificada del
// etiquetar_controller — no necesita lookup de duplicado de tracking
// (el tracking se genera automático EP-YYYY-SUC-PROV-NNNNNN) ni
// detección de pre-alerta. Reutiliza el patrón de modal cantidad cajas.
export default class extends Controller {
  static targets = [
    "form", "clienteInput", "clienteId", "clienteDropdown", "clienteNombre",
    "cajasModal", "cajasInput", "cantidadPaquetesHidden",
    "event"
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
    this.hideDropdown()
  }

  hideDropdown() { this.clienteDropdownTarget.classList.add("hidden") }
  showDropdown() { this.clienteDropdownTarget.classList.remove("hidden") }

  // Submit + modal de cajas (mismo patrón de PR-4 etiquetar).
  submitFormWithPrint() {
    if (!this.hasCajasModalTarget) {
      this._submitWithPrint()
      return
    }
    this._resetCantidadPaquetes()
    if (this.hasCajasInputTarget) this.cajasInputTarget.value = "1"
    if (typeof this.cajasModalTarget.showModal === "function") {
      this.cajasModalTarget.showModal()
    } else {
      this.cajasModalTarget.setAttribute("open", "")
    }
    setTimeout(() => {
      if (this.hasCajasInputTarget) {
        this.cajasInputTarget.focus()
        this.cajasInputTarget.select()
      }
    }, 50)
  }

  cancelCajas() { this._closeCajasModal() }

  cajasKeydown(e) {
    if (e.key === "Enter") {
      e.preventDefault()
      this.confirmCajas()
    } else if (e.key === "Escape") {
      e.preventDefault()
      this.cancelCajas()
    }
  }

  confirmCajas() {
    const raw = this.hasCajasInputTarget ? parseInt(this.cajasInputTarget.value, 10) : 1
    const n = Number.isFinite(raw) ? Math.max(1, Math.min(26, raw)) : 1
    if (this.hasCantidadPaquetesHiddenTarget) this.cantidadPaquetesHiddenTarget.value = String(n)
    this._closeCajasModal()
    this._submitWithPrint()
  }

  _closeCajasModal() {
    if (!this.hasCajasModalTarget) return
    if (typeof this.cajasModalTarget.close === "function") {
      this.cajasModalTarget.close()
    } else {
      this.cajasModalTarget.removeAttribute("open")
    }
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

  _resetCantidadPaquetes() {
    if (this.hasCantidadPaquetesHiddenTarget) this.cantidadPaquetesHiddenTarget.value = "1"
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
    this._closeCajasModal()
    this._resetCantidadPaquetes()
  }

  // Handle turbo stream events después del save.
  eventTargetConnected(el) {
    if (el.dataset.action !== "paquete-saved") return
    this.dispatch("success")
    if (el.dataset.print === "true") {
      window.open(`/paquetes/${el.dataset.paqueteId}/label`, "_blank")
    }
    setTimeout(() => this.clearForm(), 100)
    el.remove()
  }
}
