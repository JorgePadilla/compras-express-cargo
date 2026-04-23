import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "paquetesBody", "template", "counter", "addButton", "limitMessage", "status", "saveButton", "savedModal"]
  static values = {
    maxPaquetes: { type: Number, default: -1 },
    cancelUrl: { type: String, default: "" },
    consolidado: { type: Boolean, default: false },
    autosaveUrl: { type: String, default: "" },
    autoAdd: { type: Boolean, default: false }
  }

  _newIndex = Date.now()
  _autosaveTimer = null
  _saving = false
  _statusTimer = null

  connect() {
    this._handleGlobalKeydown = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this._handleGlobalKeydown)
    this.updateCounter()

    if (this.consolidadoValue && this.autosaveUrlValue) {
      this._handleInput = this.scheduleAutosave.bind(this)
      this.formTarget.addEventListener("input", this._handleInput)
    }

    if (this.autoAddValue) {
      this.addPaquete()
    }
  }

  disconnect() {
    document.removeEventListener("keydown", this._handleGlobalKeydown)
    if (this._handleInput) {
      this.formTarget.removeEventListener("input", this._handleInput)
    }
    clearTimeout(this._autosaveTimer)
    clearTimeout(this._statusTimer)
    clearTimeout(this._savedModalTimer)
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
      this.finalizar()
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

  async removePaquete(e) {
    const row = e.currentTarget.closest(".paquete-row")
    const visibleRows = this.paquetesBodyTarget.querySelectorAll(".paquete-row:not(.hidden)").length
    const esUltimo = visibleRows <= 1

    const mensaje = esUltimo
      ? "¿Eliminar este paquete? Es el último de la pre-alerta; la pre-alerta quedará vacía y será eliminada."
      : "¿Eliminar este paquete?"

    const ask = typeof window.cecConfirm === "function"
      ? window.cecConfirm
      : (m) => Promise.resolve(window.confirm(m))

    const ok = await ask(mensaje, {
      title: esUltimo ? "Eliminar paquete y pre-alerta" : "Eliminar paquete",
      confirmLabel: "Eliminar",
      danger: true,
    })
    if (!ok) return

    const destroyField = row.querySelector("[data-pre-alerta-editor-target='destroyField']")

    if (destroyField) {
      // Existing record: mark for destruction
      destroyField.value = "1"
      row.classList.add("hidden")
      // Auto-save immediately so deletion persists
      this.autosave()
    } else {
      // New record: remove from DOM
      row.remove()
    }

    this.updateCounter()
  }

  // ── Auto-save ──

  scheduleAutosave() {
    clearTimeout(this._autosaveTimer)
    this._autosaveTimer = setTimeout(() => this.autosave(), 1500)
  }

  async autosave() {
    clearTimeout(this._autosaveTimer)

    if (this._saving || !this.autosaveUrlValue) return false

    const formData = this._buildAutosaveFormData()
    if (!formData) return false

    this._saving = true
    this._showStatus("Guardando...", "text-gray-400")

    try {
      const csrfToken = document.querySelector("meta[name='csrf-token']")?.content
      const response = await fetch(this.autosaveUrlValue, {
        method: "PATCH",
        headers: {
          "Accept": "application/json",
          "X-CSRF-Token": csrfToken
        },
        body: formData
      })

      if (response.ok) {
        const data = await response.json()
        if (data.redirect) {
          window.location.href = data.redirect
          return true
        }
        this._injectNewPaqueteIds(data.new_paquetes || {})
        this._removeDestroyedRows()
        this.updateCounter()
        this._showStatus("Guardado \u2713", "text-cec-teal", 3000)
        return true
      } else if (response.status === 422) {
        const data = await response.json()
        this._showStatus("Error al guardar", "text-red-500", 5000)
        return false
      } else {
        this._showStatus("Error de conexión", "text-red-500", 5000)
        return false
      }
    } catch (error) {
      this._showStatus("Error de conexión", "text-red-500", 5000)
      return false
    } finally {
      this._saving = false
    }
  }

  _buildAutosaveFormData() {
    const formData = new FormData(this.formTarget)
    formData.append("autosave", "true")

    // Find new paquete rows where tracking AND descripcion are both blank — skip them
    const rows = this.paquetesBodyTarget.querySelectorAll(".paquete-row:not(.hidden)")
    const keysToDelete = []

    rows.forEach(row => {
      if (!row.dataset.newRecord) return

      // Find the index from the input name pattern
      const input = row.querySelector("input[name*='[tracking]']")
      if (!input) return
      const match = input.name.match(/\[(\d+)\]/)
      if (!match) return
      const index = match[1]

      const tracking = formData.get(`pre_alerta[pre_alerta_paquetes_attributes][${index}][tracking]`) || ""
      const descripcion = formData.get(`pre_alerta[pre_alerta_paquetes_attributes][${index}][descripcion]`) || ""

      if (tracking.trim() === "" && descripcion.trim() === "") {
        // Remove this incomplete row's fields from formData
        keysToDelete.push(index)
      }
    })

    keysToDelete.forEach(index => {
      const prefix = `pre_alerta[pre_alerta_paquetes_attributes][${index}]`
      for (const key of [...formData.keys()]) {
        if (key.startsWith(prefix)) {
          formData.delete(key)
        }
      }
    })

    return formData
  }

  _injectNewPaqueteIds(newPaquetes) {
    // newPaquetes is { "formIndex": dbId, ... }
    for (const [index, dbId] of Object.entries(newPaquetes)) {
      const row = this._findRowByIndex(index)
      if (!row) continue

      // Remove the data-new-record flag
      delete row.dataset.newRecord

      // Give it an ID for DOM reference
      row.id = `paquete_row_${dbId}`

      const firstTd = row.querySelector("td")

      // Inject hidden id field
      const idInput = document.createElement("input")
      idInput.type = "hidden"
      idInput.name = `pre_alerta[pre_alerta_paquetes_attributes][${index}][id]`
      idInput.value = dbId
      firstTd.prepend(idInput)

      // Inject hidden _destroy field + target so removePaquete works
      const destroyInput = document.createElement("input")
      destroyInput.type = "hidden"
      destroyInput.name = `pre_alerta[pre_alerta_paquetes_attributes][${index}][_destroy]`
      destroyInput.value = "0"
      destroyInput.dataset.preAlertaEditorTarget = "destroyField"
      firstTd.prepend(destroyInput)
    }
  }

  _findRowByIndex(index) {
    const input = this.formTarget.querySelector(`input[name*='[${index}][tracking]']`)
    if (!input) return null
    return input.closest(".paquete-row")
  }

  _removeDestroyedRows() {
    const hiddenRows = this.paquetesBodyTarget.querySelectorAll(".paquete-row.hidden")
    hiddenRows.forEach(row => row.remove())
  }

  static STATUS_COLORS = ["text-gray-400", "text-cec-teal", "text-red-500"]

  _showStatus(message, colorClass, fadeAfterMs = 0) {
    if (!this.hasStatusTarget) return

    clearTimeout(this._statusTimer)
    const el = this.statusTarget
    el.textContent = message
    // Swap only the color class, preserving base classes from the template
    this.constructor.STATUS_COLORS.forEach(c => el.classList.remove(c))
    el.classList.add(colorClass)
    el.style.opacity = "1"

    if (fadeAfterMs > 0) {
      this._statusTimer = setTimeout(() => {
        el.style.opacity = "0"
      }, fadeAfterMs)
    }
  }

  // ── Manual save (flush + confirm modal) ──

  async save() {
    // Cancel any pending debounced autosave
    clearTimeout(this._autosaveTimer)

    // Wait for any in-flight autosave to finish before flushing a new one
    if (this._saving) {
      await this._waitForSaveComplete()
    }

    const ok = await this.autosave()
    if (ok) this._showSavedModal()
  }

  _waitForSaveComplete() {
    return new Promise(resolve => {
      const check = () => {
        if (!this._saving) return resolve()
        setTimeout(check, 100)
      }
      check()
    })
  }

  _showSavedModal() {
    if (!this.hasSavedModalTarget) return
    clearTimeout(this._savedModalTimer)
    this.savedModalTarget.classList.remove("hidden")
    this._savedModalTimer = setTimeout(() => {
      this.savedModalTarget.classList.add("hidden")
    }, 3000)
  }

  // ── Finalize ──

  async finalizar() {
    // Wait for any in-flight auto-save to finish
    if (this._saving) {
      await new Promise(resolve => {
        const check = () => {
          if (!this._saving) return resolve()
          setTimeout(check, 100)
        }
        check()
      })
    }

    this._removeFinalizarField()
    const finalizarInput = document.createElement("input")
    finalizarInput.type = "hidden"
    finalizarInput.name = "finalizar"
    finalizarInput.value = "true"
    finalizarInput.dataset.finalizarField = "true"
    this.formTarget.appendChild(finalizarInput)

    this.formTarget.requestSubmit()
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
