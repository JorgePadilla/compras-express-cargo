import { Controller } from "@hotwired/stimulus"

// PR-C29.16 · Vuelve a pedir un `turbo-frame` cada tanto, para los signos del
// servidor. Es el primer refresco solo de la app: el resto se refresca a mano
// («Refrescar», con Turbo y sin perder el scroll).
//
// Se frena con la pestaña escondida —nadie mira una pantalla de fondo, y cada
// vuelta son unas cuantas consultas a la base— y, al volver, refresca de una.
export default class extends Controller {
  static values = { url: String, segundos: { type: Number, default: 30 } }

  connect() {
    this._visibilidad = () => (document.hidden ? this._parar() : this._arrancar(true))
    document.addEventListener("visibilitychange", this._visibilidad)
    if (!document.hidden) this._arrancar(false)
  }

  disconnect() {
    this._parar()
    document.removeEventListener("visibilitychange", this._visibilidad)
  }

  // «Actualizar»: la primera vez el frame no tiene `src`, así que se le pone;
  // después alcanza con `reload()`.
  ahora() {
    if (this.element.src) this.element.reload()
    else this.element.src = this.urlValue
  }

  _arrancar(yaMismo) {
    this._parar()
    if (yaMismo) this.ahora()
    this._reloj = setInterval(() => this.ahora(), this.segundosValue * 1000)
  }

  _parar() {
    if (this._reloj) clearInterval(this._reloj)
    this._reloj = null
  }
}
