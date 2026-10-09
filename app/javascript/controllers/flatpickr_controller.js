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
    this._noEsUnaTarjeta()
  }

  // Chrome ofrecía **tarjetas de crédito guardadas** al hacer clic en una fecha.
  // Jorge: *"salen las tarjetas de crédito, como que el campo es de tarjeta
  // pero es fecha, ¿por qué?"*.
  //
  // Por `altInput: true`: flatpickr esconde el input real —el que lleva el
  // `name`— y crea **otro de texto, visible, sin name y sin autocomplete**.
  // Chrome ve un campo anónimo que muestra `17/08/2026` dentro de un formulario
  // y lo clasifica de oído como fecha de vencimiento de tarjeta.
  //
  // Va acá y no en la pantalla donde se reportó: el `altInput` lo tienen las
  // seis fechas de la app, así que arreglarlo en una dejaría las otras cinco
  // ofreciendo tarjetas.
  _noEsUnaTarjeta() {
    const alt = this.fp?.altInput
    if (!alt) return

    alt.setAttribute("autocomplete", "off")
    // Los mismos que este repo ya le pone al tracking en `_paquete_card` para
    // sacarse de encima a 1Password y LastPass.
    alt.setAttribute("data-1p-ignore", "true")
    alt.setAttribute("data-lpignore", "true")
    alt.setAttribute("data-form-type", "other")
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
