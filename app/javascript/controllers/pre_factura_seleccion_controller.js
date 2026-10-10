import { Controller } from "@hotwired/stimulus"

// PR-P.10 · El paso 2 de /pre_facturas/new: cada vez que cambia un check se le
// pide al servidor el total de lo marcado. El total no se suma acá: lo arma
// `ArmarPreFacturaManual` —el mismo que `create`— con la cuenta del documento
// (ISV half-up), así que la pantalla dice lo que se va a guardar.
//
// El check de una tanda trae sus ids juntos («12,13»): se manda tal cual.
export default class extends Controller {
  static targets = ["check", "todos", "frame"]
  static values = { url: String }

  cambiar() {
    this._sincronizarTodos()
    this._cotizar()
  }

  todos(event) {
    this.checkTargets.forEach(check => { check.checked = event.currentTarget.checked })
    this._cotizar()
  }

  _sincronizarTodos() {
    if (!this.hasTodosTarget) return
    const marcados = this.checkTargets.filter(check => check.checked).length
    this.todosTarget.checked = marcados > 0 && marcados === this.checkTargets.length
    this.todosTarget.indeterminate = marcados > 0 && marcados < this.checkTargets.length
  }

  _cotizar() {
    if (!this.hasFrameTarget || !this.hasUrlValue) return

    const url = new URL(this.urlValue, window.location.origin)
    this.checkTargets.filter(check => check.checked).forEach(check => url.searchParams.append("paquete_ids[]", check.value))
    this.frameTarget.src = url.toString()
  }
}
