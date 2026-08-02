import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "cec_wizard_draft"
const FIELD_NAMES = ["titulo", "proveedor", "tracking", "descripcion", "instrucciones"]
const DEBOUNCE_MS = 500

export default class extends Controller {
  static values = { tipoEnvioId: Number, consolidado: Boolean }

  connect() {
    this._restoreDraft()
  }

  saveDraft() {
    clearTimeout(this._timer)
    this._timer = setTimeout(() => {
      const data = {
        tipoEnvioId: this.tipoEnvioIdValue,
        consolidado: this.consolidadoValue
      }
      for (const name of FIELD_NAMES) {
        const el = this.element.querySelector(`[name="${name}"]`)
        if (el) data[name] = el.value
      }
      localStorage.setItem(STORAGE_KEY, JSON.stringify(data))
    }, DEBOUNCE_MS)
  }

  clearDraft() {
    localStorage.removeItem(STORAGE_KEY)
  }

  disconnect() {
    clearTimeout(this._timer)
  }

  // private

  _restoreDraft() {
    let draft
    try {
      draft = JSON.parse(localStorage.getItem(STORAGE_KEY))
    } catch {
      return
    }
    if (!draft || draft.tipoEnvioId !== this.tipoEnvioIdValue) return

    for (const name of FIELD_NAMES) {
      const el = this.element.querySelector(`[name="${name}"]`)
      if (el && !el.value && draft[name]) {
        el.value = draft[name]
      }
    }
  }
}
