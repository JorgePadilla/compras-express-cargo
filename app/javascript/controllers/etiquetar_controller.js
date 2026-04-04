import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "form", "tracking", "clienteInput", "clienteId", "clienteDropdown",
    "clienteNombre", "notasBanner", "notasTexto", "duplicateModal",
    "duplicateInfo", "submitBtn", "event"
  ]
  static values = {
    checkUrl: String,
    buscarUrl: String
  }

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
    } else if (e.key === "F8") {
      e.preventDefault()
      this.submitForm()
    } else if (e.key === "F9") {
      e.preventDefault()
      this.submitFormWithPrint()
    }
  }

  // Client autocomplete
  searchCliente() {
    if (this._searchTimeout) clearTimeout(this._searchTimeout)

    const query = this.clienteInputTarget.value.trim()
    if (query.length < 2) {
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

  renderDropdown(clientes) {
    if (clientes.length === 0) {
      this.clienteDropdownTarget.innerHTML = `
        <div class="px-4 py-3 text-sm text-gray-500">No se encontraron clientes</div>
      `
      this.showDropdown()
      return
    }

    this.clienteDropdownTarget.innerHTML = clientes.map(c => `
      <button type="button"
        class="w-full text-left px-4 py-2 hover:bg-gray-100 flex items-center justify-between"
        data-action="click->etiquetar#selectCliente"
        data-id="${c.id}"
        data-codigo="${c.codigo}"
        data-nombre="${c.nombre}"
        data-notas="${c.notas_miami || ''}"
        data-categoria="${c.categoria_precio || ''}">
        <div>
          <span class="font-mono text-sm font-medium text-cec-navy">${c.codigo}</span>
          <span class="ml-2 text-sm text-gray-700">${c.nombre}</span>
        </div>
        ${c.categoria_precio ? `<span class="text-xs text-gray-500">${c.categoria_precio}</span>` : ''}
      </button>
    `).join("")
    this.showDropdown()
  }

  selectCliente(e) {
    const btn = e.currentTarget
    const id = btn.dataset.id
    const codigo = btn.dataset.codigo
    const nombre = btn.dataset.nombre
    const notas = btn.dataset.notas
    const categoria = btn.dataset.categoria

    this.clienteIdTarget.value = id
    this.clienteInputTarget.value = codigo
    this.clienteNombreTarget.textContent = `${nombre}${categoria ? ` — ${categoria}` : ''}`
    this.clienteNombreTarget.classList.remove("hidden")

    if (notas && notas.trim() !== "") {
      this.notasTextoTarget.textContent = notas
      this.notasBannerTarget.classList.remove("hidden")
      // Trigger audio alert for client notes
      this.dispatch("clienteNotas")
    } else {
      this.notasBannerTarget.classList.add("hidden")
    }

    this.hideDropdown()
  }

  hideDropdown() {
    this.clienteDropdownTarget.classList.add("hidden")
  }

  showDropdown() {
    this.clienteDropdownTarget.classList.remove("hidden")
  }

  clickOutsideDropdown(e) {
    if (!this.clienteDropdownTarget.contains(e.target) && e.target !== this.clienteInputTarget) {
      this.hideDropdown()
    }
  }

  // Duplicate tracking detection
  checkTracking() {
    const tracking = this.trackingTarget.value.trim()
    if (tracking.length < 5) return

    fetch(`${this.checkUrlValue}?tracking=${encodeURIComponent(tracking)}`, {
      headers: { "Accept": "application/json" }
    })
      .then(r => r.json())
      .then(data => {
        if (data.exists && !data.terminal) {
          const info = this.duplicateInfoTarget
          info.textContent = ""
          const lines = [
            { text: "Tracking duplicado encontrado", cls: "font-medium" },
            { text: `Guia: ${data.guia}`, cls: "mt-1" },
            { text: `Cliente: ${data.cliente}`, cls: "" },
            { text: `Estado: ${data.estado} — Fecha: ${data.fecha}`, cls: "" },
            { text: `${data.count} paquete(s) con este tracking`, cls: "text-sm text-gray-500 mt-1" }
          ]
          lines.forEach(({ text, cls }) => {
            const p = document.createElement("p")
            p.textContent = text
            if (cls) p.className = cls
            info.appendChild(p)
          })
          this.duplicateModalTarget.classList.remove("hidden")
        }
      })
      .catch(() => {})
  }

  closeDuplicate() {
    this.duplicateModalTarget.classList.add("hidden")
  }

  continueDuplicate() {
    this.duplicateModalTarget.classList.add("hidden")
    // Focus next field
    this.clienteInputTarget.focus()
  }

  // Form actions
  clearForm() {
    this.formTarget.reset()
    this.clienteIdTarget.value = ""
    this.clienteNombreTarget.textContent = ""
    this.clienteNombreTarget.classList.add("hidden")
    this.notasBannerTarget.classList.add("hidden")
    this.duplicateModalTarget.classList.add("hidden")
    this.trackingTarget.focus()
  }

  submitForm() {
    this._removePrintField()
    this.formTarget.requestSubmit()
  }

  submitFormWithPrint() {
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

  // Handle turbo stream events
  eventTargetConnected(el) {
    const action = el.dataset.action
    if (action === "paquete-saved") {
      // Trigger success audio
      this.dispatch("success")

      if (el.dataset.print === "true") {
        window.open(`/paquetes/${el.dataset.paqueteId}/label`, "_blank")
      }

      // Clear form after successful save
      setTimeout(() => this.clearForm(), 100)
      el.remove()
    }
  }
}
