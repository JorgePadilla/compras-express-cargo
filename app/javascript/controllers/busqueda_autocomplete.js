import { Controller } from "@hotwired/stimulus"

// Buscar algo tecleando y elegirlo con el teclado. Base compartida por TODOS
// los autocompletes del sistema: cliente, tercero, proveedor, manifiesto,
// pre-alerta.
//
// PR-C6.33. No es un controller registrado — el archivo no termina en
// `_controller`, así que `eagerLoadControllersFrom` lo ignora. Es la clase de
// la que heredan los demás.
//
// **Por qué existe.** Había ocho copias de esta misma interacción, y cada una
// se había arreglado por separado o no se había arreglado nunca:
//
//   · las ocho pedían **2 caracteres** para buscar
//   · solo dos preseleccionaban el primer resultado
//   · solo cuatro respondían a las flechas
//
// Jorge, después de ver la tercera divergencia en un día: "esta búsqueda de
// cliente se puede hacer un solo componente para que tenga las mismas
// funcionalidades? Porque al final él va a querer la misma funcionalidad en
// todo".
//
// **Cómo se extiende.** Los nombres de los targets cambian de pantalla en
// pantalla (`clienteId`, `terceroId`, `hiddenId`…), así que en vez de forzar
// un renombre en diez vistas, el que hereda declara sus accesores. Lo único
// obligatorio es decir de dónde salen el campo, la lista y el campo oculto.
export default class BusquedaAutocomplete extends Controller {
  // ── Lo que cada pantalla define ──────────────────────────────────────────
  //
  // Se sobreescriben con los targets propios. Ej:
  //   get _campo()  { return this.inputTarget }
  //   get _oculto() { return this.terceroIdTarget }
  get _campo() { return this.inputTarget }
  get _lista() { return this.dropdownTarget }
  get _oculto() { return null }
  get _etiqueta() { return null }
  get _url() { return this.urlValue }

  // El HTML de una fila. Recibe el ítem crudo del JSON y su índice.
  // `data-index` y el `data-action` los agrega la base — acá va solo el
  // contenido y los `data-*` que el select necesite.
  _filaHtml(_item) { return "" }

  // Qué hacer cuando el operario elige uno. Recibe el `dataset` del botón.
  _alSeleccionar(_datos) {}

  // Qué hacer cuando llegaron resultados y el primero ya quedó activo. La base
  // no hace nada; el autocomplete de cliente pita (C16-02). No corre con la
  // lista vacía: «no se encontraron resultados» no es un «podés seguir».
  _alPintar(_items) {}

  // Qué hacer después de elegir un ítem **con Enter**. Recibe el keydown. La
  // base no hace nada; las pantallas de escaneo avanzan de campo (C16-04). Con
  // Tab no hace falta: el navegador ya mueve el foco solo.
  _despuesDeElegirConTeclado(_e) {}

  _textoVacio() { return "No se encontraron resultados" }

  // Los modales pintan sus resultados en un `<ul>`, así que cada fila va
  // envuelta en un `<li>`. El resto usa `<div>` y no envuelve nada.
  get _envoltorio() { return null }

  // ── Comportamiento compartido ────────────────────────────────────────────

  // Cuánto se espera antes de salir a buscar. Es un getter y no una constante
  // para que un autocomplete con un endpoint caro pueda darse más aire sin
  // tocar a los otros siete.
  //
  // C20-10: baja de 300 a 120. Los 300 eran casi la mitad de la queja de Jorge
  // —*"el dropdown tarda mucho"*—, y agrupar el tecleo sigue funcionando: 120ms
  // es más de lo que tarda una tecla y menos de lo que el operario espera.
  get _esperaMs() { return 120 }

  // Cuánto aguanta un Enter anotado antes de rendirse. Si la respuesta nunca
  // llega, el operario no puede quedarse con el foco congelado en el campo: se
  // degrada a lo de antes (avanzar sin elegir) en vez de trabarse.
  get _pacienciaMs() { return 1200 }

  buscar() {
    if (this._timeout) clearTimeout(this._timeout)

    const query = this._campo.value.trim()
    if (!this._alcanzaParaBuscar(query)) {
      this.cerrar()
      return
    }

    // C20-10: cada búsqueda lleva número. Es el mismo guard que `checkTracking`
    // usa desde `PR-C6.21` —y que este archivo nunca recibió—: sin él, dos
    // consultas en vuelo se pisan y **la vieja pinta encima de la nueva**.
    // Siguió tecleando: el Enter que estaba anotado hablaba de otra búsqueda.
    this._olvidarPendiente()

    const consulta = (this._seq = (this._seq || 0) + 1)
    this._enVuelo = query

    this._timeout = setTimeout(() => {
      fetch(`${this._url}?q=${encodeURIComponent(query)}`, {
        headers: { "Accept": "application/json" }
      })
        .then(r => r.json())
        .then(items => {
          // Llegó tarde: ya salió otra consulta.
          if (consulta !== this._seq) return
          // O habla de un valor que el operario ya cambió. Las dos guardas son
          // las mismas de `checkTracking`, por el mismo motivo.
          if (this._campo.value.trim() !== query) return

          this._enVuelo = null
          this.pintar(items)
        })
        .catch(() => { if (consulta === this._seq) this.cerrar() })
    }, this._esperaMs)
  }

  // ¿Alcanza lo tecleado para buscar?
  //
  // PR-C6.16. Había un mínimo de 2 caracteres, y eso bloqueaba justo la forma
  // en que Miami trabaja. Yusef:
  //
  //   > "Solo le ponían el dos, ponele que el mío es el seis, solo poníamos el
  //   >  seis o el dos y ya con eso cae."
  //
  // Un dígito suelto es una búsqueda legítima —`2` cae en `CEC-002`, que el
  // backend ya pone primero (PR-C6.14b)— pero una letra suelta no: buscar "a"
  // devolvería la lista entera y el dropdown sería ruido.
  _alcanzaParaBuscar(query) {
    if (query.length >= 2) return true

    return /^\d$/.test(query)
  }

  pintar(items) {
    const env = this._envoltorio
    const envolver = (html) => (env ? `<${env}>${html}</${env}>` : html)
    // C20-10: ¿había un Enter esperando esta lista?
    const pendiente = this._cobrarPendiente()

    if (!items || items.length === 0) {
      if (pendiente) {
        // Sin resultados no hay a quién elegir. Se hace lo mismo que con la
        // lista abierta diciendo «no se encontraron»: no se elige nada y el
        // foco avanza. Y no se pinta: el foco ya se va, quedaría guindada.
        this.cerrar()
        this._despuesDeElegirConTeclado(pendiente.evento)
        return
      }
      this._lista.innerHTML = envolver(
        `<div class="px-4 py-3 text-sm text-gray-500 italic">${this._textoVacio()}</div>`
      )
      this._listaDe = this._campo.value.trim()
      this.abrir()
      return
    }

    // `this.identifier` y no un nombre fijo: el mismo markup lo usan varios
    // controllers con identificadores distintos.
    const id = this.identifier

    this._lista.innerHTML = items.map((item, i) => `
      <button type="button"
        class="w-full text-left px-4 py-2 hover:bg-gray-100 dark:hover:bg-gray-700 flex items-center justify-between"
        data-action="click->${id}#elegir mousemove->${id}#sobrevolar"
        data-index="${i}"
        ${this._filaHtml(item)}
      </button>
    `).join("")

    // C20-10: de qué valor del campo es esta lista. Lo que se pintó para «6»
    // no puede elegir por el operario cuando el campo ya dice «63».
    this._listaDe = this._campo.value.trim()

    this.abrir()
    // El primero queda activo para confirmarlo con Enter sin tocar el mouse:
    // Miami trabaja solo con teclado, "usamos las manos para trabajar".
    this._activo = 0
    // Con un Enter esperando, la lista se cierra en este mismo tick: hacer
    // scroll hacia una fila que va a desaparecer es puro salto visual.
    this._resaltar({ scroll: !pendiente })
    this._alPintar(items)

    if (!pendiente) return

    // Se cobra el Enter que llegó antes que la lista: EL PRIMERO, que es
    // exactamente el que habría elegido de haber esperado. Y el foco avanza
    // acá, que es lo que no pudo hacer cuando se lo quitamos al mixin.
    this._elegirEl(this._items()[0])
    this._despuesDeElegirConTeclado(pendiente.evento)
  }

  // ── Navegación con teclado ───────────────────────────────────────────────

  _items() { return Array.from(this._lista.querySelectorAll("[data-index]")) }

  _resaltar({ scroll = true } = {}) {
    this._items().forEach((el, i) => {
      const activo = i === this._activo
      el.classList.toggle("bg-cec-teal/10", activo)
      if (activo && scroll) el.scrollIntoView({ block: "nearest" })
    })
  }

  _mover(delta) {
    const items = this._items()
    if (items.length === 0) return

    this._activo = Math.max(0, Math.min(items.length - 1, this._activo + delta))
    this._resaltar()
  }

  sobrevolar(e) {
    const idx = parseInt(e.currentTarget.dataset.index, 10)
    if (Number.isFinite(idx) && idx !== this._activo) {
      this._activo = idx
      this._resaltar()
    }
  }

  // ¿La lista que está en pantalla habla del valor que el campo tiene AHORA?
  //
  // C20-10. Antes alcanzaba con que no estuviera oculta, y por eso el campo
  // podía decir «63» mientras la lista seguía siendo la de «6»: Enter elegía
  // CEC-006 en silencio. Es el «queda seleccionado porque se hizo muy rápido»
  // de la nota de audio.
  _listaAlDia() {
    return !this._lista.classList.contains("hidden") &&
           this._listaDe === this._campo.value.trim()
  }

  teclado(e) {
    if (!this._listaAlDia()) return this._tecladoSinLista(e)

    if (e.key === "ArrowDown") {
      e.preventDefault()
      this._mover(1)
    } else if (e.key === "ArrowUp") {
      e.preventDefault()
      this._mover(-1)
    } else if (e.key === "Enter") {
      const activo = this._items()[this._activo]
      if (activo) {
        e.preventDefault() // no enviar el form: solo elegir
        this._elegirEl(activo)
        this._despuesDeElegirConTeclado(e)
      } else {
        // La lista abierta que dice «no se encontraron» no tiene qué elegir, y
        // el Enter sigue de largo hacia quien avance el foco. Se cierra ACÁ: si
        // no, el foco se va y la lista queda guindada sin nadie que la pueda
        // cerrar, porque Escape y Tab viven en el keydown de este campo.
        this.cerrar()
      }
    } else if (e.key === "Escape") {
      e.preventDefault()
      this.cerrar()
    } else if (e.key === "Tab") {
      // C16-04 · Yusef: "nosotros presionamos entre Tab y Enter: es la misma
      // cosa para nosotros". Tab cerraba la lista **sin elegir**, así que el
      // que tabulaba perdía el cliente que ya tenía resaltado. Ahora elige el
      // activo y deja pasar el Tab, que mueve el foco solo. Shift+Tab (volver
      // atrás) no elige nada.
      const activo = this._items()[this._activo]
      if (activo && !e.shiftKey) {
        this._elegirEl(activo)
      } else {
        this.cerrar()
      }
    }
  }

  // Lo que pasa cuando el operario le gana al dropdown.
  //
  // C20-10. Antes acá había un `return` seco: el Enter salía sin
  // `preventDefault`, se lo quedaba el mixin que avanza de campo, y el paquete
  // se iba a guardar **sin cliente** mientras el dropdown se abría solo dos
  // décimas después. Jorge: *"es más rápido que el dropdown, y encima el
  // dropdown se queda guindado"*.
  //
  // Ahora el Enter se **anota** y se cobra cuando la lista llegue. La regla es
  // la misma que ya rige con la lista abierta —elegir el primero—, solo que
  // deja de depender de quién fue más rápido.
  _tecladoSinLista(e) {
    if (e.key === "Escape" || e.key === "Tab") {
      // Se fue del campo a propósito: lo que venga en camino ya no es suyo.
      // Sin `preventDefault`, que Tab tiene que seguir moviendo el foco.
      this.cerrar()
      return
    }
    if (e.key !== "Enter") return
    // Nada en vuelo (campo vacío, o lo tecleado no alcanza para buscar): el
    // Enter es del formulario, como siempre.
    if (!this._enVuelo) return

    // Se le quita el Enter a quien avanza el foco: avanzar ahora dejaría el
    // cliente vacío. El avance lo hace `_despuesDeElegirConTeclado` cuando
    // esto se resuelva.
    e.preventDefault()
    this._pendiente = {
      valor: this._campo.value.trim(),
      evento: e,
      reloj: setTimeout(() => {
        const p = this._pendiente
        this.cerrar()
        // La respuesta no llegó: se hace lo de antes —avanzar sin elegir— en
        // vez de dejar al operario con el foco trabado.
        if (p) this._despuesDeElegirConTeclado(p.evento)
      }, this._pacienciaMs)
    }
  }

  _cobrarPendiente() {
    const p = this._pendiente
    if (!p) return null

    this._pendiente = null
    clearTimeout(p.reloj)
    // Si el campo cambió, ese Enter ya no habla de esta lista. (`buscar()`
    // normalmente ya lo olvidó; esto es el cinturón.)
    return p.valor === this._campo.value.trim() ? p : null
  }

  _olvidarPendiente() {
    if (!this._pendiente) return

    clearTimeout(this._pendiente.reloj)
    this._pendiente = null
  }

  elegir(e) { this._elegirEl(e.currentTarget) }

  _elegirEl(btn) {
    const datos = btn.dataset

    if (this._oculto) this._oculto.value = datos.id
    if (datos.codigo !== undefined) this._campo.value = datos.codigo

    const etiqueta = this._etiqueta
    if (etiqueta) {
      etiqueta.textContent = `${datos.nombre || ""}${datos.categoria ? ` — ${datos.categoria}` : ""}`
      etiqueta.classList.remove("hidden")
    }

    this._alSeleccionar(datos)
    this.cerrar()
  }

  // Al cerrarla se olvida cuál estaba activo: si no, el próximo Enter sobre
  // una lista recién abierta tomaría el índice de la búsqueda anterior.
  //
  // C20-10: y se cancela lo que venía en camino. `cerrar()` ya era el punto
  // por donde pasan TODAS las salidas —elegir, Escape, Tab, el click afuera,
  // la query que se quedó corta—, así que centralizar acá el cancel hace que
  // ninguna deje una búsqueda viva que después pinte sola.
  //
  // Se parte en dos porque hay quien no oculta nada: los modales pintan en un
  // `<ul>` que vive dentro de un `<dialog>` y solo limpian el resaltado. Antes
  // sobreescribían `cerrar()` entero y por eso se quedaban sin el cancel.
  cerrar() {
    this._ocultarLista()
    this._activo = -1
    this._listaDe = null
    this._cancelarBusqueda()
  }

  _ocultarLista() { this._lista.classList.add("hidden") }

  _cancelarBusqueda() {
    if (this._timeout) { clearTimeout(this._timeout); this._timeout = null }
    // Bumpear el número invalida lo que ya salió: cuando vuelva, se descarta.
    this._seq = (this._seq || 0) + 1
    this._enVuelo = null
    this._olvidarPendiente()
  }

  abrir() { this._lista.classList.remove("hidden") }

  clickAfuera(e) {
    if (!this._lista.contains(e.target) && e.target !== this._campo) this.cerrar()
  }

  disconnect() {
    this._cancelarBusqueda()
  }
}
