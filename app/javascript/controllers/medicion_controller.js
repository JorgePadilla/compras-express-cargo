import { Controller } from "@hotwired/stimulus"
import { conEnterAvanza } from "controllers/enter_avanza"

// C26-02 · La estación de Medición (San Pedro).
//
// Se escanea el warehouse receipt de la etiqueta de Miami y la pantalla
// contesta con **el grupo**, no con una caja: lo que declaró el cliente, cómo
// lo ingresó Miami, y la grilla de cuadritos con lo que está y lo que falta.
// Se mide cada una, y al completar el grupo salen todas las stickers juntas.
//
// Mismo esqueleto que /empacar: la pistola dispara Enter, cada resultado suena
// distinto, y el guard `_seq` evita que una respuesta vieja pinte por una caja
// que ya no está en pantalla. Los `dispatch` van con el nombre literal, uno por
// rama, para que `sonidos_cableados_test` los pueda leer del archivo; y el
// `showModal()` va en el mismo método que el `dispatch`, que es lo que el lint
// exige.
export default class extends conEnterAvanza(Controller) {
  static targets = [
    "codigo", "aviso",
    "dosLados", "panelPreAlerta", "paNumero", "paTitulo", "paDetalle", "paBanderas", "paNotas",
    "panelMiami", "miamiWr", "miamiDetalle", "miamiDescripcion", "miamiRetenido",
    "grupo", "grupoTitulo", "grupoSello", "grilla", "plantillaCuadrito", "facturarParcial",
    "panel", "codigoCaja", "tracking", "caja", "cliente", "tipoEnvio", "descripcion", "previa",
    "form", "peso", "alto", "largo", "ancho", "guardar", "guardarTexto", "reimprimir", "reimprimirTexto",
    "banner", "bannerTexto", "bannerReimprimir", "bannerReimprimirTexto",
    "manifiestoNumero", "manifiestoFechas", "manifiestoConteo", "pendientes", "sinPendientes",
    "plantillaPendiente", "descarteModal", "descarteCaja", "descarteMotivo", "descarteNota",
    "descarteError", "confirmarDescarte",
    "problemaModal", "problemaTitulo", "problemaTexto", "problemaEntendido", "medirDeNuevo",
    "excepcionModal", "excepcionFaltantes", "excepcionError", "confirmarParcial"
  ]
  static values = { escanearUrl: String, panelUrl: String, etiquetaUrlTemplate: String, clases: Object }

  connect() {
    this._seq = 0
    this._paquete = null
    this._grupo = null
    // F10 guarda, F9 reimprime, F2 limpia — escuchando en `document`, porque el
    // atajo global ignora las F-keys cuando el foco está en un input, y acá
    // siempre está.
    this._teclaGlobal = this.teclaGlobal.bind(this)
    document.addEventListener("keydown", this._teclaGlobal)
    // Al cerrarse cualquier modal, el foco vuelve a donde toca, un frame
    // después: en el mismo tick el `open` todavía no se fue.
    this._alCerrarse = () => requestAnimationFrame(() => this._enfocarDondeToca())
    this.element.addEventListener("close", this._alCerrarse, true)
    if (this.hasCodigoTarget) this.codigoTarget.focus()
    // C26-17 · El panel de la derecha arranca con el último manifiesto que
    // todavía tiene algo que medir, para que la pantalla no abra vacía.
    this._fetch("GET", this.panelUrlValue)
      .then((r) => r.json())
      .then((data) => this._pintarManifiesto(data.manifiesto))
      .catch(() => {})
  }

  disconnect() {
    document.removeEventListener("keydown", this._teclaGlobal)
    this.element.removeEventListener("close", this._alCerrarse, true)
  }

  // ── Escanear ────────────────────────────────────────────────────────────

  teclado(e) {
    if (e.key !== "Enter") return
    e.preventDefault()
    const codigo = this.codigoTarget.value.trim()
    this.codigoTarget.value = ""
    this._escanear(codigo)
  }

  // Tocar un cuadrito que ya llegó es lo mismo que escanearlo: el operario
  // tiene las tres cajas enfrente y no siempre quiere levantar la pistola.
  elegirCaja(e) {
    const wr = e.currentTarget.dataset.wr
    if (wr) this._escanear(wr)
  }

  _escanear(codigo) {
    if (!codigo) return

    const consulta = (this._seq += 1)
    this._post(this.escanearUrlValue, { codigo })
      .then((data) => {
        if (consulta !== this._seq) return  // llegó tarde: habla de otro escaneo
        this._resolver(data)
      })
      .catch(() => this._problema("No se pudo consultar", "Probá de nuevo."))
  }

  _resolver(data) {
    if (data.resultado !== "ok" && data.resultado !== "pre_alerta_ya_facturada") {
      this._problema(this._titulo(data.resultado), data.mensaje)
      return
    }

    this._pintar(data)

    if (data.resultado === "pre_alerta_ya_facturada") {
      // Se avisa y se deja medir: esa caja se factura aparte.
      this._problema("Pre-alerta ya facturada", data.mensaje)
    } else if (data.medicion_previa) {
      this.dispatch("yaMedido")
      this._llenarProblema("Ya medida", `Medida el ${data.medicion_previa.fecha} por ${data.medicion_previa.por}: ` +
        `${data.medicion_previa.peso} lb · ${data.medicion_previa.medidas}. ¿Medir de nuevo?`, { medirDeNuevo: true })
      this.problemaModalTarget.showModal()
      requestAnimationFrame(() => this.problemaEntendidoTarget.focus())
    } else if (data.grupo && !data.grupo.completo) {
      this.dispatch("unir")
      this._enfocarPeso()
    } else {
      this.dispatch("ok")
      this._enfocarPeso()
    }
  }

  _titulo(resultado) {
    return {
      no_encontrado: "No se encontró",
      ambiguo: "Escaneá la caja, no el tracking",
      en_pre_factura: "Ya está en una pre-factura",
      no_esta_en_honduras: "Todavía no se recibió"
    }[resultado] || "Problema"
  }

  // El modal rojo grande.
  _problema(titulo, texto) {
    this.dispatch("problema")
    this._llenarProblema(titulo, texto, { medirDeNuevo: false })
    this.problemaModalTarget.showModal()
    requestAnimationFrame(() => this.problemaEntendidoTarget.focus())
  }

  _llenarProblema(titulo, texto, { medirDeNuevo }) {
    this.problemaTituloTarget.textContent = titulo
    this.problemaTextoTarget.textContent = texto
    this.medirDeNuevoTarget.classList.toggle("hidden", !medirDeNuevo)
  }

  avisoEntendido() { this.problemaModalTarget.close() }

  medirDeNuevo() {
    this._volverAPeso = true
    this.problemaModalTarget.close()
  }

  // C20-13 · Escape no contesta un aviso: *"ellos no las leen"*.
  avisoCancelar(e) { e.preventDefault() }

  // ── Pintar ──────────────────────────────────────────────────────────────

  _pintar(data) {
    this._paquete = data.paquete
    const p = data.paquete
    this.codigoCajaTarget.textContent = p.codigo
    this.trackingTarget.textContent = p.tracking
    this.cajaTarget.textContent = p.caja ? `caja ${p.caja}` : ""
    this.clienteTarget.textContent = p.cliente || ""
    this.tipoEnvioTarget.textContent = p.tipo_envio || ""
    this.descripcionTarget.textContent = p.descripcion || ""
    this.previaTarget.classList.toggle("hidden", !data.medicion_previa)
    if (data.medicion_previa) {
      this.previaTarget.textContent = `Ya medida el ${data.medicion_previa.fecha} por ${data.medicion_previa.por}: ` +
        `${data.medicion_previa.peso} lb · ${data.medicion_previa.medidas}`
    }
    this.pesoTarget.value = p.peso || ""
    this.altoTarget.value = p.alto || ""
    this.largoTarget.value = p.largo || ""
    this.anchoTarget.value = p.ancho || ""

    this._pintarDosLados(data.pre_alerta, data.miami)
    this._pintarGrupo(data.grupo)
    this._pintarManifiesto(data.manifiesto)
    this._textoDeLosBotones()
    this.bannerTarget.classList.add("hidden")
    this.panelTarget.classList.remove("hidden")
    this.formTarget.querySelectorAll("input").forEach((i) => i.dispatchEvent(new Event("input", { bubbles: true })))
  }

  // Los dos lados del dato: lo que el cliente declaró y lo que Miami ingresó.
  // Pueden no coincidir, y esa diferencia es justamente la información.
  _pintarDosLados(preAlerta, miami) {
    this.panelPreAlertaTarget.classList.toggle("hidden", !preAlerta)
    if (preAlerta) {
      this.paNumeroTarget.textContent = preAlerta.numero
      this.paTituloTarget.textContent = preAlerta.titulo || ""
      const detalle = [preAlerta.proveedor, preAlerta.tipo_envio,
                       `${preAlerta.trackings} tracking${preAlerta.trackings === 1 ? "" : "s"}`].filter(Boolean)
      this.paDetalleTarget.textContent = detalle.join(" · ")
      const banderas = []
      if (preAlerta.consolidado) banderas.push("Pidió consolidar")
      if (preAlerta.con_reempaque) banderas.push("con reempaque")
      this.paBanderasTarget.textContent = banderas.join(" · ")
      this.paNotasTarget.textContent = preAlerta.notas || ""
    }

    this.panelMiamiTarget.classList.toggle("hidden", !miami)
    if (miami) {
      this.miamiWrTarget.textContent = miami.wr
      const detalle = [miami.recibido && `recibido ${miami.recibido}`, miami.por && `por ${miami.por}`,
                       miami.tipo_envio, miami.caja && `caja ${miami.caja}`].filter(Boolean)
      this.miamiDetalleTarget.textContent = detalle.join(" · ")
      this.miamiDescripcionTarget.textContent = miami.descripcion || ""
      this.miamiRetenidoTarget.classList.toggle("hidden", !miami.retenido)
    }
    this.dosLadosTarget.classList.toggle("hidden", !preAlerta && !miami)
  }

  // La grilla de cuadritos: uno por caja, con su estado.
  _pintarGrupo(grupo) {
    this._grupo = grupo
    this.grupoTarget.classList.toggle("hidden", !grupo)
    if (!grupo) return

    this.grupoTituloTarget.textContent = grupo.consolidada
      ? `UNIR · ${grupo.numero} · ${grupo.medidas} de ${grupo.total} medidas`
      : `Viene partido en ${grupo.total} cajas · ${grupo.medidas} medidas`
    this.grupoSelloTarget.textContent = grupo.parcial_autorizado
      ? `Se facturó incompleto el ${grupo.parcial_autorizado.fecha} por ${grupo.parcial_autorizado.por}`
      : ""

    this.grillaTarget.replaceChildren(...grupo.cajas.map((c) => this._cuadrito(c)))

    const forzable = !grupo.completo && !grupo.cerrada && !grupo.parcial_autorizado && grupo.facturar_parcial_url
    this.facturarParcialTarget.classList.toggle("hidden", !forzable)
  }

  // C26-04 · Los botones dicen lo que **va a pasar**, que no es siempre lo
  // mismo. Jorge: *"veo «Guardar e imprimir»… «Reimprimir etiqueta», no sé si
  // solo hace una, ¿cuál hace?"*. Con un envío a medias, F10 no imprime:
  // guarda y salta a la caja siguiente, y el texto lo dice con su número.
  _textoDeLosBotones() {
    const g = this._grupo
    const otraSinMedir = g && this._paquete
      ? g.cajas.find((c) => c.estado === "aqui" && c.id !== this._paquete.id)
      : null

    if (!g) {
      this.guardarTextoTarget.textContent = "Guardar e imprimir"
    } else if (otraSinMedir) {
      this.guardarTextoTarget.textContent = `Guardar y seguir con la ${otraSinMedir.caja || "siguiente"}`
    } else {
      this.guardarTextoTarget.textContent = `Guardar e imprimir las ${g.total}`
    }
  }

  _cuadrito(caja) {
    const nodo = this.plantillaCuadritoTarget.content.firstElementChild.cloneNode(true)
    const clases = this.clasesValue
    nodo.dataset.wr = caja.wr || ""
    nodo.dataset.estado = caja.estado
    nodo.disabled = !caja.medible
    // La seleccionada **reemplaza** las clases del estado en vez de sumarse:
    // dos `bg-` en el mismo elemento las resuelve el orden del CSS, no el del
    // atributo, así que sumarlas daba un resultado a medias. Jorge: *"la
    // seleccionada no se ve tan marcada"*.
    nodo.className += ` ${caja.seleccionada ? clases.seleccionada : (clases[caja.estado] || "")}`
    nodo.setAttribute("aria-label",
                      `${caja.wr || caja.tracking}: ${caja.seleccionada ? "midiendo esta" : caja.donde}`)
    nodo.querySelector("[data-campo=marca]").textContent = caja.seleccionada ? "MIDIENDO" : ""
    nodo.querySelector("[data-campo=wr]").textContent = caja.wr || caja.tracking
    nodo.querySelector("[data-campo=caja]").textContent = caja.caja || ""
    nodo.querySelector("[data-campo=estado]").textContent = caja.donde
    nodo.querySelector("[data-campo=peso]").textContent = caja.peso ? `${Number(caja.peso).toFixed(2)} lb` : ""
    return nodo
  }

  // ── Guardar ─────────────────────────────────────────────────────────────

  guardar() {
    if (!this._paquete || this._modalAbierto()) return

    const cuerpo = { peso: this.pesoTarget.value, alto: this.altoTarget.value,
                     largo: this.largoTarget.value, ancho: this.anchoTarget.value }
    this._patch(this._paquete.medir_url, cuerpo)
      .then(({ ok, data }) => {
        if (!ok) {
          this.dispatch("fallo")
          this._llenarProblema("No se guardó", (data.errores || []).join(" "), { medirDeNuevo: false })
          this.problemaModalTarget.showModal()
          requestAnimationFrame(() => this.problemaEntendidoTarget.focus())
          return
        }

        // Literales y no un ternario: `sonidos_cableados_test` los busca en el
        // archivo, y con el ternario dejó de encontrar `grupoCompleto`.
        if (data.resultado === "grupo_completo") {
          this.dispatch("grupoCompleto")
        } else {
          this.dispatch("guardado")
        }
        this._pintarManifiesto(data.manifiesto)
        this.avisoTarget.textContent = data.mensaje
        // La grilla se queda en pantalla con el cuadrito ya en verde: el
        // operario sigue con la caja siguiente del mismo grupo.
        this._pintarGrupo(data.grupo)

        // C26-02 · Si el envío venía partido, las otras cajas tienen **el
        // mismo warehouse receipt impreso**: volver a escanearlo no aportaría
        // nada. Se salta sola a la siguiente sin medir, con el cursor en el
        // peso.
        const siguiente = this._siguienteDelEnvio(data.paquete, data.grupo)
        if (siguiente) {
          this._escanear(siguiente)
          return
        }

        // C26-04 · Cuando hay algo que imprimir, el envío terminó: se imprime,
        // **se limpia la pantalla** y queda el banner. Jorge: *"cuando se
        // facture o se termine de imprimir se debería limpiar para que se
        // comience con el siguiente grupo"*.
        if (data.imprimir_url) {
          this._terminar(data.mensaje, data.imprimir_url, data.grupo ? data.grupo.total : 1)
          return
        }

        this._limpiarCaja()
        this.codigoTarget.focus()
      })
  }

  // La siguiente caja sin medir del mismo envío, si queda alguna.
  _siguienteDelEnvio(paquete, grupo) {
    if (!paquete.wr || !grupo) return null

    const caja = grupo.cajas.find((c) => c.envio === paquete.wr && c.estado === "aqui")
    return caja?.wr || null
  }

  // ── El panel de la derecha: lo que falta de este manifiesto ─────────────

  _pintarManifiesto(m) {
    if (!m) return

    this.manifiestoNumeroTarget.textContent = [m.numero, m.guia && `guía ${m.guia}`].filter(Boolean).join(" · ")
    this.manifiestoFechasTarget.textContent = [
      m.enviado && `Salió de Miami el ${m.enviado}`,
      m.recibido && `recibido el ${m.recibido}`
    ].filter(Boolean).join(" · ")
    // El match con lo que Miami dijo que mandó.
    const partes = [`Miami mandó ${m.enviados}`, `medidos ${m.medidos}`]
    if (m.descartados > 0) partes.push(`sacados ${m.descartados}`)
    partes.push(`faltan ${m.faltan}`)
    this.manifiestoConteoTarget.textContent = partes.join(" · ")

    this.pendientesTarget.replaceChildren(...m.pendientes.map((p) => this._renglon(p, m.puede_descartar)))
    this.sinPendientesTarget.classList.toggle("hidden", m.pendientes.length > 0)
  }

  _renglon(pendiente, puedeDescartar) {
    const nodo = this.plantillaPendienteTarget.content.firstElementChild.cloneNode(true)
    nodo.dataset.paqueteId = pendiente.id
    nodo.dataset.descartarUrl = pendiente.descartar_url
    nodo.dataset.wr = pendiente.wr || ""
    if (pendiente.midiendo) nodo.classList.add("bg-cec-gold/15")
    if (!pendiente.aqui) nodo.classList.add("opacity-60")

    nodo.querySelector("[data-campo=wr]").textContent =
      [pendiente.wr, pendiente.caja && `caja ${pendiente.caja}`].filter(Boolean).join(" · ")
    nodo.querySelector("[data-campo=cliente]").textContent = pendiente.cliente || ""
    const donde = nodo.querySelector("[data-campo=donde]")
    donde.textContent = pendiente.donde
    donde.classList.add(pendiente.aqui ? "text-gray-500" : "text-amber-800")

    // C26-17 · Los que vienen consolidados se ven sin escanearlos.
    const unir = nodo.querySelector("[data-campo=unir]")
    unir.classList.toggle("hidden", !pendiente.unir)
    if (pendiente.unir) unir.textContent = `UNIR · ${pendiente.unir}`

    // Sacar de la lista es de administración y de nadie más.
    nodo.querySelector("button").classList.toggle("hidden", !puedeDescartar)
    return nodo
  }

  // ── Sacar una caja de la lista ──────────────────────────────────────────

  abrirDescarte(e) {
    // Suena aunque lo abra un clic y no la pistola: la regla de las pantallas
    // de escaneo es que ningún modal se abra mudo, y acá el operario puede
    // estar mirando la caja y no la pantalla.
    this.dispatch("atencion")
    const fila = e.currentTarget.closest("li")
    this._descartando = fila.dataset.descartarUrl
    this.descarteCajaTarget.textContent = fila.dataset.wr
    this.descarteNotaTarget.value = ""
    this.descarteErrorTarget.classList.add("hidden")
    this.descarteModalTarget.showModal()
    requestAnimationFrame(() => this.confirmarDescarteTarget.focus())
  }

  cerrarDescarte() { this.descarteModalTarget.close() }

  confirmarDescarte() {
    if (!this._descartando) return

    const motivo = this.descarteMotivoTargets.find((r) => r.checked)?.value
    this._post(this._descartando, { motivo: motivo, nota: this.descarteNotaTarget.value }, { conEstado: true })
      .then(({ ok, data }) => {
        if (!ok) {
          this.dispatch("fallo")
          this.descarteErrorTarget.textContent = (data.errores || []).join(" ")
          this.descarteErrorTarget.classList.remove("hidden")
          return
        }
        this.dispatch("guardado")
        this._pintarManifiesto(data.manifiesto)
        this.avisoTarget.textContent = data.mensaje
        this.descarteModalTarget.close()
      })
  }

  // ── Terminar: imprimir, limpiar y dejar dicho qué pasó ──────────────────
  //
  // C26-04 · Una caja suelta imprime su sticker al guardarla; un envío imprime
  // **todas juntas** cuando se mide la última — *"que salgan las 3 stickers"*.
  // En los dos casos la pantalla queda limpia para el envío siguiente, y el
  // banner guarda el resultado y la única acción que todavía sirve: reimprimir.
  _terminar(mensaje, url, cantidad) {
    this._limpiarCaja()
    this._pintarGrupo(null)
    this.dosLadosTarget.classList.add("hidden")

    this.bannerTextoTarget.textContent = cantidad > 1
      ? `${mensaje} Se imprimieron ${cantidad} stickers.`
      : mensaje
    this.bannerTarget.classList.remove("hidden")

    this._imprimir(url, cantidad)
  }

  _imprimir(url, cantidad = 1) {
    if (!url) { this.codigoTarget.focus(); return }

    // «Reimprimir» significa **lo último que se imprimió**, y el texto de los
    // botones lo dice: era la pregunta de Jorge, *"¿cuál hace?"*.
    this._ultimaEtiquetaUrl = url
    const texto = cantidad > 1 ? `Reimprimir las ${cantidad} del envío` : "Reimprimir la etiqueta"
    this.reimprimirTextoTarget.textContent = texto
    this.bannerReimprimirTextoTarget.textContent = texto
    this.reimprimirTarget.classList.remove("hidden")
    this.bannerReimprimirTarget.classList.remove("hidden")

    window.open(url, "_blank")
    window.addEventListener("focus", () => this.codigoTarget.focus(), { once: true })
    this.codigoTarget.focus()
  }

  reimprimir() {
    if (!this._ultimaEtiquetaUrl || this._modalAbierto()) return

    window.open(this._ultimaEtiquetaUrl, "_blank")
    window.addEventListener("focus", () => this.codigoTarget.focus(), { once: true })
  }

  // ── Limpiar ─────────────────────────────────────────────────────────────

  limpiar() {
    if (this._modalAbierto()) return
    this._limpiarCaja()
    this._pintarGrupo(null)
    this.dosLadosTarget.classList.add("hidden")
    this.codigoTarget.focus()
  }

  _limpiarCaja() {
    this._paquete = null
    this.panelTarget.classList.add("hidden")
    ;[this.pesoTarget, this.altoTarget, this.largoTarget, this.anchoTarget].forEach((i) => { i.value = "" })
  }

  // ── Facturar lo que hay ─────────────────────────────────────────────────

  abrirExcepcion() {
    if (!this._grupo) return

    this.dispatch("problema")
    this.excepcionFaltantesTarget.replaceChildren(...this._grupo.cajas.filter((c) => c.estado !== "medida").map((c) => {
      const li = document.createElement("li")
      li.textContent = `${c.wr || c.tracking} · ${c.donde}`
      return li
    }))
    this.excepcionErrorTarget.classList.add("hidden")
    this.excepcionModalTarget.showModal()
    requestAnimationFrame(() => this.confirmarParcialTarget.focus())
  }

  cerrarExcepcion() { this.excepcionModalTarget.close() }

  confirmarParcial() {
    if (!this._grupo?.facturar_parcial_url) return

    this._post(this._grupo.facturar_parcial_url, {}, { conEstado: true })
      .then(({ ok, data }) => {
        if (!ok) {
          this.dispatch("fallo")
          this.excepcionErrorTarget.textContent = (data.errores || []).join(" ")
          this.excepcionErrorTarget.classList.remove("hidden")
          return
        }
        this.dispatch("guardado")
        this.avisoTarget.textContent = data.mensaje
        this.excepcionModalTarget.close()
        // Facturar lo que hay cierra el envío: imprime lo medido y limpia.
        this._terminar(data.mensaje, data.imprimir_url, data.grupo.medidas)
      })
  }

  // ── Teclado ─────────────────────────────────────────────────────────────

  teclaGlobal(e) {
    if (this._modalAbierto()) return
    if (e.key === "F10") { e.preventDefault(); this.guardar() }
    if (e.key === "F9")  { e.preventDefault(); this.reimprimir() }
    if (e.key === "F2")  { e.preventDefault(); this.limpiar() }
  }

  _modalAbierto() {
    return this.problemaModalTarget.open || this.excepcionModalTarget.open || this.descarteModalTarget.open
  }

  _enfocarPeso() {
    this.pesoTarget.focus()
    this.pesoTarget.select()
  }

  _enfocarDondeToca() {
    if (this._volverAPeso) { this._volverAPeso = false; this._enfocarPeso(); return }
    if (this._paquete && !this.panelTarget.classList.contains("hidden")) this._enfocarPeso()
    else this.codigoTarget.focus()
  }

  // ── Red ─────────────────────────────────────────────────────────────────

  _post(url, cuerpo, { conEstado = false } = {}) {
    return this._fetch("POST", url, cuerpo)
      .then((r) => (conEstado ? r.json().then((data) => ({ ok: r.ok, data })) : r.json()))
  }

  _patch(url, cuerpo) {
    return this._fetch("PATCH", url, cuerpo).then((r) => r.json().then((data) => ({ ok: r.ok, data })))
  }

  _fetch(method, url, cuerpo) {
    const token = document.querySelector("meta[name='csrf-token']")?.content
    return fetch(url, {
      method,
      headers: { "Content-Type": "application/json", "Accept": "application/json", "X-CSRF-Token": token },
      body: JSON.stringify(cuerpo)
    })
  }
}
