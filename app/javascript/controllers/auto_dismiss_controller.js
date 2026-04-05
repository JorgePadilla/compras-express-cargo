import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { delay: { type: Number, default: 3000 } }

  connect() {
    this.timeout = setTimeout(() => {
      this.element.style.transition = "opacity 0.3s ease-out"
      this.element.style.opacity = "0"
      setTimeout(() => this.element.remove(), 300)
    }, this.delayValue)
  }

  disconnect() {
    if (this.timeout) clearTimeout(this.timeout)
  }
}
