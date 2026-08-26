// Enter avanza al siguiente campo. Nunca envía el formulario.
//
// Yusef, 2026-08-08: "el enter es como el siguiente campo". Y sobre los
// dropdowns: "grabar, no grabar — **seleccionar**".
//
// No es una preferencia: **la pistola de código de barras dispara Enter** al
// terminar de leer, y eso no es configurable en la práctica — hay varias
// pistolas, con cable y sin, y todas vienen así. Miami trabaja solo con
// teclado: "nosotros solo teclado porque usamos las manos para trabajar".
//
// Sin este handler gana el default del navegador y Enter envía el form, que
// es de donde salían los paquetes grabados a medias apenas se escaneaba el
// tracking (PR-C6.3).
//
// Vivía adentro de `etiquetar_controller.js`. C16-04 (2026-08-25) lo sacó a un
// mixin porque /entrega_personal —la gemela— no lo tenía: ahí Enter seguía
// enviando el formulario, y al hacer que elegir un cliente con el teclado
// avance de campo, EP habría quedado con Tab avanzando y Enter no. Yusef,
// Conversación 4: "esto es en Etiquetar y en Entrega Personal".
//
// Se usa como `class extends conEnterAvanza(ClienteAutocomplete)`. Necesita
// `formTarget` en el controller que lo mezcla.
export function conEnterAvanza(Base) {
  return class extends Base {
    formKeydown(e) {
      if (e.key !== "Enter") return

      // El dropdown de cliente y el modal de cajas ya resolvieron su Enter
      // (seleccionar el ítem activo / confirmar). No pisarlos.
      if (e.defaultPrevented) return

      const el = e.target
      if (!el || !el.tagName) return

      // La descripción y las notas son textarea: ahí Enter es un salto de línea.
      if (el.tagName === "TEXTAREA") return

      // En un botón, Enter es "apretarlo". Dejarlo pasar.
      if (el.tagName === "BUTTON" || el.type === "submit" || el.type === "button") return

      // Todo lo demás: avanzar, jamás enviar.
      e.preventDefault()
      this._focusSiguiente(el)
    }

    // Los campos que se pueden enfocar, en el orden en que están en el DOM.
    // Se recalcula en cada Enter a propósito: F3 y F4 muestran y esconden
    // campos, así que una lista cacheada quedaría desactualizada.
    _camposEnfocables() {
      const selector = [
        "input:not([type=hidden])",
        "select",
        "textarea"
      ].join(", ")

      return Array.from(this.formTarget.querySelectorAll(selector)).filter((el) => {
        if (el.disabled || el.readOnly) return false
        if (el.tabIndex < 0) return false
        // `offsetParent` es null cuando el campo o alguno de sus contenedores
        // está oculto — que es como viven el tercero (F4) y el tracking
        // secundario (F3) hasta que alguien los revela.
        return el.offsetParent !== null
      })
    }

    _focusSiguiente(actual) {
      const campos = this._camposEnfocables()
      const i = campos.indexOf(actual)
      if (i === -1) return

      const siguiente = campos[i + 1]
      if (!siguiente) return   // en el último campo, Enter no hace nada

      siguiente.focus()
      if (siguiente.select) siguiente.select()
    }
  }
}
