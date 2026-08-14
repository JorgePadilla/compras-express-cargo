import ClienteAutocomplete from "controllers/cliente_autocomplete"

// PR-6: flow separado para entrega personal. Versión simplificada del
// etiquetar_controller — no necesita lookup de duplicado de tracking
// (el tracking se genera automático EP-YYYY-SUC-PROV-NNNNNN) ni
// detección de pre-alerta. Reutiliza el patrón de modal cantidad cajas.
export default class extends ClienteAutocomplete {
  static targets = [
    "form", "clienteInput", "clienteId", "clienteDropdown", "clienteNombre",
    "event", "panel"
  ]

  connect() {
    this._searchTimeout = null
    this._handleGlobalKeydown = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this._handleGlobalKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this._handleGlobalKeydown)
    if (this._searchTimeout) clearTimeout(this._searchTimeout)
  }

  handleKeydown(e) {
    if (e.key === "F2") {
      e.preventDefault()
      this.clearForm()
    } else if (e.key === "F9") {
      e.preventDefault()
      this.submitFormWithPrint()
    }
  }

  // Lo único que Entrega Personal hace de más al elegir un cliente: jalar sus
  // tareas y notas a la franja de la derecha (PR-9.b). El resto —búsqueda de
  // un dígito, preselección, flechas y Enter— es igual que en /etiquetar y
  // vive en `ClienteAutocomplete`.
  _alSeleccionarCliente({ id }) {
    this.loadPanel(id)
  }

  // PR-C6.41: acá el tipo de envío es un select y puede cambiar después de
  // elegir al cliente, así que el panel de cálculo tiene que enterarse. En
  // /etiquetar no hace falta: el servicio es de la sesión y no se mueve.
  cambioTipoEnvio(e) {
    const calc = this.element.querySelector("[data-controller~='calc-volumetrico']")
    if (!calc) return

    calc.dataset.calcVolumetricoTipoEnvioIdValue = parseInt(e.target.value, 10) || 0
  }

  // Recarga el turbo-frame de la franja. Sin tracking que pasar: en entrega
  // personal el tracking lo genera el sistema al guardar (EP-AÑO-SUC-PROV-N).
  loadPanel(clienteId) {
    if (!this.hasPanelTarget) return

    const frame = this.panelTarget.querySelector("turbo-frame#panel_contexto")
    if (!frame) return

    const base = this.panelTarget.dataset.panelUrl
    const url = clienteId ? `${base}?cliente_id=${encodeURIComponent(clienteId)}` : base
    if (frame.getAttribute("src") !== url) frame.setAttribute("src", url)
  }


  // Submit + modal de cajas (mismo patrón de PR-4 etiquetar).
// PR-C6.31: F9 guarda e imprime, y nada mas.
//
// Antes abria un modal "cuantas cajas?" que preguntaba lo MISMO que el campo
// visible "Cant. Cajas" del formulario — y peor: lo reseteaba a 1 antes de
// preguntar, asi que pisaba lo que el operario acababa de escribir. Es el
// mismo modal que se saco de /etiquetar cuando Jorge dijo que "el F9 era
// como confuso".
submitFormWithPrint() {
  this._submitWithPrint()
}

  _submitWithPrint() {
    this._removePrintField()
    const input = document.createElement("input")
    input.type = "hidden"
    input.name = "print"
    input.value = "true"
    input.dataset.printField = "true"
    this.formTarget.appendChild(input)
    this.formTarget.requestSubmit()
  }

  _removePrintField() {
    const existing = this.formTarget.querySelector("[data-print-field]")
    if (existing) existing.remove()
  }

  clearForm() {
    this.formTarget.reset()
    if (this.hasClienteIdTarget) this.clienteIdTarget.value = ""
    if (this.hasClienteNombreTarget) {
      this.clienteNombreTarget.textContent = ""
      this.clienteNombreTarget.classList.add("hidden")
    }
    // PR-9.b: la franja vuelve a su estado vacío junto con el formulario.
    this.loadPanel(null)
  }

  // Handle turbo stream events después del save.
  eventTargetConnected(el) {
    if (el.dataset.action !== "paquete-saved") return
    this.dispatch("success")
    if (el.dataset.print === "true") {
      // PR-10.d: la ETIQUETA (Dymo 2.25x1.25), no el Warehouse Receipt.
      // Yusef: "aqui esta tirando el warehouse, no la etiqueta".
      // `hermanas=1` saca una por caja cuando el tracking se dividio.
      //
      // PR-C7.16: el controller marca `data-print` solo en la primera caja, asi
      // que esto corre una vez por tracking y no una por caja.
      window.open(`/paquetes/${el.dataset.paqueteId}/etiqueta?hermanas=1&print=true`, "_blank")

      // Y despues el Warehouse Receipt, que es uno solo para todo el envio.
      // Yusef: "la etiqueta es la que le pegamos a cada caja, pero pido tres;
      // el warehouse receipt es al reves: solo imprimis uno, donde detalla todo
      // lo que recibiste". Va como preview (sin `print`): el operario decide si
      // lo imprime o se lo manda al cliente.
      window.open(`/paquetes/${el.dataset.paqueteId}/warehouse_receipt`, "_blank")
    }
    setTimeout(() => this.clearForm(), 100)
    el.remove()
  }
}
