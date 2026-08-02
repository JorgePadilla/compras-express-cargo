import { Controller } from "@hotwired/stimulus"

// PR sidebar hover-expand: el sidebar arranca colapsado en desktop,
// se expande al hover (overlay sobre el contenido), y permite:
//  - 📌 pin: queda fijo abierto sin auto-colapsar.
//  - ↔ position: alterna entre left y right.
// Las 3 preferencias persisten por usuario vía PATCH a sidebar_preferences.
//
// Mobile (<1024px) mantiene el comportamiento clásico de drawer
// (slide-in con backdrop) — la lógica de hover se desactiva.
//
// Markup esperado:
//   <aside data-controller="sidebar"
//          data-sidebar-url-value="/preferencia_sidebar"
//          data-sidebar-collapsed-value="true"
//          data-sidebar-pinned-value="false"
//          data-sidebar-position-value="left"
//          data-action="mouseenter->sidebar#expand mouseleave->sidebar#collapse">
//     <button data-action="click->sidebar#togglePin">📌</button>
//     <button data-action="click->sidebar#togglePosition">↔</button>
//     ...
//   </aside>
export default class extends Controller {
  static targets = ["menu", "backdrop", "pinIcon", "positionIcon"]
  static values  = {
    url: String,
    collapsed: Boolean,
    pinned: Boolean,
    position: String
  }
  static classes = ["collapsed", "pinned", "right"]

  connect() {
    this.applyState()
  }

  // ── Mobile drawer (legacy) ──────────────────────────────────
  toggle() {
    if (!this.hasMenuTarget) return
    this.menuTarget.classList.toggle("-translate-x-full")
    this.backdropTarget?.classList.toggle("hidden")
    document.body.classList.toggle("overflow-hidden")
  }

  close() {
    if (!this.hasMenuTarget) return
    this.menuTarget.classList.add("-translate-x-full")
    this.backdropTarget?.classList.add("hidden")
    document.body.classList.remove("overflow-hidden")
  }

  navigate() {
    if (window.innerWidth < 1024) this.close()
  }

  // ── Desktop hover-expand ───────────────────────────────────
  expand() {
    if (window.innerWidth < 1024) return
    if (this.pinnedValue) return
    this.collapsedValue = false
    this.applyState()
  }

  collapse() {
    if (window.innerWidth < 1024) return
    if (this.pinnedValue) return
    this.collapsedValue = true
    this.applyState()
  }

  togglePin(e) {
    e?.preventDefault()
    this.pinnedValue = !this.pinnedValue
    // Si lo pinearon, asegurarse de que esté expandido.
    if (this.pinnedValue) this.collapsedValue = false
    this.applyState()
    this.persist({ pinned: this.pinnedValue, collapsed: this.collapsedValue })
  }

  togglePosition(e) {
    e?.preventDefault()
    this.positionValue = this.positionValue === "right" ? "left" : "right"
    this.applyState()
    this.persist({ position: this.positionValue })
  }

  // Aplica las clases visuales al <aside> según el estado actual.
  applyState() {
    const el = this.element
    el.classList.toggle("is-collapsed", this.collapsedValue)
    el.classList.toggle("is-pinned",    this.pinnedValue)
    el.classList.toggle("is-right",     this.positionValue === "right")

    // Body recibe modificadores para que el main pueda compensar
    // (ml/mr 16 cuando el sidebar colapsado, 64 cuando pinned-expanded).
    document.body.classList.toggle("sidebar-pinned",   this.pinnedValue)
    document.body.classList.toggle("sidebar-right",    this.positionValue === "right")
    document.body.classList.toggle("sidebar-collapsed", this.collapsedValue)

    if (this.hasPinIconTarget) {
      this.pinIconTarget.setAttribute("aria-pressed", String(this.pinnedValue))
      this.pinIconTarget.setAttribute("title", this.pinnedValue ? "Desfijar sidebar" : "Fijar sidebar")
    }
    if (this.hasPositionIconTarget) {
      this.positionIconTarget.setAttribute(
        "title", this.positionValue === "right" ? "Mover sidebar a la izquierda" : "Mover sidebar a la derecha"
      )
    }
  }

  async persist(payload) {
    if (!this.urlValue) return
    const csrfToken = document.querySelector("meta[name='csrf-token']")?.content
    try {
      await fetch(this.urlValue, {
        method: "PATCH",
        headers: {
          "Accept": "application/json",
          "Content-Type": "application/json",
          "X-CSRF-Token": csrfToken
        },
        body: JSON.stringify(payload)
      })
    } catch (_) {
      // silencioso: estado visual ya aplicó.
    }
  }
}
