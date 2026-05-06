import { Controller } from "@hotwired/stimulus"

// Lupa de búsqueda para filtrar paquetes por pre-alerta. Reusa el endpoint
// pre_alertas#buscar (ya existe), que devuelve:
//   [{ id, numero, titulo, cliente, consolidado, estado }, ...]
//
// Markup esperado:
//   <div data-controller="pre-alerta-search"
//        data-pre-alerta-search-url-value="<%= buscar_pre_alertas_path %>">
//     <input data-pre-alerta-search-target="input"
//            data-action="input->pre-alerta-search#search">
//     <input type="hidden" name="pre_alerta_id"
//            data-pre-alerta-search-target="preAlertaId">
//     <div data-pre-alerta-search-target="dropdown" class="hidden …"></div>
//     <p   data-pre-alerta-search-target="nombre"   class="hidden …"></p>
//   </div>
export default class extends Controller {
  static targets = ["input", "preAlertaId", "dropdown", "nombre"]
  static values  = { url: String }

  connect() {
    this._timeout = null
  }

  disconnect() {
    if (this._timeout) clearTimeout(this._timeout)
  }

  search() {
    if (this._timeout) clearTimeout(this._timeout)

    const query = this.inputTarget.value.trim()
    if (query.length === 0) {
      // Si el input se vacía, limpiar el FK y ocultar dropdown
      this.preAlertaIdTarget.value = ""
      if (this.hasNombreTarget) this.nombreTarget.classList.add("hidden")
      this.hideDropdown()
      return
    }
    if (query.length < 2) {
      this.hideDropdown()
      return
    }

    this._timeout = setTimeout(() => {
      fetch(`${this.urlValue}?q=${encodeURIComponent(query)}`, {
        headers: { "Accept": "application/json" }
      })
        .then(r => r.json())
        .then(items => this.renderDropdown(items))
        .catch(() => this.hideDropdown())
    }, 300)
  }

  renderDropdown(items) {
    this.dropdownTarget.replaceChildren()

    if (items.length === 0) {
      const empty = document.createElement("div")
      empty.className = "px-4 py-3 text-sm text-gray-500"
      empty.textContent = "No se encontraron pre-alertas"
      this.dropdownTarget.appendChild(empty)
      this.showDropdown()
      return
    }

    items.forEach(pa => {
      const btn = document.createElement("button")
      btn.type = "button"
      btn.className = "w-full text-left px-4 py-2 hover:bg-gray-100 dark:hover:bg-gray-700 flex flex-col gap-0.5"
      btn.dataset.action = "click->pre-alerta-search#select"
      btn.dataset.id        = pa.id
      btn.dataset.numero    = pa.numero
      btn.dataset.titulo    = pa.titulo || ""
      btn.dataset.cliente   = pa.cliente || ""

      const top = document.createElement("div")
      top.className = "flex items-center gap-2"

      const numeroSpan = document.createElement("span")
      numeroSpan.className = "font-mono text-sm font-medium text-cec-navy dark:text-cec-gold"
      numeroSpan.textContent = pa.numero
      top.appendChild(numeroSpan)

      if (pa.consolidado) {
        const badge = document.createElement("span")
        badge.className = "inline-flex items-center px-1.5 py-0.5 rounded text-[10px] font-medium bg-cec-gold/10 text-cec-gold-dark"
        badge.textContent = "Consolidado"
        top.appendChild(badge)
      }
      btn.appendChild(top)

      if (pa.titulo) {
        const tit = document.createElement("span")
        tit.className = "text-xs text-gray-700 dark:text-gray-300"
        tit.textContent = pa.titulo
        btn.appendChild(tit)
      }
      if (pa.cliente) {
        const cli = document.createElement("span")
        cli.className = "text-xs text-gray-500 dark:text-gray-400"
        cli.textContent = pa.cliente
        btn.appendChild(cli)
      }
      this.dropdownTarget.appendChild(btn)
    })
    this.showDropdown()
  }

  select(e) {
    const btn = e.currentTarget
    this.preAlertaIdTarget.value = btn.dataset.id
    this.inputTarget.value = btn.dataset.numero
    if (this.hasNombreTarget) {
      const partes = [btn.dataset.titulo, btn.dataset.cliente].filter(Boolean)
      this.nombreTarget.textContent = partes.join(" · ")
      this.nombreTarget.classList.toggle("hidden", partes.length === 0)
    }
    this.hideDropdown()
  }

  hideDropdown() { this.dropdownTarget.classList.add("hidden") }
  showDropdown() { this.dropdownTarget.classList.remove("hidden") }
}
