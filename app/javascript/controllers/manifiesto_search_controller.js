import { Controller } from "@hotwired/stimulus"

// Agregar paquetes al manifiesto — buscando o **escaneando**.
//
// Jorge: *"la parte de agregar paquetes tiene que ser rápida, escanear"*. La
// pistola dispara Enter al terminar de leer, así que Enter **agrega** en vez de
// solo buscar: el operario escanea uno atrás de otro sin soltar la pistola ni
// tocar el mouse. Es la misma regla que ya rige `/etiquetar`, donde Enter nunca
// guarda a medias.
//
// C28-04 · Y ahora **dice por qué**. Antes buscaba solo entre los paquetes sin
// manifiesto, y «ya está adentro» salía igual que «no existe»: *«No se
// encontró ningún paquete libre»*. Yusef: *"el mensaje está malo"*. El
// servidor clasifica (`manifiestos#escanear`) y acá cada respuesta tiene su
// forma:
//
//   ok              → se agrega (`add_paquete`), aviso verde con el warehouse
//   en_este         → aviso chico, sin modal: *"es error de dedo"*
//   varios          → la lista para elegir, sin adivinar
//   en_otro         → modal: *"¿desea agregarlo a este y retirarlo del otro?"*
//   en_otro_cerrado → modal rojo, sin mover: esa hoja ya viajó
//   tipo_distinto   → modal rojo: *"ahí sí, porque genera gasto"*
//   sucursal_distinta → modal rojo (C29-07): *"algo similar al tipo de
//                     envío, el modal así. Exactamente así"*
//   no_encontrado   → modal rojo
//
// Y siempre, con o sin error, el campo queda vacío y con el foco: *"cuando hay
// un error, siempre hay que limpiarlo"*.
export default class extends Controller {
  static targets = ["input", "results", "aviso",
                    "avisoModal", "avisoTitulo", "avisoTexto", "avisoMover", "avisoEntendido"]
  static values = { url: String, escanearUrl: String, agregarUrl: String, moverUrl: String }

  connect() {
    this._timeout = null
    this._seq = 0
    // El foco vuelve al campo cuando se cierra el modal, por donde sea.
    this._alCerrar = () => this.inputTarget.focus()
    if (this.hasAvisoModalTarget) this.avisoModalTarget.addEventListener("close", this._alCerrar)
  }

  disconnect() {
    if (this._timeout) clearTimeout(this._timeout)
    if (this.hasAvisoModalTarget) this.avisoModalTarget.removeEventListener("close", this._alCerrar)
  }

  // La pistola termina con Enter.
  teclado(e) {
    if (e.key !== "Enter") return
    e.preventDefault()

    const codigo = this.inputTarget.value.trim()
    if (codigo.length < 3) return

    if (this._timeout) clearTimeout(this._timeout)
    this._limpiar()
    this._escanear({ codigo })
  }

  // Escribir a mano sigue mostrando los paquetes sin manifiesto para elegir.
  search() {
    if (this._timeout) clearTimeout(this._timeout)

    const query = this.inputTarget.value.trim()
    if (query.length < 3) {
      this.resultsTarget.classList.add("hidden")
      return
    }

    this._timeout = setTimeout(() => this._buscar(query), 300)
  }

  _buscar(query) {
    fetch(`${this.urlValue}?q=${encodeURIComponent(query)}`, { headers: { "Accept": "application/json" } })
      .then((r) => r.json())
      .then((paquetes) => this.renderResults(paquetes))
      .catch(() => this.resultsTarget.classList.add("hidden"))
  }

  // ── El escaneo ──────────────────────────────────────────────────────────

  _escanear(cuerpo) {
    const consulta = (this._seq += 1)
    this._post(this.escanearUrlValue, cuerpo)
      .then((data) => {
        if (consulta !== this._seq) return  // llegó tarde: habla de otro escaneo
        this._resolver(data)
      })
      .catch(() => {
        this.dispatch("noEncontrado")
        this._abrirAviso("No se pudo consultar", "Probá de nuevo.", null)
      })
  }

  // Los `dispatch` van con el nombre **literal**, uno por rama: es lo que
  // `sonidos_cableados_test` puede leer. Y el `showModal()` va en el mismo
  // método que su `dispatch`, para que ningún modal abra mudo.
  _resolver(data) {
    switch (data.resultado) {
      case "ok":
        this.dispatch("ok")
        this._agregar(data.paquete, data.mensaje)
        return
      case "en_este":
        this.dispatch("enEste")
        this._avisar("alerta", data.mensaje)
        return
      case "varios":
        this.dispatch("varios")
        this._avisar("alerta", data.mensaje)
        this.renderResults(data.paquetes)
        return
      case "en_otro":
        this.dispatch("enOtro")
        this._abrirAviso("Está en otro manifiesto", data.mensaje, data.paquete)
        this.avisoModalTarget.showModal()
        break
      case "en_otro_cerrado":
        this.dispatch("cerrado")
        this._abrirAviso("Ese manifiesto ya salió", data.mensaje, null)
        this.avisoModalTarget.showModal()
        break
      case "tipo_distinto":
        this.dispatch("tipoDistinto")
        this._abrirAviso("Tipo de envío distinto", data.mensaje, null)
        this.avisoModalTarget.showModal()
        break
      case "sucursal_distinta":
        this.dispatch("sucursalDistinta")
        this._abrirAviso("Va a otra sucursal", data.mensaje, null)
        this.avisoModalTarget.showModal()
        break
      // C30-06 · El candado: una pestaña vieja escaneando en un manifiesto que
      // ya se finalizó, o que un supervisor volvió a cerrar. Suena como el
      // que ya salió, y dice por qué.
      case "bloqueado":
        this.dispatch("cerrado")
        this._abrirAviso("El manifiesto está bloqueado", data.mensaje, null)
        this.avisoModalTarget.showModal()
        break
      case "fuera_de_circulacion":
        this.dispatch("fuera")
        this._abrirAviso("Ese paquete ya no viaja", data.mensaje, null)
        this.avisoModalTarget.showModal()
        break
      default:
        this.dispatch("noEncontrado")
        this._abrirAviso("No se encontró", data.mensaje, null)
        this.avisoModalTarget.showModal()
    }
    // Con el modal abierto, Enter tiene que apretar el botón que importa.
    requestAnimationFrame(() => {
      const principal = this.avisoMoverTarget.hidden ? this.avisoEntendidoTarget : this.avisoMoverTarget
      principal.focus()
    })
  }

  _abrirAviso(titulo, texto, paquete) {
    this.avisoTituloTarget.textContent = titulo
    this.avisoTextoTarget.textContent = texto
    // «Moverlo a este» sólo cuando está en otro **abierto**. Por el atributo
    // y no por la clase: `.inline-flex` le gana a `.hidden`.
    this.avisoMoverTarget.hidden = !paquete
    this.avisoMoverTarget.dataset.paqueteId = paquete ? paquete.id : ""
  }

  avisoEntendido() {
    this.avisoModalTarget.close()
  }

  // C20-13 · Escape no contesta un aviso: *"ellos no las leen"*.
  avisoCancelar(e) {
    e.preventDefault()
  }

  // *"¿Desea agregar este a este manifiesto y retirarlo del otro?"*
  mover() {
    const paqueteId = this.avisoMoverTarget.dataset.paqueteId
    if (!paqueteId) return

    this._turbo(this.moverUrlValue, paqueteId)
      .then(() => this._avisar("ok", "Movido a este manifiesto."))
      .catch(() => this._avisar("error", "No se pudo mover. Probá de nuevo."))
      .finally(() => this.avisoModalTarget.close())
  }

  // Manda el mismo POST que siempre, para que el turbo_stream refresque la
  // tabla y los botones de cierre.
  _agregar(paquete, mensaje) {
    this._turbo(this.agregarUrlValue, paquete.id)
      .then(() => this._avisar("ok", mensaje))
      .catch(() => this._avisar("error", "No se pudo agregar. Probá de nuevo."))
  }

  _turbo(url, paqueteId) {
    const cuerpo = new FormData()
    cuerpo.append("paquete_id", paqueteId)
    cuerpo.append("authenticity_token", this._token())

    return fetch(url, { method: "POST", headers: { "Accept": "text/vnd.turbo-stream.html" }, body: cuerpo })
      .then((r) => {
        if (!r.ok) throw new Error(r.status)
        return r.text()
      })
      .then((html) => window.Turbo.renderStreamMessage(html))
  }

  _post(url, cuerpo) {
    return fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json", "Accept": "application/json", "X-CSRF-Token": this._token() },
      body: JSON.stringify(cuerpo)
    }).then((r) => r.json())
  }

  _token() {
    return document.querySelector("meta[name=csrf-token]")?.content || ""
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

  // ── La lista para elegir ────────────────────────────────────────────────
  //
  // Cada «Agregar» pasa por `escanear` con el `paquete_id`: lo elegido de la
  // lista contesta las mismas preguntas que lo escaneado, y no hay un segundo
  // camino que agregue sin mirar el tipo de envío.
  elegir(e) {
    this.resultsTarget.classList.add("hidden")
    this._escanear({ paquete_id: e.currentTarget.dataset.paqueteId })
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

    const container = document.createElement("div")
    container.className = "divide-y divide-gray-100 border rounded-lg"

    paquetes.forEach((p) => {
      const row = document.createElement("div")
      row.className = "flex items-center justify-between px-4 py-3 hover:bg-gray-50"

      const info = document.createElement("div")
      const spans = [
        { text: p.codigo || p.tracking, cls: "font-mono text-sm font-medium text-cec-navy" },
        { text: p.codigo ? p.tracking : "", cls: "ml-2 font-mono text-xs text-gray-500" },
        { text: `${p.cliente_codigo} — ${p.cliente}`, cls: "ml-2 text-sm text-gray-700" },
        { text: `${p.peso_cobrar} lbs`, cls: "ml-2 text-xs text-gray-500" }
      ]
      spans.filter(({ text }) => text).forEach(({ text, cls }) => {
        const span = document.createElement("span")
        span.className = cls
        span.textContent = text
        info.appendChild(span)
      })

      const btn = document.createElement("button")
      btn.type = "button"
      btn.className = "min-h-11 px-4 text-sm font-medium bg-cec-navy text-white rounded hover:bg-cec-navy-light"
      btn.textContent = "Agregar"
      btn.setAttribute("aria-label", `Agregar ${p.codigo || p.tracking} al manifiesto`)
      btn.dataset.paqueteId = p.id
      btn.dataset.action = "manifiesto-search#elegir"

      row.append(info, btn)
      container.appendChild(row)
    })

    this.resultsTarget.appendChild(container)
    this.resultsTarget.classList.remove("hidden")
  }
}
