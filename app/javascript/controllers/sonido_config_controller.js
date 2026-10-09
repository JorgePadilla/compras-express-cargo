import { Controller } from "@hotwired/stimulus"

// PR-9.c: diálogo de configuración de sonidos que se abre desde el header de
// /etiquetar y /entrega_personal ("cambio de sonidos en el mismo modal" —
// Yusef, 2026-08-01). Ajusta el `audio` controller que vive en la misma
// pantalla y persiste la preferencia por usuario.
export default class extends Controller {
  static targets = ["dialog", "toggle", "slider", "valor", "variante", "motivo"]
  static values = { url: String }

  open() {
    if (this.hasDialogTarget) this.dialogTarget.showModal()
  }

  close() {
    if (this.hasDialogTarget) this.dialogTarget.close()
  }

  // El slider y el toggle aplican en vivo para que el operario escuche el
  // efecto antes de cerrar.
  cambiar() {
    const habilitado = this.hasToggleTarget ? this.toggleTarget.checked : true
    const volumen = this.hasSliderTarget ? parseInt(this.sliderTarget.value, 10) : 60
    const variante = this._varianteElegida()
    const motivos = this._motivosElegidos()

    if (this.hasValorTarget) this.valorTarget.textContent = `${volumen}%`

    const audio = this._audioController()
    if (audio) {
      audio.enabledValue = habilitado
      audio.volumenValue = volumen
      if (variante) audio.varianteValue = variante
      if (motivos) audio.porMotivoValue = { ...audio.porMotivoValue, ...motivos }
    }

    this._persistir(habilitado, volumen, variante, motivos)
  }

  // C29-08 · Con qué variante suena cada error con sonido propio. Un select
  // por error; sin selects en el modal, no se manda nada.
  _motivosElegidos() {
    if (!this.hasMotivoTarget) return null
    return Object.fromEntries(this.motivoTargets.map(s => [s.dataset.motivo, s.value]))
  }

  // RP-20: escuchar una opción sin adoptarla, para poder compararlas.
  probarVariante(event) {
    const id = event.currentTarget.dataset.variante
    const audio = this._audioController()
    if (audio && id) audio.probarVariante(id)
  }

  _varianteElegida() {
    const elegido = this.varianteTargets.find(r => r.checked)
    return elegido ? elegido.value : null
  }

  // Botones de prueba: reproducen cada tono para que el operario confirme
  // que se oye. Es también el gesto que desbloquea el AudioContext.
  probar(event) {
    const tono = event.currentTarget.dataset.tono || "success"
    const audio = this._audioController()
    if (audio && typeof audio[tono] === "function") audio[tono]()
  }

  _audioController() {
    const el = document.querySelector('[data-controller~="audio"]')
    if (!el) return null
    return this.application.getControllerForElementAndIdentifier(el, "audio")
  }

  _persistir(habilitado, volumen, variante, motivos) {
    if (!this.hasUrlValue) return

    clearTimeout(this._saveTimeout)
    this._saveTimeout = setTimeout(() => {
      const token = document.querySelector('meta[name="csrf-token"]')?.content
      const cuerpo = { habilitado: habilitado, volumen: volumen }
      if (variante) cuerpo.variante = variante
      if (motivos) cuerpo.motivos = motivos

      fetch(this.urlValue, {
        method: "PATCH",
        headers: { "Content-Type": "application/json", "X-CSRF-Token": token },
        body: JSON.stringify(cuerpo)
      }).catch(e => console.warn("[sonido] no se pudo guardar la preferencia:", e))
    }, 400)
  }
}
