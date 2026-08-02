import { Controller } from "@hotwired/stimulus"

// PR-D4.b / PR-D7.b / PR-D7.d — Inline edit de un campo via <select>.
// El submit se hace vía Turbo (form oculto con data-turbo-frame) para
// que el server pueda inyectar modals de bloqueo dentro del frame.
//
// Para retrocesos del pipeline, NO confirmamos client-side: el server
// detecta el caso y devuelve 422 con un modal que lista exactamente
// qué fechas + FKs se van a limpiar antes de pedir confirmación. Esto
// asegura un solo punto de decisión con info completa.
//
// Markup esperado:
//   <div data-controller="inline-select"
//        data-inline-select-url-value="/paquetes/123"
//        data-inline-select-field-value="estado"
//        data-inline-select-resource-value="paquete">
//     <select data-action="change->inline-select#submit"
//             data-inline-select-target="select">…</select>
//     <span data-inline-select-target="status" class="hidden">…</span>
//   </div>
export default class extends Controller {
  static values = {
    url: String,
    field: String,
    resource: String,
    frame: { type: String, default: "paquete_dynamic" }
  }
  static targets = ["select", "status"]

  submit(event) {
    const value = event.target.value

    this.showStatus("Guardando…", "text-gray-500")
    this.selectTarget.disabled = true

    const form = document.createElement("form")
    form.method = "post"
    form.action = this.urlValue
    form.setAttribute("data-turbo-frame", this.frameValue)
    form.style.display = "none"
    form.append(this.#hidden("_method", "patch"))
    form.append(this.#hidden("authenticity_token", this.csrfToken))
    form.append(this.#hidden(`${this.resourceValue}[${this.fieldValue}]`, value))

    document.body.appendChild(form)
    form.requestSubmit()
    setTimeout(() => form.remove(), 5000)
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
