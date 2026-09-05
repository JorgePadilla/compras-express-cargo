import { Controller } from "@hotwired/stimulus"

// Global keyboard shortcuts handler. Mounted en <body> via
// data-controller="keyboard-shortcuts".
//
// Cualquier elemento con `data-shortcut="F7"` en la página recibe un
// click cuando se presiona la tecla. Funciona con <a>, <button>,
// <input type="submit">.
//
// Convenciones del sistema (alineadas con f2_clear, paquetes_shortcuts,
// pre_alerta_editor, etiquetar):
//   F2  → Cancelar / Limpiar / Volver
//   F4  → Imprimir el documento de esta pantalla
//   F5  → Agregar una línea (la casa del manifiesto)
//   F6  → Editar (entrar a edit)
//   F7  → Nuevo / Crear nuevo recurso
//   F8  → Excel export
//   F9  → Imprimir: el PDF, y también «hacer algo **e imprimir**»
//   F10 → Guardar (submit form)
//   F11 → Finalizar la sesión de /etiquetar (la eligió Yusef, `C22-02`)
//
// La lista se corrigió el 2026-09-05 (`C23-13`) leyendo lo que la app **hace**,
// no lo que decía acá. Tres cosas estaban mal o faltaban:
//
//   · **F9 no es «PDF export»**: es imprimir. Lo usan «Imprimir» de venta,
//     recibo, cotización y nota; el «PDF» de /paquetes; el «Guardar + Imprimir»
//     de /entrega_personal y el «Agregar e imprimir» del manifiesto. Un
//     desarrollador que siguiera el rótulo viejo le pondría otra tecla a un
//     botón de imprimir.
//   · **F5 y F11 no estaban**, y las dos vienen de afuera: F5 es la de «Solo
//     Agregar» del sistema viejo y F11 la que Yusef eligió para finalizar.
//     Ojo con F11: al probarla en Chrome su `keydown` **no llegó a la página**
//     —y `F7`, sin atar a nada, tampoco—, así que la prueba no decide. La de
//     `/etiquetar` se verificó a mano en su día y se queda; **no se le puso a
//     nada nuevo** hasta poder comprobarla.
//   · **F4 y F9 imprimen las dos**, y no es un descuido: F4 saca el documento
//     de la pantalla (el manifiesto, el Warehouse Receipt) y F9 el de la acción
//     que uno acaba de hacer. La ficha del manifiesto tiene las dos.
//
// `test/lint/teclas_por_familia_test.rb` lo traba: una tecla no puede
// significar dos cosas distintas.
//
// Reglas:
// - Si el foco está en un input/textarea editable y la tecla NO es F2,
//   se ignora (evita interferir con la escritura).
// - F2 siempre dispara, aunque esté tipeando (consistente con
//   f2_clear_controller existente).
// - preventDefault para que el browser no abra menús nativos
//   (algunos navegadores usan F-keys para devtools / context menus).
export default class extends Controller {
  connect() {
    this.handler = this.handle.bind(this)
    document.addEventListener("keydown", this.handler)
  }

  disconnect() {
    document.removeEventListener("keydown", this.handler)
  }

  handle(e) {
    if (!/^F\d{1,2}$/.test(e.key)) return

    const target = document.querySelector(`[data-shortcut="${e.key}"]`)
    if (!target) return

    // Si está editando y la tecla NO es F2, no interrumpir.
    if (e.key !== "F2" && this.isEditing(e.target)) return

    e.preventDefault()
    target.click()
  }

  isEditing(el) {
    if (!el) return false
    if (el.isContentEditable) return true
    const tag = el.tagName
    if (tag !== "INPUT" && tag !== "TEXTAREA" && tag !== "SELECT") return false
    if (tag === "INPUT" && [ "checkbox", "radio", "button", "submit" ].includes(el.type)) return false
    return true
  }
}
