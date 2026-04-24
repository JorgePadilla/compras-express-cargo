import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["iconLight", "iconDark", "button"]
  static values  = { url: String }

  connect() {
    this.updateUI()
    this._mediaQuery = window.matchMedia("(prefers-color-scheme: dark)")
    this._onSystemChange = () => {
      const dataTheme = document.documentElement.dataset.theme
      if (dataTheme === "auto") {
        document.documentElement.classList.toggle("dark", this._mediaQuery.matches)
        this.updateUI()
      }
    }
    this._mediaQuery.addEventListener("change", this._onSystemChange)
  }

  disconnect() {
    if (this._mediaQuery && this._onSystemChange) {
      this._mediaQuery.removeEventListener("change", this._onSystemChange)
    }
  }

  toggle() {
    const isDark = document.documentElement.classList.toggle("dark")
    const nuevoTema = isDark ? "dark" : "light"
    document.documentElement.dataset.theme = nuevoTema
    this.updateUI()
    this.persist(nuevoTema)
  }

  // Actualiza iconos visibles, aria-pressed y aria-label para que los
  // usuarios de screen reader siempre sepan en qué modo están y qué hace
  // el botón al clickear.
  updateUI() {
    const isDark = document.documentElement.classList.contains("dark")
    if (this.hasIconLightTarget) this.iconLightTarget.classList.toggle("hidden", isDark)
    if (this.hasIconDarkTarget)  this.iconDarkTarget.classList.toggle("hidden", !isDark)
    if (this.hasButtonTarget) {
      this.buttonTarget.setAttribute("aria-pressed", String(isDark))
      this.buttonTarget.setAttribute("aria-label", isDark ? "Cambiar a tema claro" : "Cambiar a tema oscuro")
    }
  }

  async persist(tema) {
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
        body: JSON.stringify({ tema: tema })
      })
    } catch (_) {
      // silencioso: si falla la persistencia, el tema igual aplicó visualmente
    }
  }
}
