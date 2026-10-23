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
// - data-flatpickr-solo-hora-value="true": solo la hora, 24 h, H:i y **sin
//   segundos** (PR-P.4, la hora del aviso de la hoja de preparación; `C30-08`:
//   *"no hace falta que diga los segundos"*).
export default class extends Controller {
  static values = { time: { type: Boolean, default: false }, soloHora: { type: Boolean, default: false } }
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
    if (this.soloHoraValue) {
      opts.enableTime = true
      opts.noCalendar = true
      opts.time_24hr = true
      opts.dateFormat = "H:i"
      opts.altFormat = "H:i"
    } else if (this.timeValue) {
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
    this._conSuNombre(target)
  }

  // Con `altInput` el `<label for>` apunta al input **escondido**, y el que se
  // ve y se toca queda sin nombre: el lector de pantalla anuncia «campo de
  // edición» a secas, y tocar el rótulo no lleva a la fecha. El visible toma
  // el nombre del rótulo (Jorge, 2026-10-15: *"make sure the page is
  // accessible"*), en las fechas de toda la app y no solo en la que se miró.
  //
  // PR-A11Y.6 · Y lo demás que el input escondido sabía y el visible no: qué
  // ayuda lo describe, si tiene un error, y `aria-required` (el `required` ya
  // lo copiaba flatpickr, pero no todos los lectores lo leen sin el aria). El
  // rótulo se devuelve a su input en `disconnect`, para que un montaje
  // siguiente lo encuentre donde lo busca; el test del caché de Turbo pasa
  // con o sin esto, así que es una red y no un arreglo.
  _conSuNombre(target) {
    const alt = this.fp?.altInput
    if (!alt) return

    for (const attr of ["aria-label", "aria-labelledby", "aria-describedby", "aria-invalid", "aria-required"]) {
      if (target.hasAttribute(attr)) alt.setAttribute(attr, target.getAttribute(attr))
    }
    if (target.required) {
      alt.required = true
      alt.setAttribute("aria-required", "true")
    }

    if (!target.id) return
    const rotulo = document.querySelector(`label[for="${CSS.escape(target.id)}"]`)
    if (!rotulo) return

    alt.id = `${target.id}_visible`
    rotulo.htmlFor = alt.id
    this._rotulo = { label: rotulo, para: target.id }
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
    if (this._rotulo) {
      this._rotulo.label.htmlFor = this._rotulo.para
      this._rotulo = null
    }
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
