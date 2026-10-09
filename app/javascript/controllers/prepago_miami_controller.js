import { Controller } from "@hotwired/stimulus"

// Muestra las formas de pago solo cuando el paquete se pagó en Miami.
//
// La respuesta normal es "se cobra en Honduras", así que tener los tres
// métodos siempre a la vista es ruido en la pantalla que más se usa.
//
// Esto es SOLO lo visual. Lo que protege el dato es la validación del modelo,
// que exige método si hubo prepago y lo prohíbe si no — esconder un radio no
// impide que llegue en el request.
export default class extends Controller {
  static targets = ["metodo", "enHonduras", "opcionDeMetodo"]

  connect() {
    this.alternar()
  }

  alternar() {
    // El target está en el radio de "cobrar en Honduras": si está marcado, no
    // hubo prepago. Sin el target —no debería pasar— se asume que no.
    const prepagado = this.hasEnHondurasTarget ? !this.enHondurasTarget.checked : false
    if (!this.hasMetodoTarget) return

    this.metodoTarget.classList.toggle("hidden", !prepagado)

    if (prepagado) {
      // Que quede uno elegido al abrir, para que no se pueda guardar sin método
      // por simple descuido.
      if (!this.opcionDeMetodoTargets.some(r => r.checked)) {
        this.opcionDeMetodoTargets[0]?.setAttribute("checked", "checked")
        if (this.opcionDeMetodoTargets[0]) this.opcionDeMetodoTargets[0].checked = true
      }
    } else {
      // Al arrepentirse, el form deja de mandar el método. El server igual lo
      // limpia; esto es para que la pantalla no diga una cosa y se guarde otra.
      this.opcionDeMetodoTargets.forEach(r => { r.checked = false })
    }
  }
}
