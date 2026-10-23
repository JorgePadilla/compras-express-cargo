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
  static targets = ["menu", "backdrop", "pinIcon", "positionIcon", "boton"]
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

  disconnect() {
    document.removeEventListener("keydown", this._alTeclear)
  }

  // ── Mobile drawer (legacy) ──────────────────────────────────
  // PR-A11Y.3 · El botón «Menú» dice si está abierto (`aria-expanded`), el
  // foco entra al primer link al abrir, y Escape cierra y lo devuelve al
  // botón. Antes el foco se quedaba atrás del fondo oscuro.
  toggle() {
    if (!this.hasMenuTarget) return
    if (this.menuTarget.classList.contains("-translate-x-full")) {
      this.open()
    } else {
      this.close()
    }
  }

  open() {
    this.menuTarget.classList.remove("-translate-x-full")
    if (this.hasBackdropTarget) this.backdropTarget.classList.remove("hidden")
    document.body.classList.add("overflow-hidden")
    if (this.hasBotonTarget) this.botonTarget.setAttribute("aria-expanded", "true")
    this._alTeclear ||= (e) => { if (e.key === "Escape") this.close() }
    document.addEventListener("keydown", this._alTeclear)
    this.menuTarget.querySelector("nav a, a")?.focus()
  }

  close() {
    if (!this.hasMenuTarget) return
    const estabaAbierto = !this.menuTarget.classList.contains("-translate-x-full")
    this.menuTarget.classList.add("-translate-x-full")
    if (this.hasBackdropTarget) this.backdropTarget.classList.add("hidden")
    document.body.classList.remove("overflow-hidden")
    document.removeEventListener("keydown", this._alTeclear)
    if (this.hasBotonTarget) {
      this.botonTarget.setAttribute("aria-expanded", "false")
      if (estabaAbierto && window.innerWidth < 1024) this.botonTarget.focus()
    }
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

  // PR-A11Y.3 · Con teclado no hay hover: el rail colapsado se expande
  // cuando el foco entra, y se cierra cuando sale (no al pasar de un link a
  // otro adentro).
  alEnfocar() {
    this.expand()
  }

  alDesenfocar(e) {
    if (this.menuTarget.contains(e.relatedTarget)) return
    this.collapse()
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

  // Aplica las clases visuales al <aside> según el estado actual. El
  // controller vive en el contenedor (para alcanzar el «Menú» del celular),
  // así que el `<aside>` es el target `menu`, no `this.element`.
  applyState() {
    if (!this.hasMenuTarget) return
    const el = this.menuTarget
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
      const pin = this.pinnedValue ? "Desfijar sidebar" : "Fijar sidebar"
      this.pinIconTarget.setAttribute("title", pin)
      this.pinIconTarget.setAttribute("aria-label", pin)
    }
    if (this.hasPositionIconTarget) {
      const lado = this.positionValue === "right" ? "Mover sidebar a la izquierda" : "Mover sidebar a la derecha"
      this.positionIconTarget.setAttribute("title", lado)
      this.positionIconTarget.setAttribute("aria-label", lado)
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
