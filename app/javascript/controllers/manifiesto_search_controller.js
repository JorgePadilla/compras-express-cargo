import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "results"]
  static values = { url: String, manifiestoId: String }

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
    this.resultsTarget.textContent = ""

    if (paquetes.length === 0) {
      const p = document.createElement("p")
      p.className = "text-sm text-gray-500 py-2"
      p.textContent = "No se encontraron paquetes sin manifiesto"
      this.resultsTarget.appendChild(p)
      this.resultsTarget.classList.remove("hidden")
      return
    }

    const manifiestoId = this.manifiestoIdValue
    const csrfToken = document.querySelector('meta[name=csrf-token]')?.content || ''
    const container = document.createElement("div")
    container.className = "divide-y divide-gray-100 border rounded-lg"

    paquetes.forEach(p => {
      const row = document.createElement("div")
      row.className = "flex items-center justify-between px-4 py-3 hover:bg-gray-50"

      const info = document.createElement("div")
      const spans = [
        { text: p.guia, cls: "font-mono text-sm font-medium text-cec-navy" },
        { text: p.tracking, cls: "ml-2 text-sm text-gray-500" },
        { text: `${p.cliente_codigo} — ${p.cliente}`, cls: "ml-2 text-sm text-gray-700" },
        { text: `${p.peso_cobrar} lbs`, cls: "ml-2 text-xs text-gray-500" }
      ]
      spans.forEach(({ text, cls }) => {
        const span = document.createElement("span")
        span.className = cls
        span.textContent = text
        info.appendChild(span)
      })

      const form = document.createElement("form")
      form.action = `/manifiestos/${manifiestoId}/add_paquete`
      form.method = "post"
      form.className = "inline"

      const tokenInput = document.createElement("input")
      tokenInput.type = "hidden"
      tokenInput.name = "authenticity_token"
      tokenInput.value = csrfToken

      const idInput = document.createElement("input")
      idInput.type = "hidden"
      idInput.name = "paquete_id"
      idInput.value = p.id

      const btn = document.createElement("button")
      btn.type = "submit"
      btn.className = "px-3 py-1 text-xs font-medium bg-cec-navy text-white rounded hover:bg-cec-navy-light"
      btn.textContent = "Agregar"

      form.append(tokenInput, idInput, btn)
      row.append(info, form)
      container.appendChild(row)
    })

    this.resultsTarget.appendChild(container)
    this.resultsTarget.classList.remove("hidden")
  }
}
