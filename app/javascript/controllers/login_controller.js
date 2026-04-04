import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["password", "toggleIcon", "submitBtn", "submitText", "spinner", "form"]

  connect() {
    this.element.classList.add("animate-fade-in-up")
  }

  togglePassword() {
    const isPassword = this.passwordTarget.type === "password"
    this.passwordTarget.type = isPassword ? "text" : "password"

    // Swap icon: eye ↔ eye-slash
    this.toggleIconTarget.querySelectorAll("[data-icon]").forEach(icon => {
      icon.classList.toggle("hidden")
    })
  }

  submit() {
    // Prevent double-click
    this.submitBtnTarget.disabled = true
    this.submitTextTarget.classList.add("hidden")
    this.spinnerTarget.classList.remove("hidden")
  }
}
