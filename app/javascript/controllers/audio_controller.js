import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { enabled: { type: Boolean, default: true } }

  connect() {
    this._audioContext = null
    // Las voces de speechSynthesis cargan async; las cacheamos y nos
    // re-suscribimos cuando el navegador las publica.
    this._voices = []
    this._loadVoices()
    if (typeof window !== "undefined" && window.speechSynthesis) {
      this._onVoices = () => this._loadVoices()
      window.speechSynthesis.addEventListener("voiceschanged", this._onVoices)
    }
  }

  disconnect() {
    if (this._onVoices && window.speechSynthesis) {
      window.speechSynthesis.removeEventListener("voiceschanged", this._onVoices)
    }
  }

  success() {
    if (!this.enabledValue) return
    this._playTone(800, 0.15)
  }

  error() {
    if (!this.enabledValue) return
    this._playTone(200, 0.3)
  }

  alert() {
    if (!this.enabledValue) return
    this._playTone(600, 0.15, () => {
      setTimeout(() => this._playTone(900, 0.15), 180)
    })
  }

  // Two-chime ascending fifth (880Hz → 1320Hz) — distinto del alert/error/success.
  // Yusef quiere un sonido distintivo cuando el tracking matchea con pre-alerta.
  notify() {
    if (!this.enabledValue) return
    this._playTone(880, 0.12, () => {
      setTimeout(() => this._playTone(1320, 0.18), 120)
    })
  }

  // Match con pre-alerta: chime corto de atención + voz femenina (colombiana
  // si está instalada) diciendo "pre alerta". Si TTS no está disponible, el
  // chime ya sonó (degradación elegante).
  speakPreAlerta() {
    if (!this.enabledValue) return
    this.notify()
    setTimeout(() => this._speak("pre alerta"), 250)
  }

  _speak(text) {
    try {
      const synth = window.speechSynthesis
      if (!synth) return
      const utter = new SpeechSynthesisUtterance(text)
      utter.lang = "es-CO"
      utter.rate = 1.0
      utter.pitch = 1.05
      const voice = this._pickVozEs(synth)
      if (voice) utter.voice = voice
      synth.cancel() // evitar cola si se escanea rápido
      synth.speak(utter)
    } catch (e) {
      // Silently fail si TTS no está disponible
    }
  }

  _loadVoices() {
    try {
      if (window.speechSynthesis) {
        this._voices = window.speechSynthesis.getVoices() || []
      }
    } catch (e) {
      this._voices = []
    }
  }

  // Prioridad: (1) voz es-CO; (2) español con nombre femenino conocido;
  // (3) cualquier español; (4) null → default del navegador.
  _pickVozEs(synth) {
    const voices = (this._voices && this._voices.length ? this._voices : synth.getVoices()) || []
    const es = voices.filter(v => (v.lang || "").toLowerCase().startsWith("es"))
    if (es.length === 0) return null

    const colombiana = es.find(v => (v.lang || "").toLowerCase() === "es-co")
    if (colombiana) return colombiana

    const femeninas = /m[oó]nica|paulina|paola|sabina|marisol|luciana|google espa[nñ]ol|female|mujer/i
    const femenina = es.find(v => femeninas.test(v.name || ""))
    if (femenina) return femenina

    return es[0]
  }

  _getContext() {
    if (!this._audioContext) {
      this._audioContext = new (window.AudioContext || window.webkitAudioContext)()
    }
    return this._audioContext
  }

  _playTone(frequency, duration, callback) {
    try {
      const ctx = this._getContext()
      const oscillator = ctx.createOscillator()
      const gain = ctx.createGain()

      oscillator.connect(gain)
      gain.connect(ctx.destination)

      oscillator.frequency.value = frequency
      oscillator.type = "sine"
      gain.gain.value = 0.3

      oscillator.start(ctx.currentTime)
      gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + duration)
      oscillator.stop(ctx.currentTime + duration)

      if (callback) {
        oscillator.onended = callback
      }
    } catch (e) {
      // Silently fail if audio is not available
    }
  }
}
