import { Controller } from "@hotwired/stimulus"
import { enfocar } from "controllers/enfocar"

// PR-P.5 · C30-17 / C30-18 · Auditar la pre-factura escaneando.
//
// Yusef: *"escanear cualquiera de estas: automáticamente… jala los tres
// volúmenes… y ahora te dice escanear los paquetes que van con esto"* ·
// *"sí, pertenece"*.
//
// Dos escaneos, y se distinguen por el **prefijo** `MED` (el QR del volumen),
// no buscando el código: el QR lleva el código de la primera caja de la tanda,
// que también es una etiqueta de Miami. El servidor clasifica
// (`AuditoriaDeTanda`) y esta pantalla solo lleva la cuenta de qué tandas y qué
// cajas se escanearon, que manda en cada pedido. Quien decide al guardar es
// `GuardarPreFacturaAuditada`, que lo vuelve a preguntar todo.
//
// Pantalla de pistola, con las reglas de /medicion:
//   · **Enter nunca guarda**: la pistola dispara Enter en cada lectura.
//   · Cada respuesta suena; un `dispatch` literal por rama
//     (`sonidos_cableados_test` lee los dos lados).
//   · Después de un modal, `enfocar` y no `focus()`: cerrarlo con el dedo deja
//     el campo sordo a la pistola (C30-10).
//   · Teclas de la hoja de Yusef (C30-02): F9 guarda e imprime, F2 limpia, y
//     F8 guarda **consolidando** (PR-P.6): imprime la etiqueta con la franja y
//     no avisa. Es la única pantalla donde F8 imprime (Fase 14).
//
// PR-P.6 · Escanear un volumen de una pre-factura consolidando la **reabre**:
// sus tandas entran a la pantalla ya auditadas, y la tanda nueva se le agrega
// —Yusef: *"¿desea agregar más paquetes a este volumen, o nuevo volumen?"*;
// lo que se construye es «nuevo volumen»—.
export default class extends Controller {
  static targets = [
    "codigo", "aviso", "bitacora", "guardarBtn",
    "vacio", "contenido", "clienteCodigo", "clienteNombre", "servicio", "resumen",
    "cajas", "volumenes", "lineas",
    "finModal", "finTexto", "finGuardar", "finSeguir", "abierta"
  ]
  static values = { volumenUrl: String, paqueteUrl: String, guardarUrl: String, abrir: Object }

  connect() {
    this._cola = Promise.resolve()
    this._reiniciar()
    this._teclaGlobal = this.teclaGlobal.bind(this)
    document.addEventListener("keydown", this._teclaGlobal)
    this._alCerrar = () => requestAnimationFrame(() => enfocar(this.codigoTarget))
    this.finModalTarget.addEventListener("close", this._alCerrar)
    // PR-P.7 · Abierta desde «editar pre-facturas»: la consolidando, ya cargada.
    if (this.abrirValue?.pre_factura) {
      this._reabrir(this.abrirValue)
      this._avisar("alerta", this.abrirValue.mensaje)
    }
  }

  disconnect() {
    document.removeEventListener("keydown", this._teclaGlobal)
    this.finModalTarget.removeEventListener("close", this._alCerrar)
  }

  // ── Teclado ─────────────────────────────────────────────────────────────

  // La pistola termina cada lectura con Enter: lee, nunca guarda.
  teclado(e) {
    if (e.key !== "Enter") return
    e.preventDefault()

    const codigo = this.codigoTarget.value.trim()
    this.codigoTarget.value = ""
    this._leer(codigo)
  }

  // Jorge, 2026-10-10: *"estoy pegando este QR de un volumen y no funciona"*.
  // Funcionaba, pero esperaba el Enter que la pistola manda sola y un pegado
  // no: el texto se quedaba en el campo. Pegar es una lectura entera —el ícono
  // de copiar de /medicion/volumenes copia el QR completo—, así que se manda
  // como si la pistola lo hubiera leído.
  pegado(e) {
    const texto = (e.clipboardData || window.clipboardData)?.getData("text") || ""
    if (texto.trim().length < 3) return
    e.preventDefault()
    this.codigoTarget.value = ""
    this._leer(texto.trim())
  }

  _leer(codigo) {
    enfocar(this.codigoTarget)
    if (codigo.length < 3) return

    // En fila, uno detrás del otro. La pistola es más rápida que el servidor:
    // la primera caja llegaba mientras el volumen todavía estaba en vuelo,
    // salía con la lista de tandas vacía y contestaba «primero el volumen».
    // Cada lectura espera a que la anterior termine y pregunta con lo que ya
    // se sabe.
    this._cola = this._cola.then(() => (/^MED[^A-Z0-9]/i.test(codigo) ? this._volumen(codigo) : this._paquete(codigo)))
  }

  teclaGlobal(e) {
    if (e.key === "F9") {
      e.preventDefault()
      this.guardar()
    } else if (e.key === "F8") {
      e.preventDefault()
      this.consolidar()
    } else if (e.key === "F2") {
      if (this.finModalTarget.open) return
      e.preventDefault()
      this.limpiar()
    }
  }

  // ── El volumen ──────────────────────────────────────────────────────────

  _volumen(codigo) {
    return this._post(this.volumenUrlValue, { codigo, sesiones: this.sesiones, pre_factura_id: this.preFactura?.id })
      .then((data) => {
        if (data.resultado === "consolidando") {
          this.dispatch("consolidando")
          this._reabrir(data)
          this._avisar("alerta", data.mensaje)
          this._anotar(`Reabierta ${data.pre_factura.numero} · consolidando`)
        } else if (data.resultado === "ok") {
          this._agregarTanda(data)
          this._anotar(`Volumen · ${data.resumen}`)
          // La etiqueta es de una medición anterior: se avisa con otro sonido,
          // y la tanda de hoy queda cargada igual.
          if (data.aviso_ndem) {
            this.dispatch("medicionAnterior")
            this._avisar("alerta", data.aviso_ndem)
          } else {
            this.dispatch("ok")
            this._avisar("ok", data.mensaje)
          }
        } else {
          this.dispatch("rechazo")
          this._avisar("error", data.mensaje, data.pre_factura_url)
          this._anotar(`✗ ${data.mensaje}`)
        }
      })
      .catch(() => {
        this.dispatch("rechazo")
        this._avisar("error", "No se pudo consultar. Probá de nuevo.")
      })
  }

  _agregarTanda(data, { pintar = true } = {}) {
    this.sesiones.push(data.sesion)
    data.cajas.forEach((c) => this.cajas.push({ ...c, sesion: data.sesion }))
    this.volumenes = this.volumenes.concat(data.volumenes)
    this.cliente = data.cliente
    this.tipoEnvio = data.tipo_envio
    this.preAlerta = data.pre_alerta
    if (data.lineas) this.lineas = data.lineas
    if (pintar) this._pintar()
  }

  // PR-P.6 · La consolidando, con sus tandas ya auditadas.
  _reabrir(data) {
    this._reiniciar()
    this.preFactura = data.pre_factura
    data.tandas.forEach((t) => this._agregarTanda(t, { pintar: false }))
    data.escaneadas.forEach((id) => this.escaneadas.add(id))
    this.lineas = data.lineas
    this._pintar()
  }

  // ── Las cajas ───────────────────────────────────────────────────────────

  _paquete(codigo) {
    return this._post(this.paqueteUrlValue, {
      codigo, sesiones: this.sesiones, escaneadas: [ ...this.escaneadas ], pre_factura_id: this.preFactura?.id
    })
      .then((data) => {
        switch (data.resultado) {
          case "pertenece":
            this.dispatch("pertenece")
            this.escaneadas.add(data.caja_id)
            this._avisar("ok", data.mensaje)
            this._anotar(`✓ ${data.mensaje}`)
            this._pintar()
            if (this._faltan() === 0) this._completo()
            return
          case "ya_escaneada":
            this.dispatch("yaEscaneada")
            this._avisar("alerta", data.mensaje)
            return
          default:
            this.dispatch("noCorresponde")
            this._avisar("error", data.mensaje)
            this._anotar(`✗ ${data.mensaje}`)
        }
      })
      .catch(() => {
        this.dispatch("noCorresponde")
        this._avisar("error", "No se pudo consultar. Probá de nuevo.")
      })
  }

  _faltan() {
    return this.cajas.filter((c) => !this.escaneadas.has(c.id)).length
  }

  // «¿Desea agregar algo más?» — sale al escanear la última caja.
  _completo() {
    this.dispatch("completo")
    const n = this.cajas.length
    this.finTextoTarget.textContent =
      `${this.cliente?.codigo || ""} · ${this.volumenes.length} volumen${this.volumenes.length === 1 ? "" : "es"} · ` +
      `${n} caja${n === 1 ? "" : "s"}, todas escaneadas.`
    this.finModalTarget.showModal()
    // El foco a «Agregar otro volumen», no a «Guardar»: un Enter de la pistola
    // con el modal abierto cierra y sigue, nunca guarda. Guardar es F9.
    requestAnimationFrame(() => this.finSeguirTarget.focus())
  }

  // «Agregar otro volumen»: cierra el modal y la pistola sigue.
  seguir(e) {
    if (e?.type === "cancel") e.preventDefault()
    this.finModalTarget.close()
  }

  // ── F9 ──────────────────────────────────────────────────────────────────

  // F8: guardar consolidando (PR-P.6).
  consolidar() {
    this.guardar("consolidar")
  }

  guardar(modo = "avisar") {
    if (typeof modo !== "string") modo = "avisar"   // desde un clic llega el evento
    if (this._guardando) return
    if (this.finModalTarget.open) this.finModalTarget.close()

    // La pestaña de la etiqueta se abre **acá**, en el gesto (la tecla o el
    // clic), y recién después se le da la dirección: abierta al volver del
    // `fetch`, Chrome la bloquea por no nacer de un gesto.
    // Siempre: el volumen puede estar todavía en la fila. Si no se guarda, se
    // cierra.
    const ventana = window.open("", "_blank")
    this._guardando = true

    // En la misma fila que los escaneos, en las dos direcciones: un F9 apurado
    // espera la última caja que todavía se estaba consultando, y lo que la
    // pistola lea mientras se guarda espera a que la pantalla quede limpia —si
    // no, una lectura en vuelo se mezclaría con la pre-factura que se cierra.
    this._cola = this._cola.then(() => this._post(this.guardarUrlValue, {
      sesiones: this.sesiones, escaneadas: [ ...this.escaneadas ], modo, pre_factura_id: this.preFactura?.id
    })
      .then((data) => {
        if (data.ok) {
          this.dispatch("guardado")
          if (ventana) ventana.location = data.imprimir_url
          this._reiniciar()
          this._pintar()
          this._avisar("ok", data.mensaje, data.pre_factura_url)
          this._anotar(`Guardada ${data.numero}`)
        } else {
          ventana?.close()
          this.dispatch("noGuardo")
          this._avisar("error", data.mensaje)
        }
      })
      .catch(() => {
        ventana?.close()
        this.dispatch("noGuardo")
        this._avisar("error", "No se pudo guardar. Probá de nuevo.")
      })
      .finally(() => {
        this._guardando = false
        enfocar(this.codigoTarget)
      }))
  }

  limpiar() {
    this._reiniciar()
    this._pintar()
    this.avisoTarget.classList.add("hidden")
    this.bitacoraTarget.replaceChildren()
    enfocar(this.codigoTarget)
  }

  // ── Pintar ──────────────────────────────────────────────────────────────

  _reiniciar() {
    this.sesiones = []
    this.cajas = []
    this.escaneadas = new Set()
    this.volumenes = []
    this.cliente = null
    this.tipoEnvio = null
    this.preAlerta = null
    this.lineas = null
    this.preFactura = null
  }

  _pintar() {
    const hay = this.sesiones.length > 0
    this.vacioTarget.hidden = hay
    this.contenidoTarget.hidden = !hay
    if (!hay) return

    this.abiertaTarget.hidden = !this.preFactura
    this.abiertaTarget.textContent = this.preFactura
      ? `Agregando a la pre-factura ${this.preFactura.numero}, que estaba consolidando: escaneá el volumen nuevo.`
      : ""

    this.clienteCodigoTarget.textContent = this.cliente?.codigo || "—"
    this.clienteNombreTarget.textContent = this.cliente?.nombre || ""
    this.servicioTarget.textContent = [ this.tipoEnvio, this.preAlerta ? `pre-alerta ${this.preAlerta}` : null ]
      .filter(Boolean).join(" · ")

    const n = this.cajas.length
    const v = this.volumenes.length
    this.resumenTarget.textContent =
      `${v} volumen${v === 1 ? "" : "es"} · ${n} caja${n === 1 ? "" : "s"} · faltan ${this._faltan()}`

    this.cajasTarget.replaceChildren(...this.cajas.map((c) => {
      const li = document.createElement("li")
      const ok = this.escaneadas.has(c.id)
      li.dataset.cajaId = c.id
      li.dataset.escaneada = ok ? "true" : "false"
      li.className = "flex items-center gap-2 min-h-12 px-3 rounded-lg border-2 font-mono text-base " +
        (ok ? "border-cec-teal bg-cec-teal/10 text-cec-teal-dark" : "border-gray-200 text-gray-700 dark:border-gray-700 dark:text-gray-200")
      li.textContent = `${ok ? "✓" : "○"} ${c.codigo}`
      return li
    }))

    this.volumenesTarget.replaceChildren(...this.volumenes.map((vol) => {
      const tr = document.createElement("tr")
      const celdas = [
        vol.de_cuantos > 1 ? `${vol.orden} de ${vol.de_cuantos}` : "1",
        this._num(vol.peso), this._num(vol.vlbs), this._num(vol.pies3), this._num(vol.peso_cobrar), vol.medidas || "—"
      ]
      celdas.forEach((texto, i) => {
        const td = document.createElement("td")
        td.className = i === 0 || i === 5 ? "py-1 pr-3" : "py-1 pr-3 text-right"
        td.textContent = texto
        tr.appendChild(td)
      })
      return tr
    }))

    this._pintarLineas()
  }

  _pintarLineas() {
    const l = this.lineas
    this.lineasTarget.replaceChildren()
    if (!l) return
    if (l.error) {
      const p = document.createElement("p")
      p.className = "text-red-700"
      p.textContent = l.error
      this.lineasTarget.appendChild(p)
      return
    }
    const ul = document.createElement("ul")
    ul.className = "divide-y divide-gray-100 dark:divide-gray-700"
    l.items.forEach((item) => {
      const li = document.createElement("li")
      li.className = "flex justify-between gap-3 py-1"
      const concepto = document.createElement("span")
      concepto.textContent = item.concepto
      const monto = document.createElement("span")
      monto.className = "font-mono"
      monto.textContent = this._dinero(item.subtotal, l.moneda)
      li.append(concepto, monto)
      ul.appendChild(li)
    })
    const total = document.createElement("p")
    total.className = "mt-2 text-right font-semibold text-gray-900 dark:text-gray-100"
    total.textContent = `ISV ${this._dinero(l.impuesto, l.moneda)} · Total ${this._dinero(l.total, l.moneda)}`
    this.lineasTarget.append(ul, total)
  }

  _num(n) {
    return n === null || n === undefined ? "—" : Number(n).toFixed(2)
  }

  _dinero(n, moneda) {
    return `${moneda === "USD" ? "$" : "L."} ${Number(n || 0).toFixed(2)}`
  }

  _avisar(tipo, mensaje, url = null) {
    const estilos = {
      ok:     "bg-cec-teal/10 text-cec-teal-deep",
      alerta: "bg-cec-gold/15 text-cec-navy",
      error:  "bg-red-50 text-red-700"
    }
    this.avisoTarget.className = `mt-4 rounded-lg p-4 text-base ${estilos[tipo]}`
    this.avisoTarget.replaceChildren(document.createTextNode(mensaje))
    if (url) {
      const a = document.createElement("a")
      a.href = url
      a.target = "_blank"
      a.className = "ml-2 underline font-semibold"
      a.textContent = "Abrir la pre-factura"
      this.avisoTarget.appendChild(a)
    }
  }

  _anotar(texto) {
    const li = document.createElement("li")
    li.textContent = texto
    this.bitacoraTarget.prepend(li)
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
}
