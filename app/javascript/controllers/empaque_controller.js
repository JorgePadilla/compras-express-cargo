import { Controller } from "@hotwired/stimulus"

// C21-01 · El escaneo al empacar.
//
// Yusef, mostrando la bodega en vivo mientras empacaban: *"ahí están empacando,
// mirá… y aquí es donde hace falta, **es el pip pip pip**"*.
//
// El operario mira la pistola, no la pantalla, así que **lo que decide es el
// sonido**. Por eso cada resultado dispara su evento y la vista los cablea a
// `audio#success` / `audio#error` / `audio#alert`.
//
// La pistola dispara Enter al terminar de leer — la misma mecánica de
// /etiquetar. Y va con el guard de carrera de siempre (`_seq`): si el operario
// escanea dos seguidos, la respuesta vieja no puede pintar encima de la nueva
// ni sonar por un paquete que ya no está en pantalla.
export default class extends Controller {
  static targets = ["codigo", "aviso", "filas"]
  static values = { escanearUrl: String, omitirUrl: String }

  connect() {
    this._seq = 0
    if (this.hasCodigoTarget) this.codigoTarget.focus()
  }

  teclado(e) {
    if (e.key !== "Enter") return
    e.preventDefault()
    this.escanear()
  }

  escanear() {
    const codigo = this.codigoTarget.value.trim()
    if (codigo === "") return

    const consulta = (this._seq += 1)
    this.codigoTarget.value = ""

    this._post(this.escanearUrlValue, { codigo })
      .then((data) => {
        if (consulta !== this._seq) return  // llegó tarde: habla de otro escaneo
        this._resolver(data)
      })
      .catch(() => {
        this.dispatch("noEncontrado")
        this._mostrar("noEncontrado", "No se pudo consultar. Probá de nuevo.")
      })
  }

  // C21-01 · «Omitir»: lo mete igual aunque el tipo no concuerde. La Fase 12 lo
  // pidió *"para no trabar la operación cuando algo no cuadra"*.
  omitir(e) {
    const paqueteId = e.currentTarget.dataset.paqueteId
    this._post(this.omitirUrlValue, { paquete_id: paqueteId })
      .then((data) => this._resolver(data))
      .finally(() => this.codigoTarget.focus())
  }

  // Los `dispatch` van con el nombre **literal**, uno por rama. Con un
  // `dispatch(variable)` el sonido igual sonaría, pero `sonidos_cableados_test`
  // no podría probarlo leyendo el archivo — y ése es justo el bug que ese lint
  // existe para atrapar: un cable suelto en Stimulus no tira error, no ensucia
  // la consola; simplemente no suena.
  _resolver(data) {
    switch (data.resultado) {
      case "ok":            this.dispatch("ok"); break
      case "tipo_distinto": this.dispatch("tipoDistinto"); break
      case "ya_empacado":   this.dispatch("yaEmpacado"); break
      default:              this.dispatch("noEncontrado")
    }
    this._mostrar(this._tono(data.resultado), data.mensaje, data.paquete_id)
    if (data.fila) this._agregarFila(data.fila)
    this.codigoTarget.focus()
  }

  _tono(resultado) {
    return { ok: "ok", tipo_distinto: "tipoDistinto", ya_empacado: "yaEmpacado" }[resultado] || "noEncontrado"
  }

  _mostrar(evento, mensaje, paqueteId) {
    if (!this.hasAvisoTarget) return

    const tonos = {
      ok: "bg-cec-teal/10 text-cec-teal-dark",
      tipoDistinto: "bg-red-50 text-red-800",
      yaEmpacado: "bg-cec-gold/15 text-cec-navy",
      noEncontrado: "bg-cec-gold/15 text-cec-navy"
    }
    this.avisoTarget.className = `mt-4 rounded-lg p-3 text-sm ${tonos[evento] || tonos.noEncontrado}`
    this.avisoTarget.textContent = mensaje
    this.avisoTarget.classList.remove("hidden")

    if (evento === "tipoDistinto" && paqueteId) this._botonOmitir(paqueteId)
  }

  _botonOmitir(paqueteId) {
    const boton = document.createElement("button")
    boton.type = "button"
    boton.textContent = "Meterlo igual (omitir)"
    boton.className = "ml-3 underline font-medium"
    boton.dataset.paqueteId = paqueteId
    boton.dataset.action = "click->empaque#omitir"
    this.avisoTarget.appendChild(boton)
  }

  _agregarFila(fila) {
    if (!this.hasFilasTarget) return
    const tr = document.createElement("tr")
    const celdas = [
      ["px-6 py-3 text-sm font-mono text-cec-navy", fila.recepcion],
      ["px-6 py-3 text-sm font-mono text-gray-500", fila.tracking],
      ["px-6 py-3 text-sm text-gray-700", fila.cliente],
      ["px-6 py-3 text-sm text-gray-500", fila.tipo]
    ]
    celdas.forEach(([cls, texto]) => {
      const td = document.createElement("td")
      td.className = cls
      td.textContent = texto || "—"
      tr.appendChild(td)
    })
    this.filasTarget.prepend(tr)
  }

  _post(url, cuerpo) {
    const token = document.querySelector("meta[name='csrf-token']")?.content
    return fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json", "Accept": "application/json", "X-CSRF-Token": token },
      body: JSON.stringify(cuerpo)
    }).then((r) => r.json())
  }
}
