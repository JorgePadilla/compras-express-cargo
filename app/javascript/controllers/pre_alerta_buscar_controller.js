import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "filterInput", "loading", "list", "empty",
                    "form", "paqueteIdField", "confirmBtn", "selectedLabel"]
  static values  = { paquetesUrl: String, agregarUrl: String }

  open() {
    this.modalTarget.classList.remove("hidden")
    this.filterInputTarget.value = ""
    this.paqueteIdFieldTarget.value = ""
    this.confirmBtnTarget.disabled = true
    this.selectedLabelTarget.textContent = "Selecciona un paquete para agregar"

    this.loadingTarget.classList.remove("hidden")
    this.listTarget.classList.add("hidden")
    this.emptyTarget.classList.add("hidden")

    fetch(this.paquetesUrlValue, { headers: { "Accept": "application/json" } })
      .then(r => r.json())
      .then(paquetes => {
        this.paquetes = paquetes
        this.render(paquetes)
      })
      .catch(() => {
        this.loadingTarget.classList.add("hidden")
        this.emptyTarget.classList.remove("hidden")
      })
  }

  close() {
    this.modalTarget.classList.add("hidden")
    this.listTarget.innerHTML = ""
  }

  filter() {
    const q = this.filterInputTarget.value.toLowerCase().trim()
    if (!this.paquetes) return
    const filtered = q === ""
      ? this.paquetes
      : this.paquetes.filter(p =>
          (p.tracking || "").toLowerCase().includes(q) ||
          (p.descripcion || "").toLowerCase().includes(q)
        )
    this.render(filtered)
  }

  selectPaquete(event) {
    const id = event.currentTarget.dataset.paqueteId
    const tracking = event.currentTarget.dataset.tracking
    this.listTarget.querySelectorAll("[data-paquete-id]").forEach(el => {
      el.classList.remove("ring-2", "ring-cec-teal", "bg-cec-teal/5")
    })
    event.currentTarget.classList.add("ring-2", "ring-cec-teal", "bg-cec-teal/5")
    this.paqueteIdFieldTarget.value = id
    this.confirmBtnTarget.disabled = false
    this.selectedLabelTarget.textContent = `Paquete seleccionado: ${tracking}`
  }

  render(paquetes) {
    this.loadingTarget.classList.add("hidden")

    if (!paquetes || paquetes.length === 0) {
      this.listTarget.classList.add("hidden")
      this.emptyTarget.classList.remove("hidden")
      return
    }
    this.emptyTarget.classList.add("hidden")
    this.listTarget.classList.remove("hidden")

    const cubeIcon = `<svg class="w-5 h-5 text-cec-navy" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" d="M21 7.5l-9-5.25L3 7.5m18 0l-9 5.25m9-5.25v9l-9 5.25M3 7.5l9 5.25M3 7.5v9l9 5.25m0-9v9"/></svg>`
    const scaleIcon = `<svg class="w-3 h-3" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" d="M12 3v17.25m0 0c-1.472 0-2.882.265-4.185.75M12 20.25c1.472 0 2.882.265 4.185.75M18.75 4.97A48.416 48.416 0 0012 4.5c-2.291 0-4.545.16-6.75.47m13.5 0c.34.059.68.124 1.02.194 1.1.225 1.98 1.11 1.98 2.235v2.227a1 1 0 01-.293.707L17.5 13.5h3.75M6 4.97L4.73 8.97a1 1 0 01-.293.707L2.25 11.818V13.5H6"/></svg>`
    const calendarIcon = `<svg class="w-3 h-3" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" d="M6.75 3v2.25M17.25 3v2.25M3 18.75V7.5a2.25 2.25 0 012.25-2.25h13.5A2.25 2.25 0 0121 7.5v11.25m-18 0A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75m-18 0v-7.5A2.25 2.25 0 015.25 9h13.5A2.25 2.25 0 0121 11.25v7.5"/></svg>`
    const arrowIcon = `<svg class="w-3 h-3" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" d="M15.75 9V5.25A2.25 2.25 0 0013.5 3h-6a2.25 2.25 0 00-2.25 2.25v13.5A2.25 2.25 0 007.5 21h6a2.25 2.25 0 002.25-2.25V15M12 9l-3 3m0 0l3 3m-3-3h12.75"/></svg>`
    const sparklesIcon = `<svg class="w-3 h-3" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" d="M9.813 15.904L9 18.75l-.813-2.846a4.5 4.5 0 00-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 003.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 003.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 00-3.09 3.09zM18.259 8.715L18 9.75l-.259-1.035a3.375 3.375 0 00-2.455-2.456L14.25 6l1.036-.259a3.375 3.375 0 002.455-2.456L18 2.25l.259 1.035a3.375 3.375 0 002.456 2.456L21.75 6l-1.035.259a3.375 3.375 0 00-2.456 2.456zM16.894 20.567L16.5 21.75l-.394-1.183a2.25 2.25 0 00-1.423-1.423L13.5 18.75l1.183-.394a2.25 2.25 0 001.423-1.423l.394-1.183.394 1.183a2.25 2.25 0 001.423 1.423l1.183.394-1.183.394a2.25 2.25 0 00-1.423 1.423z"/></svg>`
    const truckIcon = `<svg class="w-3 h-3" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" d="M8.25 18.75a1.5 1.5 0 01-3 0m3 0a1.5 1.5 0 00-3 0m3 0h6m-9 0H3.375a1.125 1.125 0 01-1.125-1.125V14.25m17.25 4.5a1.5 1.5 0 01-3 0m3 0a1.5 1.5 0 00-3 0m3 0h1.125c.621 0 1.129-.504 1.09-1.124a17.902 17.902 0 00-3.213-9.193 2.056 2.056 0 00-1.58-.86H14.25M16.5 18.75h-2.25m0-11.177v-.958c0-.568-.422-1.048-.987-1.106a48.554 48.554 0 00-10.026 0 1.106 1.106 0 00-.987 1.106v7.635m12-6.677v6.677m0 4.5v-4.5m0 0h-12"/></svg>`

    this.listTarget.innerHTML = paquetes.map(p => {
      const origenBadge = p.origen
        ? `<span class="inline-flex items-center gap-1 text-[10px] font-medium text-amber-700 bg-amber-50 px-2 py-0.5 rounded-full ring-1 ring-amber-200 shrink-0">
             ${arrowIcon}
             <span>De ${this.escape(p.origen.numero)}</span>
           </span>`
        : `<span class="inline-flex items-center gap-1 text-[10px] font-medium text-emerald-700 bg-emerald-50 px-2 py-0.5 rounded-full ring-1 ring-emerald-200 shrink-0">
             ${sparklesIcon}
             <span>Suelto en bodega</span>
           </span>`

      const tipoEnvioBadge = `<span class="inline-flex items-center gap-1 text-[10px] font-semibold text-indigo-700 bg-indigo-50 px-2 py-0.5 rounded-full ring-1 ring-indigo-200 shrink-0">
             ${truckIcon}
             <span>${this.escape(p.tipo_envio)}</span>
           </span>`

      return `
        <button type="button"
                data-action="click->pre-alerta-buscar#selectPaquete"
                data-paquete-id="${p.id}"
                data-tracking="${this.escape(p.tracking)}"
                class="w-full text-left px-4 py-3 rounded-xl border border-gray-200 hover:border-cec-teal/50 transition-colors cursor-pointer flex gap-3">
          <div class="w-10 h-10 shrink-0 rounded-lg bg-cec-navy/5 flex items-center justify-center">
            ${cubeIcon}
          </div>
          <div class="flex-1 min-w-0">
            <div class="flex items-center justify-between gap-2">
              <span class="font-mono text-sm font-bold text-cec-navy truncate">${this.escape(p.tracking)}</span>
              <div class="flex items-center gap-1 shrink-0">
                ${tipoEnvioBadge}
                ${origenBadge}
              </div>
            </div>
            <p class="text-xs text-gray-600 truncate mt-0.5">${this.escape(p.descripcion)}</p>
            <div class="flex items-center gap-3 mt-1 text-[11px] text-gray-400">
              <span class="inline-flex items-center gap-1">
                ${scaleIcon}
                ${p.peso_cobrar || 0} lbs
              </span>
              <span class="inline-flex items-center gap-1">
                ${calendarIcon}
                ${p.fecha_recibido || "—"}
              </span>
              <span class="inline-flex items-center gap-1 text-cec-teal font-medium">
                ${this.escape(p.estado_label)}
              </span>
            </div>
          </div>
        </button>
      `
    }).join("")
  }

  escape(str) {
    if (str == null) return ""
    return String(str)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#39;")
  }
}
