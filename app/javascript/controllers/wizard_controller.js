import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["options"]

  selectOption(e) {
    // Brief delay so the user sees their selection highlighted before advancing
    setTimeout(() => e.target.closest("form").requestSubmit(), 300)
  }

  selectService(event) {
    // Auto-advance after brief visual feedback
    setTimeout(() => event.target.closest("form").requestSubmit(), 300)
  }
}
