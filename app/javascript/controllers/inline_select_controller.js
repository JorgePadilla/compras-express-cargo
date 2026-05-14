import { Controller } from "@hotwired/stimulus"

// PR-D4.b / PR-D7.b — Inline edit de un campo via <select>. En PR-D7.c
// reemplazamos el flujo `fetch + setTimeout reload` por un submit
// programático vía Turbo. Beneficios:
// - No race entre reload y nuevos clicks (eliminó el "✗ Sin conexión").
// - Turbo swap-ea el <turbo-frame id="paquete_dynamic"> con el HTML del
//   server, incluyendo el modal de bloqueo cuando aplica.
// - Sin "manual" handling de status 403/422: Turbo respeta unprocessable
//   y renderiza el body en el frame.
//
// Markup esperado:
//   <div data-controller="inline-select"
//        data-inline-select-url-value="/paquetes/123"
//        data-inline-select-field-value="estado"
//        data-inline-select-resource-value="paquete"
//        data-inline-select-pipeline-value='["recibido_miami",...]'
//        data-inline-select-excepcionales-value='["retenido",...]'
//        data-inline-select-current-value="recibido_miami">
//     <select data-action="change->inline-select#submit"
//             data-inline-select-target="select">…</select>
//     <span data-inline-select-target="status" class="hidden">…</span>
//   </div>
export default class extends Controller {
  static values = {
    url: String,
    field: String,
    resource: String,
    pipeline: { type: Array, default: [] },
    excepcionales: { type: Array, default: [] },
    current: String,
    frame: { type: String, default: "paquete_dynamic" }
  }
  static targets = ["select", "status"]

  async submit(event) {
    const value = event.target.value

    // Detección client-side de retroceso para evitar un round-trip si el
    // usuario va a cancelar. Server sigue validando como defensa.
    let confirmRetroceso = false
    if (this.fieldValue === "estado" && this.isRetroceso(this.currentValue, value)) {
      const pasos = this.pasosAtras(this.currentValue, value)
      const ok = await this.askRetroceso(pasos, this.currentValue, value)
      if (!ok) {
        this.selectTarget.value = this.currentValue
        return
      }
      confirmRetroceso = true
    }

    this.showStatus("Guardando…", "text-gray-500")
    this.selectTarget.disabled = true

    // Construir form oculto y dejar que Turbo procese el submit. El frame
    // target hace que la respuesta (sea redirect a show, o 422 con modal)
    // reemplace el <turbo-frame id="paquete_dynamic"> en su lugar — sin
    // recargar la página y sin riesgos de carrera con setTimeout.
    const form = document.createElement("form")
    form.method = "post"
    form.action = this.urlValue
    form.setAttribute("data-turbo-frame", this.frameValue)
    form.style.display = "none"
    form.append(this.#hidden("_method", "patch"))
    form.append(this.#hidden("authenticity_token", this.csrfToken))
    form.append(this.#hidden(`${this.resourceValue}[${this.fieldValue}]`, value))
    if (confirmRetroceso) form.append(this.#hidden("confirm_retroceso", "1"))

    document.body.appendChild(form)
    form.requestSubmit()
    // Cleanup tras el swap.
    setTimeout(() => form.remove(), 5000)
  }

  askRetroceso(pasos, from, to) {
    const plural = pasos === 1 ? "" : "s"
    const msg = `Estás retrocediendo el paquete ${pasos} paso${plural} ` +
                `(${this.humanize(from)} → ${this.humanize(to)}). ` +
                `Esto puede dejar referencias inconsistentes con Entrega/Pre-Factura/Venta. ¿Confirmás?`
    if (window.cecConfirm) {
      return window.cecConfirm(msg, {
        title: "Confirmar retroceso del pipeline",
        confirmLabel: "Confirmar retroceso",
        danger: true
      })
    }
    return Promise.resolve(window.confirm(msg))
  }

  isRetroceso(from, to) {
    if (!from || !to || from === to) return false
    const exc = this.excepcionalesValue || []
    if (exc.includes(from) || exc.includes(to)) return false
    const pipe = this.pipelineValue || []
    const i = pipe.indexOf(from)
    const j = pipe.indexOf(to)
    if (i < 0 || j < 0) return false
    return j < i
  }

  pasosAtras(from, to) {
    const pipe = this.pipelineValue || []
    const i = pipe.indexOf(from)
    const j = pipe.indexOf(to)
    if (i < 0 || j < 0) return 0
    return Math.max(0, i - j)
  }

  humanize(s) {
    if (!s) return ""
    return s.replace(/_/g, " ").replace(/\b\w/g, c => c.toUpperCase())
  }

  showStatus(text, colorClass) {
    if (!this.hasStatusTarget) return
    this.statusTarget.textContent = text
    this.statusTarget.className = `text-[10px] font-semibold ${colorClass} ml-2`
    this.statusTarget.classList.remove("hidden")
  }

  get csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content || ""
  }

  #hidden(name, value) {
    const i = document.createElement("input")
    i.type = "hidden"
    i.name = name
    i.value = value
    return i
  }
}
