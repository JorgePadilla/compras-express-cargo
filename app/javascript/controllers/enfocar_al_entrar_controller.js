import { Controller } from "@hotwired/stimulus"
import { enfocar } from "controllers/enfocar"

// Lleva el foco al elemento apenas se pinta la página: el que buscó cae en
// lo que buscó. Jorge, 2026-10-24, en el historial de manifiestos: *"ocultar
// o minimizar los filtros una vez que presionamos buscar y mover el focus a
// los resultados"*.
//
// El elemento necesita `tabindex="-1"` si no es enfocable de por sí. Con un
// heading, el lector de pantalla lee «Resultados · N manifiestos» y el que
// usa teclado sigue con Tab desde ahí, no desde el principio de la página.
// Se monta solo cuando hubo búsqueda; en la primera entrada el foco se queda
// donde lo deja el navegador.
export default class extends Controller {
  connect() {
    enfocar(this.element)
    this.element.scrollIntoView({ block: "start" })
  }
}
