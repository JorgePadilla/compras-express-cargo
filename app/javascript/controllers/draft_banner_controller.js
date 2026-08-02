import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "cec_wizard_draft"

export default class extends Controller {
  static targets = ["card", "titulo", "info", "emptyState", "continueLink"]

  connect() {
    let draft
    try {
      draft = JSON.parse(localStorage.getItem(STORAGE_KEY))
    } catch {
      return
    }
    if (!draft) return

    const hasContent = draft.titulo || draft.tracking || draft.descripcion ||
                       draft.proveedor || draft.instrucciones
    if (!hasContent) return

    if (this.hasTituloTarget) {
      this.tituloTarget.textContent = draft.titulo || draft.tracking || "Pre-alerta sin título"
    }
    if (this.hasInfoTarget) {
      const parts = []
      if (draft.proveedor) parts.push(draft.proveedor)
      if (draft.tracking) parts.push(draft.tracking)
      this.infoTarget.textContent = parts.join(" · ")
    }
    if (this.hasContinueLinkTarget && draft.tipoEnvioId) {
      const params = new URLSearchParams({
        resume: "1",
        tipo_envio_id: draft.tipoEnvioId,
        consolidado: draft.consolidado ? "1" : "0",
        step: "3"
      })
      this.continueLinkTarget.href = `${this.continueLinkTarget.href.split("?")[0]}?${params}`
    }
    if (this.hasCardTarget) {
      this.cardTarget.classList.remove("hidden")
    }
    if (this.hasEmptyStateTarget) {
      this.emptyStateTarget.classList.add("hidden")
    }
  }

  discard(event) {
    event.preventDefault()
    localStorage.removeItem(STORAGE_KEY)
    if (this.hasCardTarget) {
      this.cardTarget.classList.add("hidden")
    }
    if (this.hasEmptyStateTarget) {
      this.emptyStateTarget.classList.remove("hidden")
    }
  }
}
