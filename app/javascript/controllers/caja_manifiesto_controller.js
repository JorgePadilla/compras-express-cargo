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
  static targets = ["tamano", "alto", "largo", "ancho", "peso", "volumen", "agregar", "agregarEImprimir",
                    "form", "editando", "editandoTexto", "agregarTexto", "agregarEImprimirTexto"]

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
    if (this.hasFormTarget) this._urlDeAgregar = this.formTarget.action
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
    // PR-C30.15 · Tecleando en la tarjeta de detalles abierta en formulario
    // (`data-teclas-alcance`), F5 y F9 no son de las casas: armarían una caja
    // y la ficha se recargaría con lo tecleado en la tarjeta. El controller
    // global la frena ahí (no hay F5 adentro), así que tampoco recarga.
    if (e.target instanceof Element && e.target.closest("[data-teclas-alcance]")) return

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

  // ── C28-05 · Corregir una caja ya armada ─────────────────────────────────
  //
  // El lápiz de la fila trae la caja al formulario de arriba y lo pasa a
  // PATCH. Yusef: *"la vuelvo a seleccionar, me vuelve a aparecer aquí toda la
  // información… le voy a escoger de nuevo la caja, los pesos, las medidas"*.
  // F5 y F9 siguen andando: guardan los cambios en vez de agregar.
  editar(e) {
    const d = e.currentTarget.dataset
    this.formTarget.action = d.url
    this._metodo("patch")
    this._tokenDeLaSesion()

    this.tamanoTargets.forEach((radio) => { radio.checked = radio.value === (d.tamanoId || "") })
    this.altoTarget.value = d.alto || ""
    this.largoTarget.value = d.largo || ""
    this.anchoTarget.value = d.ancho || ""
    this.pesoTarget.value = d.peso || ""
    this._recalcular()

    this.editandoTextoTarget.textContent = `Editando la caja ${d.letra}`
    this.editandoTarget.hidden = false
    this.agregarTextoTarget.textContent = "Guardar cambios"
    this.agregarEImprimirTextoTarget.textContent = "Guardar e imprimir"

    this.formTarget.scrollIntoView({ behavior: "smooth", block: "center" })
    this.pesoTarget.focus()
  }

  cancelarEdicion() {
    this.formTarget.reset()
    this.formTarget.action = this._urlDeAgregar
    this._metodo(null)
    this.editandoTarget.hidden = true
    this.agregarTextoTarget.textContent = "Agregar caja"
    this.agregarEImprimirTextoTarget.textContent = "Agregar e imprimir"
    this._recalcular()
  }

  // C29-06 · **Por qué «Guardar e imprimir» reventaba y «Guardar» no.** El
  // `authenticity_token` que `form_with` pone en el formulario es **por
  // formulario**: Rails lo ata a la acción y al verbo con que se dibujó (POST
  // a `/cajas`, `per_form_csrf_tokens`). Al editar, el formulario pasa a
  // PATCH `/cajas/:id` y ese token deja de valer.
  //
  //   · «Guardar» va por Turbo, que manda además el token **de la sesión** en
  //     el header `X-CSRF-Token`, y ése vale para cualquier acción.
  //   · «Guardar e imprimir» lleva `data-turbo=false` —la 4×6 necesita una
  //     navegación completa para que su `onload` imprima— y el navegador manda
  //     solo el campo del formulario: 422, `InvalidAuthenticityToken`.
  //
  // Yusef: *"hay algo malo en este botón nada más"*. Los tests no lo veían
  // porque el ambiente de test apaga la protección CSRF; `caja_editar_test`
  // la prende para este camino. El arreglo es poner en el campo el token de
  // la sesión (el del `<meta>`), que vale para agregar y para editar.
  _tokenDeLaSesion() {
    const meta = document.querySelector("meta[name='csrf-token']")
    const campo = this.formTarget.querySelector("input[name='authenticity_token']")
    if (meta && campo) campo.value = meta.content
  }

  // El `_method` que Rails lee para tratar el POST como PATCH. Se crea al
  // editar y se quita al volver a agregar.
  _metodo(verbo) {
    let campo = this.formTarget.querySelector("input[name='_method']")
    if (!verbo) {
      campo?.remove()
      return
    }
    if (!campo) {
      campo = document.createElement("input")
      campo.type = "hidden"
      campo.name = "_method"
      this.formTarget.appendChild(campo)
    }
    campo.value = verbo
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
