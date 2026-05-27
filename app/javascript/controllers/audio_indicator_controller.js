import { Controller } from "@hotwired/stimulus"

// Escucha el evento global `audio:played` que dispara audio_controller.js
// y hace parpadear el icono correspondiente al tipo de sonido. Esto da
// feedback visual cuando se reproduce un audio (útil en entornos ruidosos
// o si el speaker está en mute).
export default class extends Controller {
  static targets = ["icon"]

  connect() {
    this._handler = this.handlePlayed.bind(this)
    document.addEventListener("audio:played", this._handler)
  }

  disconnect() {
    document.removeEventListener("audio:played", this._handler)
  }

  handlePlayed(e) {
    const type = e.detail && e.detail.type
    if (!type) return

    const icon = this.iconTargets.find(el => el.dataset.audioType === type)
    if (!icon) return

    icon.classList.remove("opacity-0", "scale-90")
    icon.classList.add("opacity-100", "scale-110")

    clearTimeout(icon._fadeTimer)
    icon._fadeTimer = setTimeout(() => {
      icon.classList.add("opacity-0", "scale-90")
      icon.classList.remove("opacity-100", "scale-110")
    }, 900)
  }
}
