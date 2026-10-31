import { Controller } from "@hotwired/stimulus"

// PR-P.12 · Lo que se elige se manda solo. Jorge, 2026-10-31, en la hoja de
// preparación: *"siento la experiencia extraña… que todos los clicks tengan
// sentido"*. Elegir «Editar» pintaba la tarjeta y nada más: abajo seguía la
// hoja de «nuevas» hasta apretar un botón que decía otra cosa («Ver
// manifiestos», «Guardar y empezar a auditar»).
//
// Se monta en el formulario; cada casilla o radio lleva
// `change->auto-envio#enviar`. `requestSubmit()` sin botón: el servidor guarda
// y vuelve a la hoja, sin «empezar». El foco vuelve a lo que se tocó —la
// página entera se repinta, y si no el foco caía en el body—.
export default class extends Controller {
  connect() {
    const id = sessionStorage.getItem("autoEnvioFoco")
    if (!id) return
    sessionStorage.removeItem("autoEnvioFoco")
    const el = document.getElementById(id)
    if (el) requestAnimationFrame(() => el.focus({ preventScroll: true }))
  }

  enviar(event) {
    if (event?.target?.id) sessionStorage.setItem("autoEnvioFoco", event.target.id)
    this.element.requestSubmit()
  }
}
