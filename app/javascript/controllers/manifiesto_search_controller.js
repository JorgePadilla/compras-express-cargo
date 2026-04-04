import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "results"]
  static values = { url: String }

  connect() {
    this._timeout = null
  }

  disconnect() {
    if (this._timeout) clearTimeout(this._timeout)
  }

  search() {
    if (this._timeout) clearTimeout(this._timeout)

    const query = this.inputTarget.value.trim()
    if (query.length < 3) {
      this.resultsTarget.classList.add("hidden")
      return
    }

    this._timeout = setTimeout(() => {
      fetch(`${this.urlValue}?q=${encodeURIComponent(query)}`, {
        headers: { "Accept": "application/json" }
      })
        .then(r => r.json())
        .then(paquetes => this.renderResults(paquetes))
        .catch(() => {
          this.resultsTarget.classList.add("hidden")
        })
    }, 300)
  }

  renderResults(paquetes) {
    if (paquetes.length === 0) {
      this.resultsTarget.innerHTML = `
        <p class="text-sm text-gray-500 py-2">No se encontraron paquetes sin manifiesto</p>
      `
      this.resultsTarget.classList.remove("hidden")
      return
    }

    const manifiestoId = window.location.pathname.split("/").pop()

    this.resultsTarget.innerHTML = `
      <div class="divide-y divide-gray-100 border rounded-lg">
        ${paquetes.map(p => `
          <div class="flex items-center justify-between px-4 py-3 hover:bg-gray-50">
            <div>
              <span class="font-mono text-sm font-medium text-cec-navy">${p.guia}</span>
              <span class="ml-2 text-sm text-gray-500">${p.tracking}</span>
              <span class="ml-2 text-sm text-gray-700">${p.cliente_codigo} — ${p.cliente}</span>
              <span class="ml-2 text-xs text-gray-500">${p.peso_cobrar} lbs</span>
            </div>
            <form action="/manifiestos/${manifiestoId}/add_paquete" method="post" class="inline">
              <input type="hidden" name="authenticity_token" value="${document.querySelector('meta[name=csrf-token]')?.content || ''}">
              <input type="hidden" name="paquete_id" value="${p.id}">
              <button type="submit" class="px-3 py-1 text-xs font-medium bg-cec-navy text-white rounded hover:bg-cec-navy-light">
                Agregar
              </button>
            </form>
          </div>
        `).join("")}
      </div>
    `
    this.resultsTarget.classList.remove("hidden")
  }
}
