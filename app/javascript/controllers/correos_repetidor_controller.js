import { Controller } from "@hotwired/stimulus"

// Los correos de aviso de un cliente, uno por renglón.
//
// Yusef, 2026-08-19, sobre una clienta con dos correos a la que no le podían
// crear cuenta: *"que tenga opción para varios correos y que tenga la opción de
// qué correo va a usar para manejar su cuenta"*. Y sobre cuántos: *"números a
// segundo, números a tercero… ya no es problema"*.
//
// La fila sale del mismo partial que el `<template>` (`clientes/_correo_fila`),
// no de un string acá: un template escrito a mano se desincroniza de la fila y
// cada una nueva sale distinta — la lección de `PR-C6.44`.
export default class extends Controller {
  static targets = ["lista", "template"]

  agregar() {
    const html = this.templateTarget.innerHTML.replace(/NEW_INDEX/g, this._indice())
    this.listaTarget.insertAdjacentHTML("beforeend", html)
    this.listaTarget.querySelector(".correo-fila:last-child input[type=email]")?.focus()
  }

  // Quitar una fila **no** la borra del DOM cuando ya existe en la base: marca
  // `_destroy` y la esconde. Si se borrara, Rails no se enteraría de que hay que
  // eliminarla y el correo volvería al recargar.
  quitar(e) {
    const fila = e.target.closest(".correo-fila")
    if (!fila) return

    const destruir = fila.querySelector("[data-correos-repetidor-target='destruir']")
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
