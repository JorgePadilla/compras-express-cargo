import { Controller } from "@hotwired/stimulus"

// Las reglas del servicio, en la pantalla de admin de pre-alertas.
//
// Jorge, 2026-08-20: *"faltan las reglas de servicio… revisá la parte de cliente
// y aplicale las reglas al admin"*. El portal las respeta las tres —reempaque,
// consolidación y un solo tracking—; admin no respetaba ninguna y podía grabar
// combinaciones que el portal hace imposibles.
//
// Acá solo se acomoda la pantalla. **Quien manda es el modelo**: deriva el
// reempaque y rechaza el consolidado sobre un servicio que no lo permite, así
// que si alguien manda el POST a mano igual no pasa.
export default class extends Controller {
  static targets = ["select", "reglas", "reempaque", "consolidado", "consolidadoCampo", "consolidadoNo"]
  static values = { consolidable: Boolean }

  alCambiarServicio() {
    const reglas = this._reglasDelElegido()
    this._pintarReempaque(reglas)
    this._ofrecerConsolidado(reglas)
    this._limitarPaquetes(reglas)
  }

  _reglasDelElegido() {
    const id = this.hasSelectTarget ? this.selectTarget.value : ""
    return this.reglasTargets.find(r => r.dataset.tipoEnvioId === id) || null
  }

  _pintarReempaque(reglas) {
    if (!this.hasReempaqueTarget) return
    if (!reglas) return (this.reempaqueTarget.textContent = "—")

    this.reempaqueTarget.textContent = reglas.dataset.conReempaque === "true"
      ? "sí, lo reempaca el servicio"
      : "no, viaja tal como llega"
  }

  // Al esconderlo **se desmarca**: una casilla oculta pero marcada sigue mandando
  // "1", y el servidor rechazaría por un control que no está en pantalla. Es la
  // misma familia del `required` adentro de un <dialog> cerrado.
  _ofrecerConsolidado(reglas) {
    const puede = reglas ? reglas.dataset.consolidable === "true" : false

    if (this.hasConsolidadoCampoTarget) this.consolidadoCampoTarget.classList.toggle("hidden", !puede)
    if (this.hasConsolidadoNoTarget) this.consolidadoNoTarget.classList.toggle("hidden", puede || !reglas)
    if (!puede && this.hasConsolidadoTarget) this.consolidadoTarget.checked = false
  }

  // El límite de tarjetas lo sabe hacer `pre-alerta-editor` desde siempre
  // (`maxPaquetesValue`, `isAtLimit`, `limitMessage`); lo que faltaba era que
  // alguien le dijera cuánto vale al cambiar de servicio. Los values de Stimulus
  // reaccionan al atributo, así que escribirlo alcanza.
  _limitarPaquetes(reglas) {
    const editor = this.element.closest("[data-controller~='pre-alerta-editor']")
    if (!editor) return

    editor.setAttribute("data-pre-alerta-editor-max-paquetes-value",
                        reglas ? reglas.dataset.maxPaquetes : "-1")
  }
}
