import { Controller } from "@hotwired/stimulus"

// Peso y medidas de cada caja cuando un tracking se divide en varias.
//
// PR-C6.18b. Yusef lo pidió señalando el formulario: "acá sería cantidad de
// paquetes o productos, y aquí **el peso de cada quien**. Como le importa que
// son dos, te da esa opción para dos".
//
// La primera versión (PR-C6.17) puso esto adentro del modal de F9, porque ahí
// era donde se preguntaba la cantidad. Jorge lo probó y fue directo al punto:
// **"el F9 era como confuso"** — el campo visible del formulario decía "Cant.
// Productos" y parecía el que mandaba, mientras el que de verdad manda estaba
// escondido detrás de una tecla.
//
// Ahora la cantidad de cajas vive en el formulario, al lado de los productos,
// y las filas aparecen ahí mismo. F9 vuelve a ser solo "guardar e imprimir".
//
// Vive en su propio controller y no dentro de `etiquetar` porque el partial
// `shared/_peso_medidas_calc` se usa en dos lados: `/etiquetar` y
// `/entrega_personal`. Los dos crean splits.
export default class extends Controller {
  static targets = ["cantidad", "detalle", "filas", "peso", "alto", "largo", "ancho"]

  connect() {
    this.pintar()
  }

  // Se dispara con `input` y no con `change` para que las filas aparezcan
  // mientras teclea, no al salir del campo.
  pintar() {
    if (!this.hasFilasTarget || !this.hasDetalleTarget) return

    const n = this._cantidad()
    if (n < 2) {
      this.detalleTarget.classList.add("hidden")
      this.filasTarget.innerHTML = ""
      return
    }

    const base = this._medidasBase()
    const filas = []
    for (let i = 1; i <= n; i++) {
      filas.push(`
        <div class="grid grid-cols-[3rem_1fr_1fr_1fr_1fr] gap-1.5 items-center">
          <span class="text-xs font-mono font-bold text-cec-navy dark:text-cec-gold">${i}/${n}</span>
          ${this._input(i, "peso", "peso", base.peso)}
          ${this._input(i, "alto", "alto", base.alto)}
          ${this._input(i, "largo", "largo", base.largo)}
          ${this._input(i, "ancho", "ancho", base.ancho)}
        </div>
      `)
    }
    this.filasTarget.innerHTML = filas.join("")
    this.detalleTarget.classList.remove("hidden")
  }

  _input(indice, campo, placeholder, valor) {
    return `<input type="number" step="0.01" min="0"
                   name="paquete[cajas][${indice}][${campo}]"
                   value="${valor}"
                   placeholder="${placeholder}"
                   class="block w-full rounded border-gray-300 dark:border-gray-600 dark:bg-gray-700
                          dark:text-gray-100 text-xs px-1.5 py-1 focus:ring-cec-teal focus:border-cec-teal">`
  }

  // Las filas nacen con lo que ya escribió arriba: si las cajas son parecidas
  // basta con Enter, y solo se tocan las que difieren.
  _medidasBase() {
    const leer = (nombre) => {
      const t = `${nombre}Target`
      return this[`has${nombre.charAt(0).toUpperCase()}${nombre.slice(1)}Target`] ? this[t].value : ""
    }
    return { peso: leer("peso"), alto: leer("alto"), largo: leer("largo"), ancho: leer("ancho") }
  }

  _cantidad() {
    const raw = this.hasCantidadTarget ? parseInt(this.cantidadTarget.value, 10) : 1
    // 26 es el techo del sufijo A-Z que usa el split de trackings duplicados.
    return Number.isFinite(raw) ? Math.max(1, Math.min(26, raw)) : 1
  }
}
