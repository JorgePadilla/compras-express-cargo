import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "paquetesBody", "template", "counter", "addButton", "limitMessage"]
  static values = {
    maxPaquetes: { type: Number, default: -1 },
    cancelUrl: { type: String, default: "" },
    consolidado: { type: Boolean, default: false }
  }

  _newIndex = Date.now()

  connect() {
    this._handleGlobalKeydown = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this._handleGlobalKeydown)
    this.updateCounter()

    // Auto-add a blank row for consolidated pre-alertas so the next line is ready
    if (this.hasAddButtonTarget && !this.isAtLimit()) {
      this.addPaquete()
    }
  }

  disconnect() {
    document.removeEventListener("keydown", this._handleGlobalKeydown)
  }

  handleKeydown(e) {
    if (e.key === "F2" || e.key === "Escape") {
      e.preventDefault()
      this.cancel()
    } else if (e.key === "F6") {
      e.preventDefault()
      this.addPaquete()
    } else if (e.key === "F8") {
      e.preventDefault()
      this.save()
    } else if (e.key === "F9") {
      e.preventDefault()
      this.saveAndNotify()
    }
  }

  cancel() {
    if (this.cancelUrlValue) {
      Turbo.visit(this.cancelUrlValue)
    }
  }

  addPaquete(e) {
    if (this.isAtLimit()) {
      if (e) e.preventDefault()
      this.showLimitMessage()
      return
    }

    const template = this.templateTarget.content.cloneNode(true)
    const row = template.querySelector(".paquete-row")

    // Replace NEW_INDEX with unique index
    this._newIndex++
    row.innerHTML = row.innerHTML.replaceAll("NEW_INDEX", this._newIndex.toString())

    this.paquetesBodyTarget.appendChild(row)

    // Focus the tracking field in the new row
    const trackingInput = row.querySelector("input[type='text']")
    if (trackingInput) trackingInput.focus()

    this.updateCounter()
  }

  removePaquete(e) {
    const row = e.currentTarget.closest(".paquete-row")
    const destroyField = row.querySelector("[data-pre-alerta-editor-target='destroyField']")

    if (destroyField) {
      // Existing record: mark for destruction
      destroyField.value = "1"
      row.classList.add("hidden")
    } else {
      // New record: remove from DOM
      row.remove()
    }

    this.updateCounter()
  }

  save() {
    this._removeNotifyField()
    this.formTarget.requestSubmit()
  }

  saveAndNotify() {
    this._removeNotifyField()
    const notifyInput = document.createElement("input")
    notifyInput.type = "hidden"
    notifyInput.name = "notificar"
    notifyInput.value = "true"
    notifyInput.dataset.notifyField = "true"
    this.formTarget.appendChild(notifyInput)

    if (this.consolidadoValue) {
      this._removeFinalizarField()
      const finalizarInput = document.createElement("input")
      finalizarInput.type = "hidden"
      finalizarInput.name = "finalizar"
      finalizarInput.value = "true"
      finalizarInput.dataset.finalizarField = "true"
      this.formTarget.appendChild(finalizarInput)
    }

    this.formTarget.requestSubmit()
  }

  _removeNotifyField() {
    const existing = this.formTarget.querySelector("[data-notify-field]")
    if (existing) existing.remove()
  }

  _removeFinalizarField() {
    const existing = this.formTarget.querySelector("[data-finalizar-field]")
    if (existing) existing.remove()
  }

  // ── v4 max-paquetes-por-accion enforcement ──

  currentPackageCount() {
    if (!this.hasPaquetesBodyTarget) return 0
    return this.paquetesBodyTarget.querySelectorAll(".paquete-row:not(.hidden)").length
  }

  isAtLimit() {
    return this.maxPaquetesValue > 0 && this.currentPackageCount() >= this.maxPaquetesValue
  }

  updateCounter() {
    if (!this.hasCounterTarget) return
    const count = this.currentPackageCount()
    const max = this.maxPaquetesValue
    if (max > 0) {
      this.counterTarget.textContent = `${count}/${max}`
      this.counterTarget.classList.toggle("text-red-600", count >= max)
      this.counterTarget.classList.toggle("text-gray-500", count < max)
    } else {
      this.counterTarget.textContent = `${count}`
    }

    if (this.hasAddButtonTarget) {
      const disabled = this.isAtLimit()
      this.addButtonTarget.disabled = disabled
      this.addButtonTarget.classList.toggle("opacity-50", disabled)
      this.addButtonTarget.classList.toggle("cursor-not-allowed", disabled)
    }

    if (this.hasLimitMessageTarget) {
      this.limitMessageTarget.classList.toggle("hidden", !this.isAtLimit())
    }
  }

  showLimitMessage() {
    if (this.hasLimitMessageTarget) {
      this.limitMessageTarget.classList.remove("hidden")
    }
  }
}
