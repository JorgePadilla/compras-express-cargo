import { Controller } from "@hotwired/stimulus"

// C21-07 · «El aparatito» de recibir carga.
//
// Yusef: *"aquí es donde yo te digo que quiero el aparatito: que vengan ellos,
// llegan a recibir carga, y **escanean la caja** y automáticamente el sistema lo
// [pone]"*. Con pistola, y sobre poco volumen — *"como solo son 5 o 10 cajas lo
// más que se recibe"*.
//
// Mismo esqueleto que la pantalla de empacar: la pistola dispara Enter, cada
// resultado suena distinto porque el que recibe está mirando el camión, y el
// guard `_seq` evita que una respuesta vieja pinte o suene por una caja que ya
// no está en pantalla.
export default class extends Controller {
  static targets = ["codigo", "aviso", "contador"]
  static values = { escanearUrl: String }

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

    const token = document.querySelector("meta[name='csrf-token']")?.content
    fetch(this.escanearUrlValue, {
      method: "POST",
      headers: { "Content-Type": "application/json", "Accept": "application/json", "X-CSRF-Token": token },
      body: JSON.stringify({ codigo })
    })
      .then((r) => r.json())
      .then((data) => {
        if (consulta !== this._seq) return
        this._resolver(data)
      })
      .catch(() => {
        this.dispatch("noEsDeAqui")
        this._mostrar("noEsDeAqui", "No se pudo consultar. Probá de nuevo.")
      })
  }

  // Los `dispatch` van con el nombre literal, uno por rama, para que
  // `sonidos_cableados_test` pueda probarlos leyendo el archivo.
  _resolver(data) {
    switch (data.resultado) {
      case "ok":            this.dispatch("ok"); break
      case "ya_recibida":   this.dispatch("yaRecibida"); break
      default:              this.dispatch("noEsDeAqui")
    }
    this._mostrar(this._tono(data.resultado), data.mensaje)
    if (data.resultado === "ok") this._marcarRecibida(data.caja_id, data.faltan)
    this.codigoTarget.focus()
  }

  _tono(resultado) {
    return { ok: "ok", ya_recibida: "yaRecibida" }[resultado] || "noEsDeAqui"
  }

  _mostrar(evento, mensaje) {
    if (!this.hasAvisoTarget) return
    const tonos = {
      ok: "bg-cec-teal/10 text-cec-teal-dark",
      yaRecibida: "bg-cec-gold/15 text-cec-navy",
      noEsDeAqui: "bg-red-50 text-red-800"
    }
    this.avisoTarget.className = `mt-4 rounded-lg p-3 text-sm ${tonos[evento] || tonos.noEsDeAqui}`
    this.avisoTarget.textContent = mensaje
    this.avisoTarget.classList.remove("hidden")
  }

  _marcarRecibida(cajaId, faltan) {
    const celda = this.element.querySelector(`[data-caja-estado="${cajaId}"]`)
    if (celda) {
      celda.innerHTML = ""
      const badge = document.createElement("span")
      badge.className = "inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-cec-teal/10 text-cec-teal"
      badge.textContent = "Recibida"
      celda.appendChild(badge)
    }
    if (this.hasContadorTarget && typeof faltan === "number") {
      const total = this.element.querySelectorAll("[data-caja-fila]").length
      this.contadorTarget.textContent = `${total - faltan} de ${total} recibidas`
    }
  }
}
