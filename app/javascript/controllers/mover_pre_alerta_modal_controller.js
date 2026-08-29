import BusquedaAutocomplete from "controllers/busqueda_autocomplete"

// Modal para mover un paquete a otra pre-alerta.
//
// PR-C6.33: octava y última de las copias de la misma interacción. Pedía 2
// caracteres, no preseleccionaba y no tenía teclado.
//
// Lo propio de esta pantalla, que se conserva:
//   · la lista vive en un `<ul>` adentro de un `<dialog>`
//   · elegir **no** envía: muestra un resumen de la elegida y habilita el
//     botón. A diferencia de asignar-tercero, mover un paquete de pre-alerta
//     conviene confirmarlo — la fila trae estado y si es consolidada, que es
//     justo lo que hay que mirar antes de mover
export default class extends BusquedaAutocomplete {
  static values = { searchUrl: String, paqueteId: Number }
  static targets = [ "dialog", "input", "results", "hiddenId", "form", "selectedSummary" ]

  get _lista() { return this.resultsTarget }
  get _oculto() { return this.hasHiddenIdTarget ? this.hiddenIdTarget : null }
  get _url() { return this.searchUrlValue }
  get _envoltorio() { return "li" }

  _textoVacio() { return "Sin resultados — probá con otra búsqueda." }

  // La lista está adentro del `<dialog>`: se vacía, no se esconde.
  //
  // C20-10: esto sobreescribía `cerrar()` entero, así que se perdía el cancel
  // de la búsqueda en vuelo que la base hace ahí. Ahora solo se sobreescribe
  // el ocultar —que acá no aplica— y el cancel llega igual: una respuesta
  // tardía ya no puede repintar la lista después de elegir.
  abrir() {}
  _ocultarLista() {}

  _filaHtml(pa) {
    return `data-id="${pa.id}"
            data-numero="${pa.numero}"
            data-titulo="${pa.titulo || ""}"
            data-cliente="${pa.cliente || ""}">
        <div class="min-w-0">
          <div class="font-mono text-sm font-semibold text-cec-navy dark:text-cec-gold">${pa.numero}</div>
          <div class="text-xs text-gray-700 dark:text-gray-200 truncate">${pa.titulo || ""}</div>
          <div class="text-xs text-gray-500 dark:text-gray-400 truncate">${pa.cliente || ""}</div>
        </div>
        <div class="flex items-center gap-1 shrink-0">
          <span class="text-[10px] uppercase tracking-wider font-bold px-1.5 py-0.5 rounded bg-gray-100 dark:bg-gray-700 text-gray-700 dark:text-gray-200">${pa.estado}</span>
          ${pa.consolidado ? `<span class="text-[10px] uppercase tracking-wider font-bold px-1.5 py-0.5 rounded bg-cec-gold/15 text-cec-gold-dark">Consolidado</span>` : ""}
        </div>`
  }

  // Elegir muestra el resumen y habilita el botón. No envía solo: mover un
  // paquete de pre-alerta conviene confirmarlo.
  _alSeleccionar({ numero, titulo, cliente }) {
    if (this.hasSelectedSummaryTarget) {
      this.selectedSummaryTarget.innerHTML = `
        <div class="px-4 py-2 bg-cec-teal/10 dark:bg-cec-teal/20 ring-1 ring-cec-teal/30 rounded-lg">
          <p class="text-xs font-semibold uppercase tracking-wider text-cec-teal-dark dark:text-cec-teal-light">Seleccionada:</p>
          <p class="font-mono text-sm font-semibold text-cec-navy dark:text-cec-gold">${numero}</p>
          <p class="text-xs text-gray-700 dark:text-gray-200 truncate">${titulo || ""}</p>
          <p class="text-xs text-gray-500 dark:text-gray-400 truncate">${cliente || ""}</p>
        </div>
      `
      this.selectedSummaryTarget.classList.remove("hidden")
    }
    this._habilitarSubmit(true)
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
    this._habilitarSubmit(false)
  }

  _habilitarSubmit(habilitado) {
    if (!this.hasFormTarget) return

    const btn = this.formTarget.querySelector("button[type=submit]")
    if (btn) btn.disabled = !habilitado
  }

  // ── Alias en el idioma viejo, para no tocar markup que ya funciona ──
  search() { this.buscar() }
  onKeydown(e) { this.teclado(e) }
  select(e) { this.elegir(e) }
  renderResults(items) { this.pintar(items) }
}
