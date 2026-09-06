import { Controller } from "@hotwired/stimulus"
import { conEnterAvanza } from "controllers/enter_avanza"

// C26-02 · La estación de Medición (San Pedro).
//
// Mismo esqueleto que /empacar: la pistola dispara Enter, cada resultado
// suena distinto, el guard `_seq` evita que una respuesta vieja pinte por una
// caja que ya no está en pantalla, y los problemas van a un modal rojo grande.
//
// Los `dispatch` van con el nombre literal, uno por rama, para que
// `sonidos_cableados_test` los pueda leer del archivo. Y el `showModal()` va
// en el mismo método que el `dispatch`: el lint exige que todo método que abre
// un modal haga sonar algo.
export default class extends conEnterAvanza(Controller) {
  static targets = [
    "codigo", "aviso", "panel", "codigoCaja", "tracking", "caja", "cliente", "tipoEnvio", "descripcion", "previa",
    "unir", "unirTitulo", "unirFaltantes", "unirSello", "facturarParcial",
    "form", "peso", "alto", "largo", "ancho", "guardar", "banner", "medidos",
    "problemaModal", "problemaTitulo", "problemaTexto", "problemaEntendido", "medirDeNuevo",
    "excepcionModal", "excepcionFaltantes", "excepcionError", "supervisor", "pin", "motivo", "autorizar"
  ]
  static values = { escanearUrl: String }

  connect() {
    this._seq = 0
    this._paquete = null
    this._unir = null
    // F10 guarda, F2 limpia — escuchando en `document`, porque el atajo global
    // ignora las F-keys cuando el foco está en un input, y acá siempre está.
    this._teclaGlobal = this.teclaGlobal.bind(this)
    document.addEventListener("keydown", this._teclaGlobal)
    // Al cerrarse cualquier modal, el foco vuelve a donde toca — un frame
    // después, como en /etiquetar.
    this._alCerrarse = () => requestAnimationFrame(() => this._enfocarDondeToca())
    this.element.addEventListener("close", this._alCerrarse, true)
    if (this.hasCodigoTarget) this.codigoTarget.focus()
  }

  disconnect() {
    document.removeEventListener("keydown", this._teclaGlobal)
    this.element.removeEventListener("close", this._alCerrarse, true)
  }

  // ── Escanear ────────────────────────────────────────────────────────────

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
      .catch(() => this._problema("No se pudo consultar", "Probá de nuevo."))
  }

  _resolver(data) {
    switch (data.resultado) {
      case "ok":
      case "pre_alerta_ya_facturada":
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
        } else if (data.unir && !data.unir.completo) {
          this.dispatch("unir")
          this._enfocarPeso()
        } else {
          this.dispatch("ok")
          this._enfocarPeso()
        }
        break
      default:
        this._problema(this._titulo(data.resultado), data.mensaje)
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

  // El modal rojo grande. `dispatch` y `showModal()` en el mismo método, a
  // propósito: `sonidos_cableados_test` exige que todo método que abre un
  // modal haga sonar algo.
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

  avisoEntendido() {
    this.problemaModalTarget.close()
  }

  medirDeNuevo() {
    this._volverAPeso = true
    this.problemaModalTarget.close()
  }

  // C20-13 · Escape no contesta un aviso: *"ellos no las leen"*.
  avisoCancelar(e) {
    e.preventDefault()
  }

  // ── Pintar la caja y el grupo ───────────────────────────────────────────

  _pintar(data) {
    this._paquete = data.paquete
    this._unir = data.unir
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
    this._pintarUnir(data.unir)
    this.bannerTarget.classList.add("hidden")
    this.panelTarget.classList.remove("hidden")
    this.formTarget.querySelectorAll("input").forEach((i) => i.dispatchEvent(new Event("input", { bubbles: true })))
  }

  _pintarUnir(unir) {
    this._unir = unir
    this.unirTarget.classList.toggle("hidden", !unir)
    if (!unir) return
    this.unirTituloTarget.textContent = unir.cerrada
      ? `${unir.numero} ya facturada · esta caja se factura aparte`
      : `UNIR · ${unir.numero} · llegados ${unir.llegados} de ${unir.total} · medidos ${unir.medidos} de ${unir.total}`
    this.unirFaltantesTarget.replaceChildren(...unir.faltantes.map((f) => {
      const li = document.createElement("li")
      li.textContent = `${f.tracking} · ${f.descripcion || ""} · ${f.donde}`
      return li
    }))
    this.unirSelloTarget.classList.toggle("hidden", !unir.parcial_autorizado)
    if (unir.parcial_autorizado) {
      this.unirSelloTarget.textContent = `Facturar parcial autorizado el ${unir.parcial_autorizado.fecha} por ${unir.parcial_autorizado.por}`
    }
    const forzable = !unir.completo && !unir.cerrada && !unir.parcial_autorizado
    this.facturarParcialTarget.classList.toggle("hidden", !forzable)
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
        if (data.resultado === "grupo_completo") {
          this.dispatch("grupoCompleto")
          this.bannerTarget.textContent = data.mensaje
          this.bannerTarget.classList.remove("hidden")
        } else {
          this.dispatch("guardado")
        }
        this._agregarFila(data.paquete)
        this.avisoTarget.textContent = data.mensaje
        this._limpiarPanel()
        this.codigoTarget.focus()
      })
  }

  _agregarFila(p) {
    const tr = document.createElement("tr")
    tr.innerHTML = `<td class="px-4 py-2 font-mono text-cec-navy dark:text-cec-gold"></td>` +
                   `<td class="px-4 py-2 text-gray-700 dark:text-gray-200"></td>` +
                   `<td class="px-4 py-2 text-right font-mono text-gray-500"></td>`
    tr.children[0].textContent = p.codigo
    tr.children[1].textContent = (p.cliente || "").split(" · ")[0]
    tr.children[2].textContent = `${Number(p.peso).toFixed(2)} lb`
    this.medidosTarget.prepend(tr)
  }

  limpiar() {
    if (this._modalAbierto()) return
    this._limpiarPanel()
    this.codigoTarget.focus()
  }

  _limpiarPanel() {
    this._paquete = null
    this._unir = null
    this.panelTarget.classList.add("hidden")
    this.unirTarget.classList.add("hidden")
    ;[this.pesoTarget, this.altoTarget, this.largoTarget, this.anchoTarget].forEach((i) => { i.value = "" })
  }

  // ── Facturar lo que hay ─────────────────────────────────────────────────

  abrirExcepcion() {
    if (!this._unir) return
    this.dispatch("problema")
    this.excepcionFaltantesTarget.replaceChildren(...this._unir.faltantes.map((f) => {
      const li = document.createElement("li")
      li.textContent = `${f.tracking} · ${f.descripcion || ""} · ${f.donde}`
      return li
    }))
    this.excepcionErrorTarget.classList.add("hidden")
    this.pinTarget.value = ""
    this.motivoTarget.value = ""
    this.excepcionModalTarget.showModal()
    requestAnimationFrame(() => this.supervisorTarget.focus())
  }

  cerrarExcepcion() {
    this.excepcionModalTarget.close()
  }

  autorizarParcial() {
    if (!this._unir) return
    const cuerpo = { supervisor_id: this.supervisorTarget.value, pin: this.pinTarget.value, motivo: this.motivoTarget.value }
    this._post(this._unir.facturar_parcial_url, cuerpo, { conEstado: true })
      .then(({ ok, data }) => {
        if (!ok) {
          this.dispatch("fallo")
          this.excepcionErrorTarget.textContent = (data.errores || []).join(" ")
          this.excepcionErrorTarget.classList.remove("hidden")
          this.pinTarget.value = ""
          this.pinTarget.focus()
          return
        }
        this.dispatch("guardado")
        this._pintarUnir(data.unir)
        this.avisoTarget.textContent = data.mensaje
        this.excepcionModalTarget.close()
      })
  }

  // ── Teclado ─────────────────────────────────────────────────────────────

  teclaGlobal(e) {
    if (this._modalAbierto()) return
    if (e.key === "F10") { e.preventDefault(); this.guardar() }
    if (e.key === "F2")  { e.preventDefault(); this.limpiar() }
  }

  _modalAbierto() {
    return this.problemaModalTarget.open || this.excepcionModalTarget.open
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
    return this._fetch("POST", url, cuerpo).then((r) => conEstado ? r.json().then((data) => ({ ok: r.ok, data })) : r.json())
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
