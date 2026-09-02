import { Controller } from "@hotwired/stimulus"

// C21-04 · El formulario de una casa del manifiesto.
//
// Dos cosas, las dos dichas por Yusef:
//
//   · Elegir un tamaño pre-definido **pre-llena las medidas y manda el cursor
//     al peso** — *"te ponen solo el cursor a peso, porque es lo que le vas a
//     meter a ingresar, que es lo que hace falta"*.
//   · Las medidas **quedan editables**: *"ellos vienen y marcan EH y le
//     modifican una medida, porque la cortan… le decimos «EH cortada»"*. Por eso
//     el tamaño solo escribe los campos, no los bloquea.
//
// El volumen se muestra en vivo con el mismo divisor que usa el servidor
// (`VolumetricoCalculator::DIVISOR_LB`), para que el operario vea el número que
// le va a reportar al proveedor antes de guardar. La cuenta buena la hace el
// modelo: esto es display.
const DIVISOR_LB = 166.0

export default class extends Controller {
  static targets = ["tamano", "alto", "largo", "ancho", "peso", "volumen", "agregar", "agregarEImprimir"]

  // C23-12 · Las teclas de esta pantalla las escucha **este** controller, y no
  // el global.
  //
  // `keyboard_shortcuts_controller` ignora toda tecla que no sea F2 cuando el
  // foco está en un input — y acá el foco vive en **Peso**, porque elegir un
  // tamaño manda el cursor ahí (*"te ponen solo el cursor a peso"*). O sea que
  // la F5 del botón «Agregar caja» **no disparaba nunca en el flujo real**.
  //
  // Y era peor que decorativa: **F5 es «refrescar» del navegador**. El handler
  // global sale antes de llamar a `preventDefault` cuando detecta que estás
  // escribiendo, así que el operario tecleaba el peso, apretaba la tecla que el
  // botón le prometía, y la página se recargaba **borrándole el peso**.
  // Reproducido en Chrome con una tecla de verdad, no simulada.
  //
  // Escucha en `document` y no en el formulario para que las teclas anden
  // también con el foco afuera —que es como andaban antes— y `preventDefault`
  // corre **siempre**, que es lo que le saca el refresh a F5.
  //
  // Los botones llevan `shortcut_label_only`: muestran «(F5)» y «(F9)» pero
  // **no** emiten `data-shortcut`. Si lo emitieran, el controller global les
  // haría click además de esto y se guardarían dos cajas — el mismo doble
  // disparo que ya pasó en `/entrega_personal` con F2 y F9.
  connect() {
    this._recalcular()
    this._teclas = this._teclas.bind(this)
    document.addEventListener("keydown", this._teclas)
  }

  disconnect() {
    document.removeEventListener("keydown", this._teclas)
  }

  _teclas(e) {
    const boton = { F5: this.agregarTarget, F9: this.agregarEImprimirTarget }[e.key]
    if (!boton) return

    e.preventDefault()
    // `requestSubmit(boton)` y no `boton.click()`: el submitter viaja con el
    // envío, y de él salen el `name="print"` de «Agregar e imprimir» y su
    // `data-turbo="false"`. Con un `click()` sintético también viajarían, pero
    // pasar el submitter es decir explícitamente cuál de los dos se apretó.
    boton.form.requestSubmit(boton)
  }

  elegirTamano(e) {
    const { alto, largo, ancho } = e.target.dataset
    // Un tamaño sin medidas es «Especificar»: se mide a mano, así que no se
    // pisa lo que el operario ya tecleó.
    if (alto) this.altoTarget.value = alto
    if (largo) this.largoTarget.value = largo
    if (ancho) this.anchoTarget.value = ancho
    this._recalcular()
    if (this.hasPesoTarget) this.pesoTarget.focus()
  }

  medidaCambiada() {
    this._recalcular()
  }

  _recalcular() {
    if (!this.hasVolumenTarget) return
    const n = (t) => (this[`has${t}Target`] ? parseFloat(this[`${t.toLowerCase()}Target`].value) : NaN)
    const alto = n("Alto"), largo = n("Largo"), ancho = n("Ancho")
    const completo = [alto, largo, ancho].every((v) => v > 0)
    this.volumenTarget.textContent = completo
      ? (alto * largo * ancho / DIVISOR_LB).toFixed(2)
      : "—"
  }
}
