import BusquedaAutocomplete from "controllers/busqueda_autocomplete"

// Modal para asignar / cambiar el Tercero (cliente final) de un paquete.
// Reemplaza el flow viejo de "Asignar → edit mode", que confundía a los
// operadores porque aterrizaban en el form completo sin contexto.
//
// PR-C6.33: la búsqueda de adentro era una de las ocho copias, y la más pobre
// de todas — 2 caracteres, sin preselección y **sin teclado**: dentro de un
// modal, donde lo natural es teclear y confirmar con Enter, había que soltar
// el teclado y buscar el mouse. Ahora hereda de `BusquedaAutocomplete`.
//
// Lo propio de esta pantalla, que se conserva:
//   · la lista vive en un `<ul>` adentro de un `<dialog>`, así que las filas
//     van envueltas en `<li>` y no hay nada que mostrar/ocultar
//   · elegir **envía el formulario al instante**. Yusef: el paso intermedio de
//     "seleccionar + click en Asignar" se sentía trabado
export default class extends BusquedaAutocomplete {
  static values = { searchUrl: String, paqueteId: Number }
  static targets = [ "dialog", "input", "results", "hiddenId", "form", "selectedSummary" ]

  get _lista() { return this.resultsTarget }
  get _oculto() { return this.hasHiddenIdTarget ? this.hiddenIdTarget : null }
  get _url() { return this.searchUrlValue }
  get _envoltorio() { return "li" }

  _textoVacio() { return "Sin resultados — probá con otra búsqueda." }

  // La lista está adentro del `<dialog>`: se vacía, no se esconde.
  abrir() {}
  cerrar() { this._activo = -1 }

  _filaHtml(c) {
    return `data-id="${c.id}"
            data-codigo="${c.codigo}"
            data-nombre="${c.nombre}">
        <div class="min-w-0">
          <div class="font-mono text-sm font-semibold text-cec-navy dark:text-cec-gold">${c.codigo}</div>
          <div class="text-xs text-gray-700 dark:text-gray-200 truncate">${c.nombre}</div>
        </div>
        ${c.categoria_precio ? `<span class="text-[10px] uppercase tracking-wider text-gray-500 shrink-0">${c.categoria_precio}</span>` : ""}`
  }

  // Elegir = asignar. No hay paso intermedio.
  _alSeleccionar(datos) {
    const btn = this._items()[this._activo]
    if (btn) {
      btn.disabled = true
      btn.classList.add("opacity-60")
      btn.innerHTML = `<span class="text-sm italic text-cec-purple-dark">Asignando ${datos.codigo} — ${datos.nombre}…</span>`
    }
    if (this.hasFormTarget) this.formTarget.requestSubmit()
  }

  // ── El modal, que sí es propio ──

  open(e) {
    e.preventDefault()
    if (!this.hasDialogTarget) return

    if (this.dialogTarget.showModal) this.dialogTarget.showModal()
    else this.dialogTarget.classList.remove("hidden")
    this.inputTarget?.focus()
  }

  close(e) {
    e?.preventDefault()
    if (this.hasDialogTarget) {
      if (this.dialogTarget.close) this.dialogTarget.close()
      else this.dialogTarget.classList.add("hidden")
    }
    this.clearSelection()
  }

  clearSelection() {
    if (this.hasHiddenIdTarget) this.hiddenIdTarget.value = ""
    if (this.hasSelectedSummaryTarget) {
      this.selectedSummaryTarget.innerHTML = ""
      this.selectedSummaryTarget.classList.add("hidden")
    }
    if (this.hasInputTarget) this.inputTarget.value = ""
    if (this.hasResultsTarget) this.resultsTarget.replaceChildren()
    if (this.hasFormTarget) {
      const submitBtn = this.formTarget.querySelector("button[type=submit]")
      if (submitBtn) submitBtn.disabled = true
    }
  }

  // ── Alias en el idioma viejo, para no tocar markup que ya funciona ──
  search() { this.buscar() }
  onKeydown(e) { this.teclado(e) }
  select(e) { this.elegir(e) }
  renderResults(items) { this.pintar(items) }
}
