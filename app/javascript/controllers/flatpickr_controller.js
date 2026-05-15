import { Controller } from "@hotwired/stimulus"
import flatpickr from "flatpickr"
import { Spanish } from "flatpickr/dist/l10n/es"

// Attaches a Spanish-localized flatpickr.
// - Por defecto: solo fecha. Display d/m/Y, submit Y-m-d.
// - Si data-flatpickr-time-value="true": fecha + hora. Display
//   d/m/Y H:i, submit Y-m-d H:i (Rails parsea con TZ del server).
export default class extends Controller {
  static values = { time: { type: Boolean, default: false } }

  connect() {
    const opts = {
      locale: Spanish,
      allowInput: true,
      disableMobile: true,
      altInput: true
    }
    if (this.timeValue) {
      opts.enableTime = true
      opts.time_24hr = true
      opts.dateFormat = "Y-m-d H:i"
      opts.altFormat = "d/m/Y H:i"
    } else {
      opts.dateFormat = "Y-m-d"
      opts.altFormat = "d/m/Y"
    }
    this.fp = flatpickr(this.element, opts)
  }

  disconnect() {
    if (this.fp) {
      this.fp.destroy()
      this.fp = null
    }
  }

  clear(event) {
    event.preventDefault()
    if (this.fp) this.fp.clear()
  }
}
