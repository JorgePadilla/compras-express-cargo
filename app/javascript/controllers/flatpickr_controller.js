import { Controller } from "@hotwired/stimulus"
import flatpickr from "flatpickr"
import { Spanish } from "flatpickr/dist/l10n/es"

// Spanish-localized flatpickr. Acepta dos formas de montaje:
//   1. data-controller="flatpickr" sobre el <input> directamente.
//   2. data-controller="flatpickr" sobre un wrapper que contiene un
//      <input> con data-flatpickr-target="input" (necesario cuando
//      hay otros elementos como un botón "limpiar" que necesita
//      llamar acciones del controller).
//
// - Por defecto: solo fecha. Display d/m/Y, submit Y-m-d.
// - data-flatpickr-time-value="true": fecha + hora. Display
//   d/m/Y H:i, submit Y-m-d H:i.
export default class extends Controller {
  static values = { time: { type: Boolean, default: false } }
  static targets = ["input"]

  connect() {
    const target = this.hasInputTarget ? this.inputTarget
                 : (this.element.tagName === "INPUT" ? this.element
                                                     : this.element.querySelector("input"))
    if (!target) return

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
    this.fp = flatpickr(target, opts)
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
