import { Controller } from "@hotwired/stimulus"

// PR-D4.b — Inline edit de un campo via <select> que dispara PATCH al
// servidor en cuanto cambia. Yusef pidió "estado del paquete dropdown
// para modificar en caso de un error" sin obligar a entrar a /edit.
//
// Markup esperado:
//   <div data-controller="inline-select"
//        data-inline-select-url-value="/paquetes/123"
//        data-inline-select-field-value="estado"
//        data-inline-select-resource-value="paquete">
//     <select data-action="change->inline-select#submit"
//             data-inline-select-target="select">
//       <option ...>...</option>
//     </select>
//     <span data-inline-select-target="status" class="hidden">…</span>
//   </div>
//
// Hace fetch PATCH a `url` con body `resource[field]=valor` y muestra
// feedback temporal "✓ Guardado" o "✗ Error".
export default class extends Controller {
  static values = { url: String, field: String, resource: String, feedbackDuration: { type: Number, default: 1500 } }
  static targets = ["select", "status"]

  submit(event) {
    const value = event.target.value
    const body = new FormData()
    body.append(`${this.resourceValue}[${this.fieldValue}]`, value)

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
      } else {
        this.showStatus("✗ Error al guardar", "text-red-600")
        this.selectTarget.disabled = false
      }
    }).catch(() => {
      this.showStatus("✗ Sin conexión", "text-red-600")
      this.selectTarget.disabled = false
    })
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
