import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["iconLight", "iconDark"]
  static values  = { url: String }

  connect() {
    this.updateIcons()
    this._mediaQuery = window.matchMedia("(prefers-color-scheme: dark)")
    this._onSystemChange = () => {
      const dataTheme = document.documentElement.dataset.theme
      if (dataTheme === "auto") {
        document.documentElement.classList.toggle("dark", this._mediaQuery.matches)
        this.updateIcons()
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
    this.updateIcons()
    this.persist(nuevoTema)
  }

  updateIcons() {
    const isDark = document.documentElement.classList.contains("dark")
    if (this.hasIconLightTarget) this.iconLightTarget.classList.toggle("hidden", isDark)
    if (this.hasIconDarkTarget)  this.iconDarkTarget.classList.toggle("hidden", !isDark)
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
