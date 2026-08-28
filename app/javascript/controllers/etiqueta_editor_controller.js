import { Controller } from "@hotwired/stimulus"

// C19-06: el editor de la plantilla de la etiqueta, con preview en vivo.
//
// Un solo camino: cualquier cambio serializa el DOM al hidden
// `definicion_json`, y con debounce pide al server el preview — la MISMA
// etiqueta que imprime la Dymo, renderizada con la candidata sin guardar.
// Nada de duplicar la lógica de render en JS: lo que se ve es lo que sale.
//
// El estado «Cabe / Se recorta» mide exactamente lo que mide
// etiqueta_cabe_test en Chrome real: scrollHeight vs clientHeight del .etq.
// `srcdoc` es same-origin, así que se lee directo del contentDocument.
export default class extends Controller {
  static targets = [ "json", "iframe", "estado", "efectivo", "aviso", "escalaLabel" ]
  static values = { previewUrl: String }

  connect() {
    this._timeout = null
    this.refrescar()
  }

  disconnect() {
    if (this._timeout) clearTimeout(this._timeout)
  }

  cambio() {
    this._serializar()
    this._efectivos()
    if (this._timeout) clearTimeout(this._timeout)
    this._timeout = setTimeout(() => this._preview(), 300)
  }

  refrescar() {
    this._serializar()
    this._efectivos()
    this._preview()
  }

  // Guardar con el contenido desbordado no se bloquea — se confirma. La
  // etiqueta es de Yusef; el sistema le avisa, no le manda.
  confirmarSiNoCabe(e) {
    if (!this._noCabe) return
    if (!window.confirm("El contenido no cabe en la etiqueta: se va a recortar al imprimir. ¿Guardar igual?")) {
      e.preventDefault()
    }
  }

  // El iframe avisa cuando el preview terminó de cargar.
  medir() {
    if (!this.hasIframeTarget || !this.hasEstadoTarget) return
    const etq = this.iframeTarget.contentDocument?.querySelector(".etq")
    if (!etq) return

    const sobra = etq.scrollHeight - etq.clientHeight
    this._noCabe = sobra > 0
    if (this._noCabe) {
      this.estadoTarget.textContent = `Se recortan ${sobra}px ✗`
      this.estadoTarget.className = "text-sm font-bold text-red-600"
    } else {
      this.estadoTarget.textContent = "Cabe ✓"
      this.estadoTarget.className = "text-sm font-bold text-cec-teal"
    }
  }

  // ── privados ──

  // El DOM es la fuente: cada input lleva `data-def-path` ("campos.tipo_envio.pt")
  // y el JSON se arma caminando esos paths. Un número mal tecleado se omite:
  // el server pone el default de esa clave (la regla madre de Definicion).
  _serializar() {
    const def = {}
    this.element.querySelectorAll("[data-def-path]").forEach(el => {
      let valor = el.value
      if (el.dataset.defTipo === "num") {
        valor = parseFloat(String(valor).replace(",", "."))
        if (Number.isNaN(valor)) return
      }
      const camino = el.dataset.defPath.split(".")
      let nodo = def
      camino.slice(0, -1).forEach(k => { nodo = (nodo[k] ||= {}) })
      nodo[camino[camino.length - 1]] = valor
    })
    this._def = def
    if (this.hasJsonTarget) this.jsonTarget.value = JSON.stringify(def)
  }

  // El pt EFECTIVO (pt × escala) al lado de cada campo — sin esto, escala y
  // tamaño por campo multiplicándose confunden a cualquiera.
  _efectivos() {
    const escala = (this._def?.escala_pct ?? 100) / 100
    if (this.hasEscalaLabelTarget) this.escalaLabelTarget.textContent = `${this._def?.escala_pct ?? 100}%`
    let mayor = null
    this.efectivoTargets.forEach(el => {
      const valor = this._leer(el.dataset.paraPath)
      if (typeof valor !== "number") return
      const efectivo = Math.round(valor * escala * 100) / 100
      el.textContent = `→ ${efectivo}pt`
      if (el.dataset.paraPath !== "campos.tipo_envio.pt" && (mayor === null || efectivo > mayor)) mayor = efectivo
    })

    // La jerarquía es de Yusef: el tipo de envío es lo más grande. Si él
    // mismo la rompe es su decisión — pero que sea a sabiendas.
    if (this.hasAvisoTarget) {
      const tipoEnvio = this._leer("campos.tipo_envio.pt")
      const roto = typeof tipoEnvio === "number" && mayor !== null && mayor > tipoEnvio * escala
      this.avisoTarget.classList.toggle("hidden", !roto)
    }
  }

  _leer(camino) {
    let nodo = this._def
    camino.split(".").forEach(k => { nodo = nodo?.[k] })
    return nodo
  }

  _preview() {
    if (!this.hasIframeTarget || !this.previewUrlValue) return

    const cuerpo = new FormData()
    cuerpo.append("definicion_json", this.jsonTarget.value)
    const token = document.querySelector("meta[name='csrf-token']")?.content
    fetch(this.previewUrlValue, {
      method: "POST",
      headers: { "X-CSRF-Token": token },
      body: cuerpo
    })
      .then(r => r.text())
      .then(html => { this.iframeTarget.srcdoc = html })
      .catch(e => console.error("[etiqueta-editor] el preview falló", e))
  }
}
