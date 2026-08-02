import { Controller } from "@hotwired/stimulus"

// Auto-submit del form de quick filters en /paquetes.
// Selects + date inputs → submit inmediato (change event).
// Text inputs → submit con debounce (input event); Enter dispara
// inmediato (saltando el debounce).
export default class extends Controller {
  connect() {
    this.timer = null
  }

  disconnect() {
    clearTimeout(this.timer)
  }

  submit() {
    clearTimeout(this.timer)
    this.element.requestSubmit()
  }

  debouncedSubmit() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.element.requestSubmit(), 400)
  }
}
