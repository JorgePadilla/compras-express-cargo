import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { enabled: { type: Boolean, default: true } }

  connect() {
    this._audioContext = null
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
