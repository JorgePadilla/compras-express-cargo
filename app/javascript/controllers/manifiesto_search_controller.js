import { Controller } from "@hotwired/stimulus"

// Agregar paquetes al manifiesto — buscando o **escaneando**.
//
// Jorge: *"la parte de agregar paquetes tiene que ser rápida, escanear"*. La
// pistola dispara Enter al terminar de leer, así que Enter **agrega** en vez de
// solo buscar: el operario escanea uno atrás de otro sin soltar la pistola ni
// tocar el mouse. Es la misma regla que ya rige `/etiquetar`, donde Enter nunca
// guarda a medias — acá agrega **solo si hay una coincidencia sola**, que es lo
// que hace que no meta el paquete equivocado.
export default class extends Controller {
  static targets = ["input", "results", "aviso"]
  static values = { url: String, manifiestoId: String, agregarUrl: String }

  connect() {
    this._timeout = null
  }

  // La pistola termina con Enter. Si lo escaneado devuelve **uno solo**, entra
  // derecho; si devuelve varios, se muestran para elegir en vez de adivinar.
  teclado(e) {
    if (e.key !== "Enter") return
    e.preventDefault()

    const query = this.inputTarget.value.trim()
    if (query.length < 3) return

    if (this._timeout) clearTimeout(this._timeout)
    this._buscar(query, { agregarSiEsUno: true })
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

    this._timeout = setTimeout(() => this._buscar(query), 300)
  }

  _buscar(query, { agregarSiEsUno = false } = {}) {
    fetch(`${this.urlValue}?q=${encodeURIComponent(query)}`, {
      headers: { "Accept": "application/json" }
    })
      .then(r => r.json())
      .then(paquetes => {
        if (agregarSiEsUno && paquetes.length === 1) return this._agregar(paquetes[0])
        if (agregarSiEsUno && paquetes.length === 0) {
          return this._avisar("error", `No se encontró ningún paquete libre con «${query}».`)
        }
        if (agregarSiEsUno) this._avisar("alerta", `«${query}» devolvió ${paquetes.length}: elegí cuál.`)
        this.renderResults(paquetes)
      })
      .catch(() => {
        this.resultsTarget.classList.add("hidden")
        this._avisar("error", "No se pudo consultar. Probá de nuevo.")
      })
  }

  // Manda el mismo POST que el botón «Agregar» de la lista, para que los dos
  // caminos entren por la misma puerta y el turbo_stream refresque la tabla y
  // los botones de cierre.
  _agregar(paquete) {
    const cuerpo = new FormData()
    cuerpo.append("paquete_id", paquete.id)
    cuerpo.append("authenticity_token", document.querySelector("meta[name=csrf-token]")?.content || "")

    fetch(this.agregarUrlValue, {
      method: "POST",
      headers: { "Accept": "text/vnd.turbo-stream.html" },
      body: cuerpo
    })
      .then(r => r.text())
      .then(html => {
        window.Turbo.renderStreamMessage(html)
        this._limpiar()
        this._avisar("ok", `${paquete.tracking} agregado.`)
      })
      .catch(() => this._avisar("error", "No se pudo agregar. Probá de nuevo."))
  }

  // Listo para el siguiente escaneo: campo vacío y con el foco puesto, sin
  // tocar el mouse.
  _limpiar() {
    this.inputTarget.value = ""
    this.resultsTarget.classList.add("hidden")
    this.resultsTarget.textContent = ""
    this.inputTarget.focus()
  }

  _avisar(tipo, mensaje) {
    if (!this.hasAvisoTarget) return

    const estilos = {
      ok:     "bg-cec-teal/10 text-cec-teal-deep",
      alerta: "bg-cec-gold/15 text-cec-navy",
      error:  "bg-red-50 text-red-700"
    }
    this.avisoTarget.className = `mt-3 rounded-lg p-3 text-sm ${estilos[tipo]}`
    this.avisoTarget.textContent = mensaje
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
        { text: p.tracking, cls: "font-mono text-sm font-medium text-cec-navy" },
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
