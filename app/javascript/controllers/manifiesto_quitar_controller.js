import { Controller } from "@hotwired/stimulus"

// C30-06 · «Eliminar paquetes que no se fueron», escaneando en un modal.
//
// Yusef: *"deseo eliminar paquetes, y le vas a decir que sí, y empezás a
// escanear clac, clac, clac"*.
//
// La gemela de `manifiesto_search` en la otra dirección, con la misma forma:
// el servidor **clasifica** (`manifiestos#escanear_para_quitar`) y, si es
// `ok`, el que escribe es el `DELETE remove_paquete` de siempre, que contesta
// el turbo_stream que refresca la tabla y los botones de cierre. Una puerta de
// escritura por acción.
//
//   ok            → sale, aviso verde, el contador sube
//   varios        → aviso: escaneá la etiqueta de la caja, no el tracking
//   no_esta_aca   → aviso rojo: está en otro manifiesto, o en ninguno
//   no_encontrado → aviso rojo
//   bloqueado     → aviso rojo: el candado se cerró mientras tanto
//
// Siempre, con o sin error, el campo queda vacío y con el foco.
export default class extends Controller {
  static targets = ["modal", "input", "aviso", "contador"]
  static values = { escanearUrl: String, quitarUrl: String }

  abrir() {
    this._sacados = 0
    this.contadorTarget.textContent = "0"
    this.avisoTarget.classList.add("hidden")
    this.modalTarget.showModal()
    this.inputTarget.value = ""
    this.inputTarget.focus()
  }

  cerrar() {
    this.modalTarget.close()
  }

  teclado(e) {
    if (e.key !== "Enter") return
    e.preventDefault()

    const codigo = this.inputTarget.value.trim()
    this.inputTarget.value = ""
    this.inputTarget.focus()
    if (codigo.length < 3) return

    this._escanear(codigo)
  }

  _escanear(codigo) {
    fetch(this.escanearUrlValue, {
      method: "POST",
      headers: { "Content-Type": "application/json", "Accept": "application/json", "X-CSRF-Token": this._token() },
      body: JSON.stringify({ codigo })
    })
      .then((r) => r.json())
      .then((data) => this._resolver(data))
      .catch(() => {
        this.dispatch("noEncontrado")
        this._avisar("error", "No se pudo consultar. Probá de nuevo.")
      })
  }

  // Un `dispatch` literal por rama: es lo que `sonidos_cableados_test` lee.
  _resolver(data) {
    switch (data.resultado) {
      case "ok":
        this.dispatch("ok")
        this._quitar(data.paquete_id, data.mensaje)
        return
      case "varios":
        this.dispatch("varios")
        this._avisar("alerta", data.mensaje)
        return
      case "no_esta_aca":
        this.dispatch("noEstaAca")
        this._avisar("error", data.mensaje)
        return
      default:
        this.dispatch("noEncontrado")
        this._avisar("error", data.mensaje || "No se encontró.")
    }
  }

  _quitar(paqueteId, mensaje) {
    const url = this.quitarUrlValue.replace("PAQUETE_ID", encodeURIComponent(paqueteId))
    fetch(url, {
      method: "DELETE",
      headers: { "Accept": "text/vnd.turbo-stream.html", "X-CSRF-Token": this._token() }
    })
      .then((r) => {
        if (!r.ok) throw new Error(r.status)
        return r.text()
      })
      .then((html) => {
        window.Turbo.renderStreamMessage(html)
        this._sacados += 1
        this.contadorTarget.textContent = String(this._sacados)
        this._avisar("ok", mensaje)
      })
      .catch(() => this._avisar("error", "No se pudo sacar. Probá de nuevo."))
  }

  _avisar(tipo, mensaje) {
    const estilos = {
      ok:     "bg-cec-teal/10 text-cec-teal-deep",
      alerta: "bg-cec-gold/15 text-cec-navy",
      error:  "bg-red-50 text-red-700"
    }
    this.avisoTarget.className = `mt-3 rounded-lg p-3 text-sm ${estilos[tipo]}`
    this.avisoTarget.textContent = mensaje
  }

  _token() {
    return document.querySelector("meta[name=csrf-token]")?.content || ""
  }
}
