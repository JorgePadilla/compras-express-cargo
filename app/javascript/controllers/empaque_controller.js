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
  static targets = ["codigo", "aviso", "filas", "caja", "tarjeta", "candado", "conteo", "destino", "listaAbiertas"]
  static values = { escanearUrl: String, omitirUrl: String, activa: Number }

  connect() {
    this._seq = 0
    if (this.hasCodigoTarget) this.codigoTarget.focus()
  }

  // ── C23-11 · Varias cajas abiertas ────────────────────────────────────────
  //
  // Yusef: *"poder **seleccionar las tres cajas**"* · *"ellos arman tres cajas
  // y empiezan a meter los paquetes en **cualquier** caja"*.
  //
  // Un paquete sigue yendo en UNA caja: lo que cambia es que ya no hay que
  // **ir a buscarla**. Elegir caja era un `link_to` que recargaba la pantalla,
  // y con eso el campo de escaneo perdía el foco — con la pistola en la otra
  // mano, un clic por cada cambio de caja. Acá solo se mueve a dónde apunta el
  // POST, y el foco vuelve al campo siempre.

  elegirCaja(e) {
    const bloque = e.currentTarget.closest("[data-caja-id]")
    // Una caja cerrada no recibe escaneos: tocarla la abre, que es lo que el
    // operario quiso decir al tocarla.
    if (bloque.dataset.abierta !== "true") return this.alternarCaja(e)

    this._activar(Number(bloque.dataset.cajaId))
    this.codigoTarget.focus()
  }

  alternarCaja(e) {
    const bloque = e.currentTarget.closest("[data-caja-id]")

    this._post(bloque.dataset.alternarUrl, {})
      .then((data) => {
        // «Mínimo uno»: el servidor es el que decide, y si dice que no, lo dice
        // con todas las letras en vez de dejar la tarjeta a medio apagar.
        if (!data.ok) return this._mostrar("noEncontrado", data.mensaje)

        this.cajaTargets.forEach((caja) => {
          caja.dataset.abierta = String(data.abiertas.includes(Number(caja.dataset.cajaId)))
        })
        this._pintar()
        this._activar(data.activa)
      })
      .finally(() => this.codigoTarget.focus())
  }

  _activar(cajaId) {
    this.activaValue = cajaId
    const bloque = this.cajaTargets.find((c) => Number(c.dataset.cajaId) === cajaId)
    if (!bloque) return

    this.escanearUrlValue = bloque.dataset.escanearUrl
    this.omitirUrlValue = bloque.dataset.omitirUrl
    this._pintar()
  }

  // Las clases se arman acá y no en el servidor porque nada recarga: si el
  // pintado viviera solo en el ERB, la tarjeta activa se quedaría marcando la
  // caja anterior hasta el próximo refresh.
  _pintar() {
    const ACTIVA = ["border-cec-gold", "bg-cec-gold/5", "ring-2", "ring-cec-gold/30"]
    const ABIERTA = ["border-gray-200", "dark:border-gray-700", "bg-white", "dark:bg-gray-800",
                     "hover:shadow-lg", "hover:border-cec-gold/50"]
    const CERRADA = ["border-dashed", "border-gray-300", "dark:border-gray-700",
                     "bg-gray-50", "dark:bg-gray-900", "opacity-60"]

    this.cajaTargets.forEach((caja) => {
      const tarjeta = caja.querySelector("[data-empaque-target='tarjeta']")
      const abierta = caja.dataset.abierta === "true"
      const activa = Number(caja.dataset.cajaId) === this.activaValue && abierta

      tarjeta.classList.remove(...ACTIVA, ...ABIERTA, ...CERRADA)
      tarjeta.classList.add(...(activa ? ACTIVA : abierta ? ABIERTA : CERRADA))
      tarjeta.setAttribute("aria-pressed", String(activa))

      // El candado: los dos iconos están en el DOM y se alterna cuál se ve.
      const candado = caja.querySelector("[data-empaque-target='candado']")
      candado.querySelector("[data-icono='abierta']").classList.toggle("hidden", !abierta)
      candado.querySelector("[data-icono='cerrada']").classList.toggle("hidden", abierta)

      if (activa && this.hasDestinoTarget) {
        this.destinoTarget.textContent = tarjeta.querySelector("span").textContent.trim()
      }
    })

    this._pintarTabla()
  }

  // Lo que el servidor pintó una vez y acá ya no se recarga nunca: el título
  // que enumera las abiertas y las filas de las cajas que se cerraron. Sin
  // esto los dos se quedan diciendo el set del primer render — el título
  // listando cajas que ya nadie está llenando, y la tabla mostrando lo que hay
  // adentro de una caja cerrada.
  _pintarTabla() {
    const abiertas = this.cajaTargets.filter((c) => c.dataset.abierta === "true")

    if (this.hasListaAbiertasTarget) {
      this.listaAbiertasTarget.textContent = abiertas
        .map((c) => c.querySelector("[data-empaque-target='tarjeta'] span").textContent.trim())
        .join(", ")
    }

    if (!this.hasFilasTarget) return
    const ids = abiertas.map((c) => c.dataset.cajaId)
    this.filasTarget.querySelectorAll("tr[data-caja-id]").forEach((fila) => {
      fila.classList.toggle("hidden", !ids.includes(fila.dataset.cajaId))
    })
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
    if (data.fila) {
      this._agregarFila(data.fila)
      this._sumarAlConteo()
    }
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

  // El «N pqt» de la tarjeta activa. Sin esto la cuenta se queda en lo que
  // había al cargar la pantalla, y como acá ya no se recarga nunca, se quedaría
  // vieja todo el turno.
  _sumarAlConteo() {
    const bloque = this.cajaTargets.find((c) => Number(c.dataset.cajaId) === this.activaValue)
    const conteo = bloque?.querySelector("[data-empaque-target='conteo']")
    if (!conteo) return

    const n = parseInt(conteo.textContent, 10)
    conteo.textContent = `${(Number.isInteger(n) ? n : 0) + 1} pqt`
  }

  _agregarFila(fila) {
    if (!this.hasFilasTarget) return
    const tr = document.createElement("tr")
    tr.dataset.cajaId = String(this.activaValue)
    const celdas = [
      // C23-11 · Con varias cajas abiertas la fila tiene que decir en cuál
      // entró; si no, la tabla mezcla las tres sin distinguirlas.
      ["px-6 py-3 text-sm font-bold text-cec-navy dark:text-cec-gold", fila.caja],
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
