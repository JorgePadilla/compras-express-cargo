import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "paquetesBody", "template"]

  _newIndex = Date.now()

  connect() {
    this._handleGlobalKeydown = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this._handleGlobalKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this._handleGlobalKeydown)
  }

  handleKeydown(e) {
    if (e.key === "F6") {
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

  addPaquete() {
    const template = this.templateTarget.content.cloneNode(true)
    const row = template.querySelector("tr")

    // Replace NEW_INDEX with unique index
    this._newIndex++
    row.innerHTML = row.innerHTML.replaceAll("NEW_INDEX", this._newIndex.toString())

    // Auto-populate fecha with today's date
    const dateInput = row.querySelector("input[type='date']")
    if (dateInput) dateInput.value = new Date().toISOString().split("T")[0]

    this.paquetesBodyTarget.appendChild(row)

    // Focus the tracking field in the new row
    const trackingInput = row.querySelector("input[type='text']")
    if (trackingInput) trackingInput.focus()
  }

  removePaquete(e) {
    const row = e.currentTarget.closest("tr")
    const destroyField = row.querySelector("[data-pre-alerta-editor-target='destroyField']")

    if (destroyField) {
      // Existing record: mark for destruction
      destroyField.value = "1"
      row.classList.add("hidden")
    } else {
      // New record: remove from DOM
      row.remove()
    }
  }

  save() {
    this._removeNotifyField()
    this.formTarget.requestSubmit()
  }

  saveAndNotify() {
    this._removeNotifyField()
    const input = document.createElement("input")
    input.type = "hidden"
    input.name = "notificar"
    input.value = "true"
    input.dataset.notifyField = "true"
    this.formTarget.appendChild(input)
    this.formTarget.requestSubmit()
  }

  _removeNotifyField() {
    const existing = this.formTarget.querySelector("[data-notify-field]")
    if (existing) existing.remove()
  }
}
