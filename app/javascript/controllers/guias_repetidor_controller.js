import { Controller } from "@hotwired/stimulus"

// C21-11 · Los números de guía del proveedor, uno por renglón.
//
// Yusef: *"el número de guía termina siendo varios"*, con la forma de nuestros
// splits — `286441-1`, `-2`, `-3`: *"es el mismo número, solo tiene el 1, el 2 y
// el 3. Es el mismo que nosotros, la misma teoría"*.
//
// Antes eran **tres renglones vacíos fijos**, con el argumento de que
// "alcanzan para el caso normal y no obligan a nadie a pelear con un botón de
// «agregar»". El problema es el otro lado: con cuatro guías había que guardar,
// volver a entrar y llenar la cuarta, y las tres casillas vacías ocupaban la
// pantalla siempre. Jorge, 2026-08-30: *"veo que hay 3 guías por defecto, esto
// debería ser un poco más dinámico"*.
//
// La fila sale del mismo partial que el `<template>` (`guias_aduana/_guia_fila`),
// no de un string acá: un template escrito a mano se desincroniza de la fila —
// la lección de `PR-C6.44`.
export default class extends Controller {
  static targets = ["lista", "template"]

  agregar() {
    const html = this.templateTarget.innerHTML.replace(/NEW_INDEX/g, this._indice())
    this.listaTarget.insertAdjacentHTML("beforeend", html)
    this.listaTarget.querySelector(".guia-fila:last-child input[type=text]")?.focus()
  }

  // Quitar una fila **no** la borra del DOM cuando ya existe en la base: marca
  // `_destroy` y la esconde. Si se borrara, Rails no se enteraría de que hay que
  // eliminarla y la guía volvería al recargar.
  quitar(e) {
    const fila = e.target.closest(".guia-fila")
    if (!fila) return

    const destruir = fila.querySelector("[data-guias-repetidor-target='destruir']")
    const id = fila.querySelector("input[name*='[id]']")
    if (destruir && id?.value) {
      destruir.value = "1"
      fila.classList.add("hidden")
    } else {
      fila.remove()
    }
  }

  // Un índice que no choque con los que ya están.
  _indice() {
    return Date.now().toString()
  }
}
