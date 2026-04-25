import { Controller } from "@hotwired/stimulus"

// Stimulus controller para selección múltiple de filas en el listado de
// paquetes. Mantiene visible una barra flotante con contador y acciones
// (imprimir, exportar Excel/PDF) cuando hay ≥ 1 fila seleccionada.
export default class extends Controller {
  static targets = ["row", "selectAll", "bar", "counter", "idsField"]

  connect() {
    this.updateUI()
  }

  toggleAll(event) {
    const checked = event.currentTarget.checked
    this.rowTargets.forEach(cb => { cb.checked = checked })
    this.updateUI()
  }

  toggleRow() {
    this.syncSelectAll()
    this.updateUI()
  }

  syncSelectAll() {
    if (!this.hasSelectAllTarget) return
    const total = this.rowTargets.length
    const selected = this.rowTargets.filter(cb => cb.checked).length
    this.selectAllTarget.checked = total > 0 && selected === total
    this.selectAllTarget.indeterminate = selected > 0 && selected < total
  }

  updateUI() {
    const selected = this.rowTargets.filter(cb => cb.checked)
    const count = selected.length

    if (this.hasCounterTarget) this.counterTarget.textContent = count
    if (this.hasBarTarget) this.barTarget.classList.toggle("hidden", count === 0)
    if (this.hasIdsFieldTarget) {
      this.idsFieldTargets.forEach(f => {
        f.innerHTML = selected.map(cb => `<input type="hidden" name="paquete_ids[]" value="${cb.value}">`).join("")
      })
    }
  }

  clear() {
    this.rowTargets.forEach(cb => { cb.checked = false })
    if (this.hasSelectAllTarget) {
      this.selectAllTarget.checked = false
      this.selectAllTarget.indeterminate = false
    }
    this.updateUI()
  }
}
