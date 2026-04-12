import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "trackingLabel", "body", "loading", "list", "empty",
                     "form", "papIdField", "destinoField", "confirmBtn"]
  static values  = { destinosUrl: String, moverUrl: String }

  open(event) {
    const papId    = event.currentTarget.dataset.papId
    const tracking = event.currentTarget.dataset.tracking

    this.trackingLabelTarget.textContent = tracking
    this.papIdFieldTarget.value = papId
    this.destinoFieldTarget.value = ""
    this.confirmBtnTarget.disabled = true

    // Show modal
    this.modalTarget.classList.remove("hidden")

    // Show loading, hide others
    this.loadingTarget.classList.remove("hidden")
    this.listTarget.classList.add("hidden")
    this.emptyTarget.classList.add("hidden")

    // Fetch destinations
    const url = `${this.destinosUrlValue}?pre_alerta_paquete_id=${papId}`
    fetch(url, { headers: { "Accept": "application/json" } })
      .then(r => r.json())
      .then(destinos => this.renderDestinos(destinos))
      .catch(() => {
        this.loadingTarget.classList.add("hidden")
        this.emptyTarget.classList.remove("hidden")
      })
  }

  close() {
    this.modalTarget.classList.add("hidden")
    this.listTarget.innerHTML = ""
  }

  selectDestino(event) {
    const id = event.currentTarget.dataset.destinoId

    // Deselect all
    this.listTarget.querySelectorAll("[data-destino-id]").forEach(el => {
      el.classList.remove("ring-2", "ring-cec-teal", "bg-cec-teal/5")
    })

    // Select this one
    event.currentTarget.classList.add("ring-2", "ring-cec-teal", "bg-cec-teal/5")
    this.destinoFieldTarget.value = id
    this.confirmBtnTarget.disabled = false
  }

  renderDestinos(destinos) {
    this.loadingTarget.classList.add("hidden")

    if (destinos.length === 0) {
      this.emptyTarget.classList.remove("hidden")
      return
    }

    this.listTarget.innerHTML = destinos.map(d => `
      <button type="button"
              data-action="click->pre-alerta-mover#selectDestino"
              data-destino-id="${d.id}"
              class="w-full text-left px-4 py-3 rounded-lg border border-gray-200 hover:border-cec-teal/50 transition-colors cursor-pointer">
        <div class="flex items-center justify-between">
          <span class="font-mono text-sm font-bold text-cec-navy">${d.numero_documento}</span>
          <span class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-cec-navy/5 text-cec-navy ring-1 ring-cec-navy/20">
            ${d.tipo_envio}
          </span>
        </div>
        <p class="text-xs text-gray-500 mt-1">
          ${d.titulo || "Sin titulo"} &middot; ${d.paquetes_count} paquete${d.paquetes_count === 1 ? "" : "s"}
        </p>
      </button>
    `).join("")

    this.listTarget.classList.remove("hidden")
  }
}
