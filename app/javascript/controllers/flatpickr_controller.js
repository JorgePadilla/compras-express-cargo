import { Controller } from "@hotwired/stimulus"
import flatpickr from "flatpickr"
import { Spanish } from "flatpickr/dist/l10n/es"

// Attaches a Spanish-localized flatpickr to any <input type="date">.
// Shows d/m/Y to the user but submits Y-m-d so Rails still parses it.
export default class extends Controller {
  connect() {
    this.fp = flatpickr(this.element, {
      locale: Spanish,
      dateFormat: "Y-m-d",
      altInput: true,
      altFormat: "d/m/Y",
      allowInput: true,
      disableMobile: true
    })
  }

  disconnect() {
    if (this.fp) {
      this.fp.destroy()
      this.fp = null
    }
  }
}
