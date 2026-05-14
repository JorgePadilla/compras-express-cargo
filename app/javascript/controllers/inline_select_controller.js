import { Controller } from "@hotwired/stimulus"

// PR-D4.b — Inline edit de un campo via <select> que dispara PATCH al
// servidor en cuanto cambia. Yusef pidió "estado del paquete dropdown
// para modificar en caso de un error" sin obligar a entrar a /edit.
//
// PR-D7.b — Cuando el field es `estado` y el cambio representa un
// retroceso del pipeline, se intercepta antes del PATCH y se pide
// confirmación vía window.cecConfirm. Si el usuario cancela, el select
// vuelve al valor original. Si confirma, se envía con
// `confirm_retroceso=1` para que el servidor lo deje pasar.
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
    feedbackDuration: { type: Number, default: 1500 },
    pipeline: { type: Array, default: [] },
    excepcionales: { type: Array, default: [] },
    current: String
  }
  static targets = ["select", "status"]

  async submit(event) {
    const value = event.target.value

    // Si el campo es `estado` y el cambio es retroceso, pedir confirmación
    // antes de enviar.
    let confirmRetroceso = false
    if (this.fieldValue === "estado" && this.isRetroceso(this.currentValue, value)) {
      const pasos = this.pasosAtras(this.currentValue, value)
      const ok = await (window.cecConfirm
        ? window.cecConfirm(
            `Estás retrocediendo el paquete ${pasos} paso${pasos === 1 ? "" : "s"} ` +
            `en el pipeline (${this.humanize(this.currentValue)} → ${this.humanize(value)}). ` +
            `Esto puede dejar referencias inconsistentes con Entrega/Pre-Factura/Venta. ¿Confirmás?`,
            { title: "Confirmar retroceso del pipeline", confirmLabel: "Confirmar retroceso", danger: true }
          )
        : Promise.resolve(window.confirm(`Retroceso ${pasos} paso(s). ¿Confirmás?`)))
      if (!ok) {
        // Revertir al valor anterior y abortar.
        this.selectTarget.value = this.currentValue
        return
      }
      confirmRetroceso = true
    }

    const body = new FormData()
    body.append(`${this.resourceValue}[${this.fieldValue}]`, value)
    if (confirmRetroceso) body.append("confirm_retroceso", "1")

    this.showStatus("Guardando…", "text-gray-500")
    this.selectTarget.disabled = true

    fetch(this.urlValue, {
      method: "PATCH",
      headers: {
        "X-CSRF-Token": this.csrfToken,
        "Accept": "text/vnd.turbo-stream.html, text/html"
      },
      body: body
    }).then(response => {
      if (response.ok) {
        this.showStatus("✓ Guardado", "text-cec-teal-dark")
        // Recarga para que el badge / clases CSS reflejen el nuevo estado.
        setTimeout(() => window.location.reload(), 600)
      } else if (response.status === 403 || response.status === 422) {
        // El servidor renderizó el show con el modal de bloqueo.
        // Navegar a la URL para que aparezca.
        this.selectTarget.value = this.currentValue
        this.selectTarget.disabled = false
        this.showStatus("Acción bloqueada", "text-red-600")
        window.location.href = this.urlValue
      } else {
        this.showStatus("✗ Error al guardar", "text-red-600")
        this.selectTarget.disabled = false
      }
    }).catch(() => {
      this.showStatus("✗ Sin conexión", "text-red-600")
      this.selectTarget.disabled = false
    })
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
}
