import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["options", "limitWarning"]

  selectOption(e) {
    // Visual feedback is handled by peer-checked CSS
    // This method can be extended for animations
  }

  selectService(event) {
    const isSingle = event.target.dataset.singlePackage === "true"
    if (this.hasLimitWarningTarget) {
      this.limitWarningTarget.classList.toggle("hidden", !isSingle)
    }
  }
}
