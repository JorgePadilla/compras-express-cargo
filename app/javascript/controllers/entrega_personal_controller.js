import ClienteAutocomplete from "controllers/cliente_autocomplete"
import { conEnterAvanza } from "controllers/enter_avanza"
import { enfocar } from "controllers/enfocar"

// PR-6: flow separado para entrega personal. Versión simplificada del
// etiquetar_controller — no necesita lookup de duplicado de tracking
// (el tracking se genera automático EP-YYYY-SUC-PROV-NNNNNN) ni
// detección de pre-alerta. Reutiliza el patrón de modal cantidad cajas.
export default class extends conEnterAvanza(ClienteAutocomplete) {
  static targets = [
    "form", "clienteInput", "clienteId", "clienteDropdown", "clienteNombre",
    "sucursalBanner", "sucursalTexto", "sucursalDestino", "sucursalFalta",
    "etiquetasModal", "etiquetasInput",
    "event", "panel"
  ]

  connect() {
    // C20-10: `_searchTimeout` era estado muerto — el debounce vive en la base.
    this._handleGlobalKeydown = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this._handleGlobalKeydown)
    // C30-10 · El último **campo** donde se tecleó, para volver ahí al cancelar
    // un modal. No alcanza con `activeElement` al abrirlo: si F9 se apretó con
    // el mouse, en ese momento el foco es el botón.
    // Los de adentro de un modal no cuentan: son la pregunta, no el paquete.
    this._alEnfocarCampo = (e) => {
      const campo = e.target
      if (!campo.matches?.("input:not([type=hidden]), select, textarea")) return
      if (campo.closest("dialog") || !this.formTarget.contains(campo)) return
      this._ultimoCampo = campo
    }
    this.element.addEventListener("focusin", this._alEnfocarCampo)
  }

  disconnect() {
    document.removeEventListener("keydown", this._handleGlobalKeydown)
    this.element.removeEventListener("focusin", this._alEnfocarCampo)
    // La gemela: sin el `super` la búsqueda pendiente sobrevivía a la
    // navegación.
    super.disconnect()
  }

  handleKeydown(e) {
    if (e.key === "F2") {
      e.preventDefault()
      this.clearForm()
    } else if (e.key === "F9") {
      e.preventDefault()
      // C19-08, la gemela: mientras haya una pregunta abierta (la listita de
      // retener, la de política — cualquier <dialog>), F9 no guarda. Se
      // contesta con un Enter y se sigue; F2 queda libre.
      if (document.querySelector("dialog[open]")) return
      this.submitFormWithPrint()
    }
  }

  // Lo único que Entrega Personal hace de más al elegir un cliente: jalar sus
  // tareas y notas a la franja de la derecha (PR-9.b). El resto —búsqueda de
  // un dígito, preselección, flechas y Enter— es igual que en /etiquetar y
  // vive en `ClienteAutocomplete`.
  // C16-04: elegir el cliente con el teclado avanza de campo, igual que en
  // /etiquetar. El resto de la navegación por Enter viene del mixin.
  _despuesDeElegirConTeclado(e) {
    this._focusSiguiente(e.target)
  }

  _alSeleccionarCliente({ id, sucursalRetiro, sinSucursalRetiro }) {
    // El mixin siempre mandó la sucursal de retiro; esta pantalla la tiraba, y
    // por eso nunca avisaba a dónde iba la caja. Yusef: "también misma
    // situación no avisa que va a tegus".
    this._mostrarSucursal(sucursalRetiro, sinSucursalRetiro === "true")
    this.loadPanel(id)
  }

  // Mismo aviso que /etiquetar, mismo motivo: decide en qué bolsa física cae la
  // caja, y enterarse tarde significa volver a abrirla (PR-C6.24).
  // C29-03 · Y la misma gemela del cliente sin sucursal: el aviso dice que
  // falta, en vez de esconderse (antes caía a la ciudad).
  _mostrarSucursal(sucursal, sinSucursal = false) {
    if (!this.hasSucursalBannerTarget) return

    const texto = (sucursal || "").trim()
    this.sucursalBannerTarget.classList.toggle("hidden", texto === "" && !sinSucursal)
    if (texto !== "" && this.hasSucursalTextoTarget) {
      this.sucursalTextoTarget.textContent = texto
    }
    if (this.hasSucursalDestinoTarget) this.sucursalDestinoTarget.hidden = sinSucursal
    if (this.hasSucursalFaltaTarget) this.sucursalFaltaTarget.hidden = !sinSucursal
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
// PR-C6.31 sacó de acá un modal "¿cuántas cajas?" que preguntaba lo MISMO que
// el campo visible del formulario —y peor: lo reseteaba a 1 antes de
// preguntar—. Ese modal estaba mal, y sigue estándolo.
//
// C20-07 trae el de /etiquetar (PR-C7.23), que es otra cosa: solo aparece
// cuando NO se midió ninguna caja, así que nunca compite con las filas. Y acá
// hacía más falta que allá, porque en Entrega Personal casi nunca se mide: sin
// esto, un envío de tres bultos no tenía forma de pedir tres etiquetas. Jorge:
// "esta lógica de las cajas que hicimos para etiquetar también hay que
// aplicarla en entrega personal".
submitFormWithPrint() {
  // C30-03, la gemela de /etiquetar: el contenido vacío se avisa antes de
  // preguntar cuántas etiquetas, no después de contestarlo.
  if (!this.formTarget.reportValidity()) return
  if (this._cajasCargadas() > 0) return this._submitWithPrint()
  if (!this.hasEtiquetasModalTarget) return this._submitWithPrint()

  if (this.hasEtiquetasInputTarget) this.etiquetasInputTarget.value = "1"
  this.dispatch("modalAbierto")
  this.etiquetasModalTarget.showModal()
  // `select()` y no solo `focus()`: el operario teclea el número encima sin
  // tener que borrar el 1.
  if (this.hasEtiquetasInputTarget) this.etiquetasInputTarget.select()
}

  // Cuántas filas de caja hay cargadas. Se cuentan las filas —la misma fuente
  // que usa el repetidor—, más la que se esté tecleando arriba sin haberle
  // dado «Agregar», que es lo que la pantalla misma dice que se puede hacer
  // (C18-05).
  _cajasCargadas() {
    const filas = this.formTarget.querySelectorAll(".caja-fila").length
    const captura = this.formTarget.querySelector("[data-caja-campo='peso']")
    return filas + (captura && captura.value.trim() !== "" ? 1 : 0)
  }

  // Enter confirma; Escape cancela. Acá Enter SÍ actúa, al revés que en el
  // formulario —donde la pistola dispara Enter y por eso pasa al campo
  // siguiente—: el modal no es el formulario y el operario ya decidió imprimir.
  etiquetasKeydown(e) {
    if (e.key === "Enter") {
      e.preventDefault()
      this.confirmarEtiquetas()
    } else if (e.key === "Escape") {
      e.preventDefault()
      this.cerrarEtiquetas()
    }
  }

  confirmarEtiquetas() {
    const cantidad = this._etiquetasPedidas()
    if (cantidad === null) return

    this.etiquetasModalTarget.close()
    this._submitWithPrint(cantidad)
  }

  // C30-10 · Cancelar vuelve al campo donde estaba el operario —el último
  // donde tecleó, sea que apretó F9 o el botón—, o al primero de la pantalla. Con `enfocar` y no
  // con `focus()`: cerrar el modal con el **mouse** o el dedo deja al campo con
  // cara de enfocado y sordo al teclado; el navegador ya le devolvió el foco y
  // un `focus()` encima no hace nada (`controllers/enfocar`). Con Enter o
  // Escape no se notaba, y por eso ningún test lo veía.
  //
  // Esta pantalla no tiene pistola —el tracking EP lo genera el sistema—, así
  // que «el campo que sigue» es donde el operario estaba tecleando.
  cerrarEtiquetas() {
    this.etiquetasModalTarget.close()
    enfocar(this._campoDeVuelta())
  }

  _campoDeVuelta() {
    const ultimo = this._ultimoCampo
    if (ultimo && ultimo.isConnected && this.formTarget.contains(ultimo)) return ultimo
    return this.formTarget.querySelector("[autofocus]")
  }

  // Un número mal tecleado no puede grabar 500 paquetes ni tirar 500
  // etiquetas: el server tiene el mismo tope, esto es para avisar antes.
  _etiquetasPedidas() {
    const n = parseInt(this.etiquetasInputTarget.value, 10)
    if (!Number.isInteger(n) || n < 1 || n > 99) {
      this.etiquetasInputTarget.select()
      return null
    }
    return n
  }

  _submitWithPrint(etiquetas = null) {
    this._removePrintField()
    const input = document.createElement("input")
    input.type = "hidden"
    input.name = "print"
    input.value = "true"
    input.dataset.printField = "true"
    this.formTarget.appendChild(input)

    // Suelto y NO como `paquete[cantidad_paquetes]`: el bug de PR-C6.31 fue
    // tener dos campos con el mismo `name`.
    if (etiquetas) {
      const cuantas = document.createElement("input")
      cuantas.type = "hidden"
      cuantas.name = "etiquetas"
      cuantas.value = String(etiquetas)
      cuantas.dataset.printField = "true"
      this.formTarget.appendChild(cuantas)
    }

    this.formTarget.requestSubmit()
  }

  // `querySelectorAll` y no `querySelector`: desde que el modal agrega también
  // la cantidad son dos. Con el singular, el segundo sobrevivía al guardado y
  // el paquete siguiente heredaba la cantidad del anterior — el bug de
  // PR-C6.31, que en /etiquetar ya se pagó una vez.
  _removePrintField() {
    this.formTarget.querySelectorAll("[data-print-field]").forEach(el => el.remove())
  }

  clearForm() {
    // C20-10, la gemela: sin esto F2 dejaba viva la búsqueda y el dropdown
    // repintaba sobre el formulario limpio.
    this.cerrar()
    this.formTarget.reset()
    // Las cajas cargadas son de ESTE paquete: se van con él. `reset()` no las
    // toca porque viven en inputs hidden que el repetidor arma a mano.
    this.formTarget.dispatchEvent(new CustomEvent("cajas:limpiar", { bubbles: true }))
    if (this.hasClienteIdTarget) this.clienteIdTarget.value = ""
    if (this.hasClienteNombreTarget) {
      this.clienteNombreTarget.textContent = ""
      this.clienteNombreTarget.classList.add("hidden")
    }
    // PR-9.b: la franja vuelve a su estado vacío junto con el formulario.
    this.loadPanel(null)

    // C19-02: acá no se enfocaba nada y el cursor quedaba "como en el aire".
    // Vuelve al mismo campo que arranca la pantalla (el [autofocus], hoy el
    // proveedor), para encadenar el siguiente paquete sin agarrar el mouse.
    // C30-10 · `enfocar`: esto corre después de cerrar el modal de cuántas
    // etiquetas, y el `focus()` a secas podía dejar el campo sordo.
    enfocar(this.formTarget.querySelector("[autofocus]"))
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
      //
      // Y despues el Warehouse Receipt, que es uno solo para todo el envio.
      // Yusef: "la etiqueta es la que le pegamos a cada caja, pero pido tres;
      // el warehouse receipt es al reves: solo imprimis uno, donde detalla todo
      // lo que recibiste". Iba como preview y lo cambió probándolo (C19-01):
      // ahora imprime de un solo y la pestaña se cierra, como la etiqueta; el
      // preview queda en el botón «Ver WR» de la ficha y el link del flash.
      //
      // `wr=1` y **una sola ventana**: esto eran dos `window.open` seguidas y
      // Chrome bloqueaba la segunda —un gesto del usuario da permiso para un
      // popup, no para dos—. Yusef veia salir la etiqueta y nada mas. Ahora la
      // ventana de la etiqueta, al terminar de imprimir, se va al Warehouse
      // Receipt en vez de cerrarse (ver `layouts/etiqueta.html.erb`).
      window.open(`/paquetes/${el.dataset.paqueteId}/etiqueta?hermanas=1&print=true&wr=1`, "_blank")
      // C19-02: la pestaña de impresión se lleva el foco de la ventana; cuando
      // el WR se cierra y la ventana vuelve, de regreso al primer campo — el
      // mismo viaje que hace /etiquetar con el tracking. El guard de
      // isConnected es por si Turbo reemplazó la página en el medio.
      window.addEventListener("focus", () => {
        if (!this.element.isConnected) return
        enfocar(this.formTarget.querySelector("[autofocus]"))
      }, { once: true })
    }
    setTimeout(() => this.clearForm(), 100)
    el.remove()
  }
}
