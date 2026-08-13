import { Controller } from "@hotwired/stimulus"

// Las cajas de una Entrega Personal, una por una.
//
// A7-20. Jorge había puesto un campo "cantidad de cajas" que generaba N filas
// iguales para corregir. Yusef lo rechazó tres veces, y el motivo no es que las
// cajas no se parezcan — es cómo trabaja el operario:
//
//   > "Ellos agarran la caja, miden, y de ahí se van a la computadora.
//   >  **¿Cuáles cajas eran? ¿Cuáles fueron las que ya metí?**"
//   > "Las entregas personales **nunca, nunca, nunca** son iguales."
//   > "Es **paso por paso**. Es igual el manifiesto de Miami."
//
// Con una plantilla, el que vuelve de medir tiene que adivinar qué fila le
// toca. Acá no: escribe lo que acaba de medir, da Agregar, y la caja baja a la
// lista con su número.
//
// El shape de los inputs es el mismo de siempre —`paquete[cajas][N][campo]`—
// para que `MedidasPorCaja` y `Paquete.crear_split!` sigan funcionando sin
// tocarse. Las filas se renumeran 1..N en cada alta y baja, porque
// `crear_split!` mapea `por_caja[i]` contra `numero_caja: i`.
export default class extends Controller {
  static targets = ["lista", "template", "contador", "vacio", "agregarBtn"]

  // Los campos de captura viven en el partial de arriba, bajo el controller
  // `calc-volumetrico`. Se leen por su target y no por un id para no depender
  // de que la vista los nombre.
  static CAMPOS = ["peso", "alto", "largo", "ancho"]

  connect() {
    this._renumerar()
    this.element.addEventListener("keydown", this._atajo)
  }

  disconnect() {
    this.element.removeEventListener("keydown", this._atajo)
  }

  // F6 = agregar, la misma tecla que usa el editor de pre-alerta para su
  // repetidor. En Miami trabajan con teclado.
  _atajo = (e) => {
    if (e.key !== "F6") return
    e.preventDefault()
    this.agregar()
  }

  agregar() {
    const valores = this._leerCaptura()

    // Sin peso no es una caja: es una fila vacía que después nadie sabe qué
    // era. Se avisa en el campo, no con un alert que tape la pantalla.
    if (!valores.peso) {
      const campo = this._campo("peso")
      if (campo) { campo.focus(); campo.reportValidity?.() }
      return
    }

    const fila = this.templateTarget.content.cloneNode(true).querySelector(".caja-fila")
    fila.dataset.valores = JSON.stringify(valores)
    fila.querySelector("[data-caja-resumen]").textContent = this._resumen(valores)
    this.listaTarget.appendChild(fila)

    this._limpiarCaptura()
    this._renumerar()
  }

  quitar(e) {
    e.currentTarget.closest(".caja-fila")?.remove()
    this._renumerar()
  }

  // Renumera las filas 1..N y reescribe sus inputs ocultos. Se hace entero en
  // cada cambio en vez de parchar índices: es barato (son pocas cajas) y evita
  // que un remove deje huecos que `crear_split!` leería como cajas que no
  // existen.
  _renumerar() {
    const filas = [...this.listaTarget.querySelectorAll(".caja-fila")]

    filas.forEach((fila, i) => {
      const n = i + 1
      fila.querySelector("[data-caja-numero]").textContent = `Caja ${n}`
      fila.querySelectorAll("input[type=hidden]").forEach(input => input.remove())

      const valores = JSON.parse(fila.dataset.valores || "{}")
      Object.entries(valores).forEach(([campo, valor]) => {
        const input = document.createElement("input")
        input.type = "hidden"
        input.name = `paquete[cajas][${n}][${campo}]`
        input.value = valor
        fila.appendChild(input)
      })
    })

    if (this.hasContadorTarget) this.contadorTarget.textContent = String(filas.length)
    if (this.hasVacioTarget) this.vacioTarget.classList.toggle("hidden", filas.length > 0)
  }

  _leerCaptura() {
    return this.constructor.CAMPOS.reduce((acc, campo) => {
      const valor = this._campo(campo)?.value?.trim()
      if (valor) acc[campo] = valor
      return acc
    }, {})
  }

  _limpiarCaptura() {
    this.constructor.CAMPOS.forEach(campo => {
      const input = this._campo(campo)
      if (input) input.value = ""
    })
    this._campo("peso")?.focus()
  }

  _campo(nombre) {
    return this.element.querySelector(`[data-calc-volumetrico-target="${nombre}"]`)
  }

  _resumen({ peso, alto, largo, ancho }) {
    const medidas = [alto, largo, ancho].filter(Boolean)
    const dim = medidas.length === 3 ? ` · ${medidas.join(" × ")} pulg` : ""
    return `${peso} lb${dim}`
  }
}
