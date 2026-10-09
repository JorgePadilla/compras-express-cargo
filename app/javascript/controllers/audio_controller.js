import { Controller } from "@hotwired/stimulus"

// Donde se suelta la grabacion de Yusef cuando llegue. Sin archivo, el
// controller usa la voz sintetica y nadie se entera.
const GRABACION_PRE_ALERTA = "/sonidos/pre_alerta.mp3"

export default class extends Controller {
  static values = {
    enabled: { type: Boolean, default: true },
    // PR-9.c: 0-100. Antes estaba fijo en 0.3 y en bodega no se oía.
    volumen: { type: Number, default: 60 },
    // RP-20: cuál de las tres opciones de error suena, y cuáles son.
    // `variantes` lo manda el server desde `SonidosDeError`, que es la misma
    // constante con la que se rendearon los .wav que se le mandaron a Yusef.
    // Importmap no tiene build step: si el JS las declarara, serían dos listas
    // distintas y divergirían.
    variante: { type: String, default: "grave" },
    variantes: { type: Array, default: [] },
    // C29-08 · Los errores con sonido propio: `{ tipo_distinto: "triple" }`.
    // Salen de `SonidosDeError::MOTIVOS`, igual que las variantes.
    porMotivo: { type: Object, default: {} },
    repeticiones: { type: Number, default: 2 },
    pausa: { type: Number, default: 150 },
    // PR-C29.9 · La voz del error: `SonidosDeError::VOZ`, por el mismo data
    // attribute que las variantes, para que el navegador y los .wav hagan la
    // misma cuenta.
    voz: { type: Object, default: {} }
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

  // RP-20: toca la variante elegida. Si el server no mandó ninguna —o mandó
  // una que no está— cae en el tono de siempre, así que la pantalla nunca se
  // queda sin sonido de error por un dato mal puesto.
  error() {
    if (!this.enabledValue) return

    const variante = this._varianteActiva()
    if (!variante) return this._playErrorTone(200, 0.3)

    this._tocarSecuencia(variante.tonos)
  }

  // C29-08 · *"Si el tipo de envío es el error, tiene que tirar un sonido de
  // una forma. Si la sucursal es el error… de otro tono."* Cada uno toca la
  // variante que el operario eligió para él, **dos veces**: *"algo como que de
  // verdad te llama"*. Sin variante elegida cae en el error de siempre, que
  // es mejor que el silencio.
  errorTipo() { this._errorDeMotivo("tipo_distinto") }

  errorSucursal() { this._errorDeMotivo("sucursal_distinta") }

  _errorDeMotivo(motivo) {
    if (!this.enabledValue) return

    const id = (this.porMotivoValue || {})[motivo]
    const variante = (this.variantesValue || []).find(v => v.id === id)
    if (!variante) return this.error()

    let tonos = []
    for (let i = 0; i < this.repeticionesValue; i++) {
      if (i > 0) tonos.push({ hz: 0, ms: this.pausaValue })
      tonos = tonos.concat(variante.tonos)
    }
    this._tocarSecuencia(tonos)
  }

  // Turbo avisa cómo terminó el submit. Sin esto un guardado fallido es
  // silencioso, y el operario está mirando la pistola, no la pantalla.
  submitEnd(event) {
    if (event?.detail?.success === false) this.error()
  }

  // Prueba desde el modal de configuración: suena una variante sin cambiar la
  // elegida, para poder compararlas.
  probarVariante(id) {
    if (!this.enabledValue) return
    const variante = (this.variantesValue || []).find(v => v.id === id)
    if (variante) this._tocarSecuencia(variante.tonos)
  }

  _varianteActiva() {
    const todas = this.variantesValue || []
    if (todas.length === 0) return null
    return todas.find(v => v.id === this.varianteValue) || todas[0]
  }

  // Los tonos van uno detrás del otro. `hz: 0` es un silencio: sirve para
  // separar pulsos sin inventar otra clave en la constante de Ruby.
  //
  // Solo la tocan los errores (`error`, `errorTipo`, `errorSucursal` y el
  // «Escuchar» del modal), así que va siempre con la voz del error.
  _tocarSecuencia(tonos, i = 0) {
    if (!tonos || i >= tonos.length) return

    const { hz, ms } = tonos[i]
    const seguir = () => this._tocarSecuencia(tonos, i + 1)

    if (!hz) return setTimeout(seguir, ms)
    this._playErrorTone(hz, ms / 1000, seguir)
  }

  // C28-11 · El consolidado quedó entero: tres tonos que suben. Yusef: *"y
  // aquí es algo donde debería decir… Completado. Completado… sí, el audio"*.
  // Distinto de `success` —un pip por caja— para que se oiga que terminó el
  // grupo, no que entró una caja más.
  completo() {
    if (!this.enabledValue) return
    this._playTone(660, 0.12, () => {
      setTimeout(() => this._playTone(880, 0.12, () => {
        setTimeout(() => this._playTone(1320, 0.25), 90)
      }), 90)
    })
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
  // Es la de los sonidos limpios; el error tiene la suya (`_gainError`).
  get _gain() {
    const pct = Math.min(100, Math.max(0, this.volumenValue)) / 100
    return Math.max(0.001, pct * 0.9)
  }

  // PR-C29.9 · El error, con tope 1.0: lo que pase del techo lo aplasta la
  // curva de saturación, que es justamente lo que se busca.
  get _gainError() {
    const pct = Math.min(100, Math.max(0, this.volumenValue)) / 100
    return Math.max(0.001, pct)
  }

  // Respaldo por si una pantalla montara `audio` sin `atributos_de_audio`.
  // No debería pasar: `sonidos_cableados_test` caza a la que se olvide.
  get _voz() {
    return Object.assign({ segunda: 1.0595, mezcla: 0.6, saturacion: 3.0, ataque_ms: 5, caida_ms: 15 },
                         this.vozValue || {})
  }

  // PR-C29.9 · El tono de error. Jorge, 2026-10-08: *"el audio de error creo
  // que tiene que ser más cruel, fuerte, molesto, intenso"*.
  //
  // El de antes era `_playTone`: una cuadrada sola cuya ganancia empezaba a
  // caer en la primera muestra, así que cada tono era un «tic» que se apagaba
  // antes de sonar. Éste es la `VOZ` de `SonidosDeError`, la misma cuenta que
  // hace `SonidosWav` para los archivos:
  //   · una cuadrada en la nota y una sierra un semitono arriba: el choque es
  //     el zumbido de un buzzer;
  //   · sostenido: sube en `ataque_ms`, se queda arriba, cae en `caida_ms`;
  //   · saturado con la curva `tanh` (`_salidaDeError`), que lo aplasta contra
  //     el techo y lo hace sonar fuerte al mismo volumen.
  _playErrorTone(frequency, duration, callback) {
    try {
      const ctx = this._getContext()
      if (!ctx) {
        console.warn("[audio] este navegador no soporta Web Audio")
        return
      }
      const voz = this._voz
      const inicio = ctx.currentTime
      const fin = inicio + duration
      const arriba = inicio + voz.ataque_ms / 1000

      const envolvente = ctx.createGain()
      envolvente.gain.setValueAtTime(0, inicio)
      envolvente.gain.linearRampToValueAtTime(1, arriba)
      envolvente.gain.setValueAtTime(1, Math.max(arriba, fin - voz.caida_ms / 1000))
      envolvente.gain.linearRampToValueAtTime(0, fin)
      envolvente.connect(this._salidaDeError(ctx))

      const ondas = [ [ "square", frequency ], [ "sawtooth", frequency * voz.segunda ] ].map(([ forma, hz ]) => {
        const oscilador = ctx.createOscillator()
        oscilador.type = forma
        oscilador.frequency.value = hz
        const mezcla = ctx.createGain()
        mezcla.gain.value = voz.mezcla
        oscilador.connect(mezcla)
        mezcla.connect(envolvente)
        return oscilador
      })

      ondas.forEach((o) => { o.start(inicio); o.stop(fin) })
      if (callback) ondas[0].onended = callback
    } catch (e) {
      console.warn("[audio] no se pudo reproducir el tono de error:", e)
    }
  }

  // La saturación y el volumen, armados una vez por contexto. La curva es
  // tanh(k·x)/tanh(k): la misma que `SonidosDeError.saturar` en Ruby. El
  // volumen se relee en cada tono porque el modal de sonidos lo cambia sin
  // recargar.
  _salidaDeError(ctx) {
    if (!this._cadenaError || this._cadenaError.ctx !== ctx) {
      const k = this._voz.saturacion
      const curva = new Float32Array(2048)
      for (let i = 0; i < curva.length; i++) {
        const x = (i * 2) / (curva.length - 1) - 1
        curva[i] = Math.tanh(k * x) / Math.tanh(k)
      }
      const saturacion = ctx.createWaveShaper()
      saturacion.curve = curva
      saturacion.oversample = "none"
      const volumen = ctx.createGain()
      saturacion.connect(volumen)
      volumen.connect(ctx.destination)
      this._cadenaError = { ctx, entrada: saturacion, volumen }
    }
    this._cadenaError.volumen.gain.value = this._gainError
    return this._cadenaError.entrada
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
