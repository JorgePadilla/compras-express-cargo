import { Controller } from "@hotwired/stimulus"

// Donde se suelta la grabacion de Yusef cuando llegue. Sin archivo, el
// controller usa la voz sintetica y nadie se entera.
const GRABACION_PRE_ALERTA = "/sonidos/pre_alerta.mp3"

export default class extends Controller {
  static values = {
    enabled: { type: Boolean, default: true },
    // PR-9.c: 0-100. Antes estaba fijo en 0.3 y en bodega no se oía.
    volumen: { type: Number, default: 60 }
  }

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

    // PR-9.c — la causa de "no suena en Tegus": Chrome crea el AudioContext
    // en estado `suspended` y no lo libera hasta que hay un gesto del
    // usuario. Antes nunca se llamaba `resume()`, así que en las máquinas
    // donde el contexto se creaba antes del primer clic los tonos salían
    // mudos, y el try/catch de _playTone se tragaba el error sin dejar
    // rastro en consola. Desbloqueamos en el primer gesto real.
    this._unlock = () => this._resumeContext()
    document.addEventListener("pointerdown", this._unlock, { once: true })
    document.addEventListener("keydown", this._unlock, { once: true })
  }

  disconnect() {
    if (this._onVoices && window.speechSynthesis) {
      window.speechSynthesis.removeEventListener("voiceschanged", this._onVoices)
    }
    if (this._unlock) {
      document.removeEventListener("pointerdown", this._unlock)
      document.removeEventListener("keydown", this._unlock)
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
  // PR-C6.38: si existe la grabacion, suena esa; si no, la voz sintetica.
  //
  // Yusef: la voz de pre-alerta del sistema viejo era la de su senora, grabada
  // en 2022-2023, y quedo de mandar grabaciones nuevas. Mientras no lleguen, la
  // sintetica dice "pre alerta" y cumple — pero no hay que tocar codigo el dia
  // que el mande el archivo: se suelta en `public/sonidos/pre_alerta.mp3` y
  // empieza a sonar solo.
  speakPreAlerta() {
    if (!this.enabledValue) return
    this.notify()
    setTimeout(() => this._decirPreAlerta(), 250)
  }

  _decirPreAlerta() {
    if (this._grabacionRota) return this._speak("pre alerta")

    const audio = new Audio(GRABACION_PRE_ALERTA)
    audio.volume = (this.volumenValue || 60) / 100
    audio.play().catch(() => {
      // No esta el archivo (o el navegador lo bloqueo): se cae a la voz
      // sintetica y no se vuelve a intentar, para no pedir un 404 por escaneo.
      this._grabacionRota = true
      this._speak("pre alerta")
    })
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
      const Ctor = window.AudioContext || window.webkitAudioContext
      if (!Ctor) return null
      this._audioContext = new Ctor()
    }
    this._resumeContext()
    return this._audioContext
  }

  _resumeContext() {
    const ctx = this._audioContext
    if (ctx && ctx.state === "suspended") {
      ctx.resume().catch(e => console.warn("[audio] no se pudo reanudar el AudioContext:", e))
    }
  }

  // 0-100 → ganancia. Tope 0.9: por encima el oscilador satura y suena sucio.
  get _gain() {
    const pct = Math.min(100, Math.max(0, this.volumenValue)) / 100
    return Math.max(0.001, pct * 0.9)
  }

  _playTone(frequency, duration, callback) {
    try {
      const ctx = this._getContext()
      if (!ctx) {
        console.warn("[audio] este navegador no soporta Web Audio")
        return
      }
      const oscillator = ctx.createOscillator()
      const gain = ctx.createGain()

      oscillator.connect(gain)
      gain.connect(ctx.destination)

      oscillator.frequency.value = frequency
      // `square` corta el ruido de bodega mucho mejor que `sine`, que a
      // volumen bajo se pierde entre el ruido de fondo (Yusef — Tegus).
      oscillator.type = "square"
      gain.gain.value = this._gain

      oscillator.start(ctx.currentTime)
      gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + duration)
      oscillator.stop(ctx.currentTime + duration)

      if (callback) {
        oscillator.onended = callback
      }
    } catch (e) {
      // Antes esto era un catch mudo: si el audio fallaba, no quedaba ni
      // rastro y era imposible diagnosticar remoto (el caso de Tegus).
      console.warn("[audio] no se pudo reproducir el tono:", e)
    }
  }
}
