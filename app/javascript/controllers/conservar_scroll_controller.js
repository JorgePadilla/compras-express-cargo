import { Controller } from "@hotwired/stimulus"

// C31-16 · Yusef, en la hoja de preparación: *"le doy guardar, porque se
// vuelve para arriba… tengo que venir y volver a bajar"*.
//
// Un formulario que vuelve a la misma pantalla (guardar con la hoja a medias,
// «Ver manifiestos», cambiar la hora en lote) termina en una visita de Turbo
// que cambia el `<body>` entero. El que scrollea en este layout no es la
// ventana sino el `<main>` (`overflow-x-hidden` le prende el scroll vertical),
// así que el `<main>` nuevo arranca arriba — y `turbo-refresh-scroll` no
// alcanza: ese solo cuida el scroll de la ventana.
//
// Se monta en un contenedor de la pantalla: al mandar cualquier formulario de
// adentro anota dónde estaba el `<main>`, y al volver a montarse —ya en la
// pantalla nueva— lo deja ahí. Si el formulario llevó a **otra** pantalla
// (guardar y entrar a auditar), lo anotado se borra: volver a la hoja más
// tarde arranca arriba, como siempre.
const CLAVE = "cec:conservar-scroll:"
const VIGENCIA_MS = 10000

export default class extends Controller {
  connect() {
    const anotado = this._leer()
    if (anotado === null) return
    this._contenedor().scrollTop = anotado
  }

  // `turbo:submit-start`
  anotar() {
    this._escribir({ y: this._contenedor().scrollTop, t: Date.now() })
  }

  // `turbo:submit-end`: si la respuesta fue a otra dirección, lo anotado no
  // sirve.
  terminar(e) {
    const destino = e.detail?.fetchResponse?.location
    if (destino && destino.pathname !== window.location.pathname) this._escribir(null)
  }

  _contenedor() {
    return this.element.closest("main") || document.scrollingElement
  }

  _clave() {
    return CLAVE + window.location.pathname
  }

  // `sessionStorage` puede no estar (ventana privada, sitio bloqueado): sin
  // él la pantalla anda igual, solo que vuelve arriba.
  _leer() {
    try {
      const crudo = sessionStorage.getItem(this._clave())
      sessionStorage.removeItem(this._clave())
      const anotado = crudo && JSON.parse(crudo)
      if (!anotado || Date.now() - anotado.t > VIGENCIA_MS) return null
      return anotado.y
    } catch {
      return null
    }
  }

  _escribir(valor) {
    try {
      if (valor === null) sessionStorage.removeItem(this._clave())
      else sessionStorage.setItem(this._clave(), JSON.stringify(valor))
    } catch {
      // sin sessionStorage, vuelve arriba como antes
    }
  }
}
