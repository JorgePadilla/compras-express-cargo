import { Controller } from "@hotwired/stimulus"

// Avisa cuando el tracking que se está escribiendo ya existe en el sistema.
//
// PR-C6.26. Yusef, probando /pre_alertas/new: "mira, ve, cómo le di enter: ya
// tiene un error y **no lo detecta que ya existe**".
//
// Tenía razón, y el hueco era más grande de lo que parecía: la unicidad de
// tracking está **scopeada a la pre-alerta** (`uniqueness: { scope:
// :pre_alerta_id }`) y `Paquete` no tiene unicidad de tracking en absoluto.
// O sea que el mismo tracking en dos pre-alertas distintas pasa sin chistar, y
// después llegan dos paquetes esperados para un solo bulto.
//
// **Avisa, no bloquea.** Yusef pidió detección, no una regla nueva — y hay
// casos legítimos: un cliente que re-usa un tracking viejo, o un duplicado
// real que se resuelve con sufijo (A, B, C…) en /etiquetar. Decidir es del
// operario; lo que no puede es no enterarse.
//
// Reusa `check_tracking`, el mismo endpoint que la pistola de Miami, así que
// hereda su escalera de búsqueda: exacto, secundario y el código largo de USPS.
export default class extends Controller {
  static targets = [ "aviso", "texto" ]
  // PR-C6.44: `excluirPaqueteId` es el paquete que esta fila ya representa.
  // Cada `PreAlertaPaquete` materializa un Paquete en estado `pre_alerta`, así
  // que sin esto, tocar el tracking de una fila guardada se avisaba **sobre sí
  // misma**. Vale 0 en /etiquetar y en las filas nuevas, y ahí no se manda.
  static values = { url: String, excluirPaqueteId: Number }

  buscar(e) {
    const campo = e.currentTarget
    const tracking = campo.value.trim()

    if (this._timeout) clearTimeout(this._timeout)
    if (tracking.length < 5) return this._ocultar()

    this._timeout = setTimeout(() => this._consultar(tracking, campo), 400)
  }

  _consultar(tracking, campo) {
    const consulta = (this._seq = (this._seq || 0) + 1)

    const params = new URLSearchParams({ tracking })
    if (this.excluirPaqueteIdValue > 0) {
      params.set("excluir_paquete_id", this.excluirPaqueteIdValue)
    }

    fetch(`${this.urlValue}?${params}`, {
      headers: { "Accept": "application/json" }
    })
      .then(r => r.json())
      .then(data => {
        // Misma guarda que en /etiquetar: una respuesta que llega tarde no
        // puede hablar de un tracking que ya no está en el campo.
        if (consulta !== this._seq) return
        if (campo.value.trim() !== tracking) return

        if (data.exists) this._mostrar(tracking, data)
        else this._ocultar()
      })
      .catch(() => this._ocultar())
  }

  _mostrar(tracking, data) {
    if (!this.hasAvisoTarget) return

    if (this.hasTextoTarget) {
      const dueno = data.cliente ? ` de ${data.cliente}` : ""
      this.textoTarget.textContent =
        `${tracking} ya está en el sistema${dueno} — ${data.estado || "sin estado"}.`
    }
    this.avisoTarget.classList.remove("hidden")
  }

  _ocultar() {
    if (this.hasAvisoTarget) this.avisoTarget.classList.add("hidden")
  }
}
