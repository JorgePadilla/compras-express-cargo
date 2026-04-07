import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["options", "limitWarning"]

  selectOption(e) {
    // Brief delay so the user sees their selection highlighted before advancing
    setTimeout(() => e.target.closest("form").requestSubmit(), 300)
  }

  selectService(event) {
    const isSingle = event.target.dataset.singlePackage === "true"
    if (this.hasLimitWarningTarget) {
      this.limitWarningTarget.classList.toggle("hidden", !isSingle)
    }
    // Auto-advance after brief visual feedback
    setTimeout(() => event.target.closest("form").requestSubmit(), 300)
  }
}
