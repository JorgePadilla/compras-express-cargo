import { Controller } from "@hotwired/stimulus"

// PR-D2.b — Plantillas reutilizables para "Notas al Cliente".
// Inyecta el texto de una plantilla seleccionada (atributo data-text)
// dentro del textarea destino. Si el textarea ya tiene contenido,
// agrega la plantilla precedida de un separador en blanco.
//
// Uso esperado en la vista:
//   <div data-controller="plantilla-picker"
//        data-plantilla-picker-target-selector-value="#paquete_notas_al_cliente">
//     <button type="button"
//             data-action="plantilla-picker#insert"
//             data-text="Texto de la plantilla">…</button>
//   </div>
export default class extends Controller {
  static values = { targetSelector: String }

  insert(event) {
    event.preventDefault()
    const textarea = document.querySelector(this.targetSelectorValue)
    if (!textarea) return

    const incoming = event.currentTarget.dataset.text || ""
    if (!incoming) return

    const current = textarea.value
    textarea.value = current.trim().length === 0
      ? incoming
      : `${current.replace(/\s+$/, "")}\n\n${incoming}`

    textarea.focus()
    textarea.dispatchEvent(new Event("input", { bubbles: true }))
  }
}
