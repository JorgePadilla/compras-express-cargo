// Lo que un `<dialog>` hace solo, para los modales hechos con un `div`.
//
// PR-A11Y.7. Buscar paquetes (portal) y mover paquete (admin) abren un `div`
// con `role="dialog"`: el foco se quedaba en la página de atrás, Tab paseaba
// por los links tapados, Escape no cerraba, y al cerrar el foco caía en el
// `<body>`. Pasarlos a `<dialog>` toca su JS de punta a punta; esto les da lo
// mismo con dos llamadas.
//
//   const modal = abrirModalDeDiv(elemento, { alCerrar: () => this.close(), foco })
//   ...
//   modal.cerrar()   // devuelve el foco al que lo abrió
const ENFOCABLES = "a[href], button:not([disabled]), input:not([disabled]):not([type=hidden]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex='-1'])"

export function abrirModalDeDiv(elemento, { alCerrar, foco } = {}) {
  const previo = document.activeElement

  const visibles = () => Array.from(elemento.querySelectorAll(ENFOCABLES))
    .filter(el => el.offsetParent !== null)

  const alTeclear = (e) => {
    if (e.key === "Escape") {
      e.preventDefault()
      alCerrar?.()
    } else if (e.key === "Tab") {
      const lista = visibles()
      if (lista.length === 0) return
      const primero = lista[0]
      const ultimo = lista[lista.length - 1]
      if (e.shiftKey && document.activeElement === primero) {
        e.preventDefault()
        ultimo.focus()
      } else if (!e.shiftKey && (document.activeElement === ultimo || !elemento.contains(document.activeElement))) {
        e.preventDefault()
        primero.focus()
      }
    }
  }
  document.addEventListener("keydown", alTeclear)

  setTimeout(() => (foco || visibles()[0])?.focus(), 0)

  return {
    cerrar() {
      document.removeEventListener("keydown", alTeclear)
      if (previo?.isConnected) previo.focus()
    }
  }
}
