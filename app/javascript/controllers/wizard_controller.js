import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["options"]

  selectOption(e) {
    // Visual feedback is handled by peer-checked CSS
    // This method can be extended for animations
  }
}
