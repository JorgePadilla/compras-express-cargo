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

  // Los campos de la caja que se está midiendo.
  //
  // PR-C7.19: entró `cantidad_productos`, y con él se rompió el atajo que
  // usaba este controller. Antes buscaba los inputs por el target de **otro**
  // controller (`data-calc-volumetrico-target`), lo cual funcionaba solo porque
  // los cuatro campos eran justo los del cálculo. Los productos no pesan y no
  // entran en el cálculo, así que seguir por ahí obligaba a inventarle un
  // target falso.
  //
  // Ahora los cinco llevan `data-caja-campo` y este controller busca por eso:
  // deja de depender de cómo el calculador nombra sus cosas.
  static CAMPOS = ["peso", "alto", "largo", "ancho", "cantidad_productos"]

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

    // PR-C7.17: avisar que las cajas cambiaron.
    //
    // El panel de cálculo leía solo los campos de captura, que `_limpiarCaptura`
    // vacía justo acá — así que con dos cajas cargadas mostraba el peso de una y
    // el cobro se desplomaba al mínimo de servicio. Jorge: *"el cálculo no está
    // haciendo la suma de las 2 cajas tampoco"*.
    //
    // Se emite un evento en vez de llamar al otro controller: los dos viven en
    // el mismo elemento, pero acoplarlos por nombre haría que este dejara de
    // funcionar solo.
    this.dispatch("cambio", { detail: { cajas: filas.length } })
  }

  // Lo que se cargó, para quien necesite el total del envío.
  get cajas() {
    return [...this.listaTarget.querySelectorAll(".caja-fila")]
      .map(fila => JSON.parse(fila.dataset.valores || "{}"))
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
    return this.element.querySelector(`[data-caja-campo="${nombre}"]`)
  }

  _resumen({ peso, alto, largo, ancho, cantidad_productos }) {
    const medidas = [alto, largo, ancho].filter(Boolean)
    const dim = medidas.length === 3 ? ` · ${medidas.join(" × ")} pulg` : ""
    // Los productos van en el resumen porque son de la caja: si no se ven en la
    // fila, el operario no tiene forma de saber cuál puso en cuál.
    const prods = cantidad_productos ? ` · ${cantidad_productos} producto${cantidad_productos === "1" ? "" : "s"}` : ""
    return `${peso} lb${dim}${prods}`
  }
}
