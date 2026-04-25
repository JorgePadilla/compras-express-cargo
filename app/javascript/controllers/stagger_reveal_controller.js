import { Controller } from "@hotwired/stimulus"

// Aplica `animation-delay` incremental a cada hijo con `[data-stagger]`,
// produciendo una entrada escalonada del bloque. La animación base está
// definida via clase `.animate-stagger` (fade-in-up) en application.css.
//
// Respeta `prefers-reduced-motion`: si está activo, no aplica ningún delay
// (la animación queda neutralizada por la regla CSS).
export default class extends Controller {
  static values = {
    step:    { type: Number, default: 60 },   // ms entre items
    initial: { type: Number, default: 0 }     // ms antes del primer item
  }

  connect() {
    const reduce = window.matchMedia?.("(prefers-reduced-motion: reduce)").matches
    if (reduce) return

    const items = this.element.querySelectorAll("[data-stagger]")
    items.forEach((el, idx) => {
      el.style.animationDelay = `${this.initialValue + idx * this.stepValue}ms`
    })
  }
}
