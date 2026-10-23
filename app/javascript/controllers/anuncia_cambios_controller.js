import { Controller } from "@hotwired/stimulus"
import { anunciar } from "controllers/anunciar"

// PR-A11Y.5 · Lo que cambia adentro de este elemento se le dice al lector de
// pantalla.
//
// Va en los avisos que el JS reescribe (el de la pistola del manifiesto, el de
// /medicion, el de recibir carga) y en los contenedores donde un turbo-stream
// mete el flash (`#flash-messages`, `#flash`). Así cada pantalla suma un
// `data-controller` y no tiene que acordarse de anunciar en cada rama de su
// JS: es la lección de `/empacar`, que vivió meses sin sonidos porque un
// helper compartido no obliga a nadie a llamarlo.
//
// No usa `aria-live` en el elemento mismo: casi todos arrancan `hidden` y se
// muestran al escribirles, y un lector no escucha una región que estaba
// escondida. Lo pasa a las regiones fijas del layout (`anunciar.js`).
//
// Urgente si el aviso lo pide (`data-anuncia-cambios-urgente-value="true"`)
// o si lo que entró es un `role="alert"` o un flash de error.
export default class extends Controller {
  static values = { urgente: Boolean }

  connect() {
    this._observador = new MutationObserver((cambios) => this._cambio(cambios))
    this._observador.observe(this.element, { childList: true, subtree: true, characterData: true })
  }

  disconnect() {
    this._observador?.disconnect()
  }

  // Se anuncia **lo que entró**, no el texto entero: cuando el auto-dismiss
  // saca un flash viejo, el contenedor cambia pero no hay nada nuevo que
  // decir. Y no se filtra el texto repetido: la pistola puede decir «ya está
  // en este manifiesto» dos veces seguidas, y las dos son noticia.
  _cambio(cambios) {
    const partes = []
    let urgente = this.urgenteValue

    for (const cambio of cambios) {
      if (cambio.type === "characterData") {
        partes.push(cambio.target.textContent)
        continue
      }
      for (const nodo of cambio.addedNodes) {
        partes.push(nodo.textContent)
        if (nodo.nodeType === Node.ELEMENT_NODE &&
            nodo.matches("[role=alert], [data-flash=alert]")) urgente = true
      }
    }

    const texto = partes.join(" ").replace(/\s+/g, " ").trim()
    if (texto) anunciar(texto, { urgente })
  }
}
