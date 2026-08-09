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

  _textoVacio() { return "No se encontraron resultados" }

  // ── Comportamiento compartido ────────────────────────────────────────────

  buscar() {
    if (this._timeout) clearTimeout(this._timeout)

    const query = this._campo.value.trim()
    if (!this._alcanzaParaBuscar(query)) {
      this.cerrar()
      return
    }

    this._timeout = setTimeout(() => {
      fetch(`${this._url}?q=${encodeURIComponent(query)}`, {
        headers: { "Accept": "application/json" }
      })
        .then(r => r.json())
        .then(items => this.pintar(items))
        .catch(() => this.cerrar())
    }, 300)
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
    if (!items || items.length === 0) {
      this._lista.innerHTML = `<div class="px-4 py-3 text-sm text-gray-500">${this._textoVacio()}</div>`
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

    this.abrir()
    // El primero queda activo para confirmarlo con Enter sin tocar el mouse:
    // Miami trabaja solo con teclado, "usamos las manos para trabajar".
    this._activo = 0
    this._resaltar()
  }

  // ── Navegación con teclado ───────────────────────────────────────────────

  _items() { return Array.from(this._lista.querySelectorAll("[data-index]")) }

  _resaltar() {
    this._items().forEach((el, i) => {
      const activo = i === this._activo
      el.classList.toggle("bg-cec-teal/10", activo)
      if (activo) el.scrollIntoView({ block: "nearest" })
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

  teclado(e) {
    if (this._lista.classList.contains("hidden")) return

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
      }
    } else if (e.key === "Escape") {
      e.preventDefault()
      this.cerrar()
    } else if (e.key === "Tab") {
      this.cerrar()
    }
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
  cerrar() {
    this._lista.classList.add("hidden")
    this._activo = -1
  }

  abrir() { this._lista.classList.remove("hidden") }

  clickAfuera(e) {
    if (!this._lista.contains(e.target) && e.target !== this._campo) this.cerrar()
  }

  disconnect() {
    if (this._timeout) clearTimeout(this._timeout)
  }
}
