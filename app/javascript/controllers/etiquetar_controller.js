import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "form", "tipoEnvio", "tracking",
    "trackingSecundario", "trackingSecundarioContainer",
    "trackingSecundarioToggle", "trackingSecundarioToggleLabel",
    "clienteInput", "clienteId", "clienteDropdown",
    "clienteNombre", "clienteLockHint", "notasBanner", "notasTexto",
    "preAlertaBanner", "preAlertaNumero", "preAlertaCliente", "preAlertaDescripcion",
    "duplicateModal", "duplicateInfo", "duplicateNewBtn", "duplicateNewHint",
    "cajasModal", "cajasInput", "cantidadPaquetesHidden",
    "submitBtn", "event"
  ]
  static values = {
    checkUrl: String,
    buscarUrl: String
  }

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
    } else if (e.key === "F3") {
      // F3 = revelar / esconder tracking secundario (solo ~40% lo usa,
      // por eso lo dejamos detrás de un atajo en vez de visible siempre).
      // Antes era TAB pero rompía la navegación natural del form.
      e.preventDefault()
      this.toggleTrackingSecundario()
    } else if (e.key === "F8") {
      e.preventDefault()
      this.submitForm()
    } else if (e.key === "F9") {
      e.preventDefault()
      this.submitFormWithPrint()
    }
  }

  toggleTrackingSecundario() {
    if (!this.hasTrackingSecundarioContainerTarget) return
    const container = this.trackingSecundarioContainerTarget
    if (container.classList.contains("hidden")) {
      this._showTrackingSecundario()
      if (this.hasTrackingSecundarioTarget) this.trackingSecundarioTarget.focus()
    } else {
      this._hideTrackingSecundario()
    }
  }

  _showTrackingSecundario() {
    this.trackingSecundarioContainerTarget.classList.remove("hidden")
    if (this.hasTrackingSecundarioToggleLabelTarget) {
      this.trackingSecundarioToggleLabelTarget.textContent = "− Quitar tracking secundario"
    }
  }

  _hideTrackingSecundario() {
    this.trackingSecundarioContainerTarget.classList.add("hidden")
    if (this.hasTrackingSecundarioTarget) this.trackingSecundarioTarget.value = ""
    if (this.hasTrackingSecundarioToggleLabelTarget) {
      this.trackingSecundarioToggleLabelTarget.textContent = "+ Agregar tracking secundario"
    }
  }

  // Client autocomplete
  searchCliente() {
    if (this._searchTimeout) clearTimeout(this._searchTimeout)

    const query = this.clienteInputTarget.value.trim()
    if (query.length < 2) {
      this.hideDropdown()
      return
    }

    this._searchTimeout = setTimeout(() => {
      fetch(`${this.buscarUrlValue}?q=${encodeURIComponent(query)}`, {
        headers: { "Accept": "application/json" }
      })
        .then(r => r.json())
        .then(clientes => this.renderDropdown(clientes))
        .catch(() => this.hideDropdown())
    }, 300)
  }

  renderDropdown(clientes) {
    if (clientes.length === 0) {
      this.clienteDropdownTarget.innerHTML = `
        <div class="px-4 py-3 text-sm text-gray-500">No se encontraron clientes</div>
      `
      this.showDropdown()
      return
    }

    this.clienteDropdownTarget.innerHTML = clientes.map(c => `
      <button type="button"
        class="w-full text-left px-4 py-2 hover:bg-gray-100 flex items-center justify-between"
        data-action="click->etiquetar#selectCliente"
        data-id="${c.id}"
        data-codigo="${c.codigo}"
        data-nombre="${c.nombre}"
        data-notas="${c.notas_miami || ''}"
        data-categoria="${c.categoria_precio || ''}">
        <div>
          <span class="font-mono text-sm font-medium text-cec-navy">${c.codigo}</span>
          <span class="ml-2 text-sm text-gray-700">${c.nombre}</span>
        </div>
        ${c.categoria_precio ? `<span class="text-xs text-gray-500">${c.categoria_precio}</span>` : ''}
      </button>
    `).join("")
    this.showDropdown()
  }

  selectCliente(e) {
    const btn = e.currentTarget
    const id = btn.dataset.id
    const codigo = btn.dataset.codigo
    const nombre = btn.dataset.nombre
    const notas = btn.dataset.notas
    const categoria = btn.dataset.categoria

    this.clienteIdTarget.value = id
    this.clienteInputTarget.value = codigo
    this.clienteNombreTarget.textContent = `${nombre}${categoria ? ` — ${categoria}` : ''}`
    this.clienteNombreTarget.classList.remove("hidden")

    if (notas && notas.trim() !== "") {
      this.notasTextoTarget.textContent = notas
      this.notasBannerTarget.classList.remove("hidden")
      // Trigger audio alert for client notes
      this.dispatch("clienteNotas")
    } else {
      this.notasBannerTarget.classList.add("hidden")
    }

    this.hideDropdown()
  }

  hideDropdown() {
    this.clienteDropdownTarget.classList.add("hidden")
  }

  showDropdown() {
    this.clienteDropdownTarget.classList.remove("hidden")
  }

  clickOutsideDropdown(e) {
    if (!this.clienteDropdownTarget.contains(e.target) && e.target !== this.clienteInputTarget) {
      this.hideDropdown()
    }
  }

  // Duplicate tracking detection
  checkTracking() {
    const tracking = this.trackingTarget.value.trim()
    if (tracking.length < 5) return

    fetch(`${this.checkUrlValue}?tracking=${encodeURIComponent(tracking)}`, {
      headers: { "Accept": "application/json" }
    })
      .then(r => r.json())
      .then(data => {
        // PR-2: si el tracking tiene pre-alerta, sonido distintivo + banner verde.
        // No abrimos el modal de duplicado en ese caso — la pre-alerta NO es un
        // duplicado, es un "paquete esperado" que el sistema reconciliará al guardar.
        if (data.pre_alerta_match) {
          this._showPreAlertaBanner(data)
          this.dispatch("preAlertaMatch")
          return
        }
        if (data.exists && !data.terminal) {
          this._openDuplicateModal(data)
        }
      })
      .catch(() => {})
  }

  _showPreAlertaBanner(data) {
    if (!this.hasPreAlertaBannerTarget) return
    if (this.hasPreAlertaNumeroTarget) this.preAlertaNumeroTarget.textContent = data.pre_alerta_numero || ""
    if (this.hasPreAlertaClienteTarget) this.preAlertaClienteTarget.textContent = data.pre_alerta_cliente || ""
    if (this.hasPreAlertaDescripcionTarget) this.preAlertaDescripcionTarget.textContent = data.pre_alerta_descripcion || ""
    this.preAlertaBannerTarget.classList.remove("hidden")

    // Auto-fill + lock cliente cuando el JSON trae los campos. Yusef pidió
    // que NO se permita cambiar el cliente cuando viene de pre-alerta —
    // evita errores de tipear código equivocado.
    if (data.cliente_id) this._fillAndLockClienteFromPreAlerta(data)
  }

  _hidePreAlertaBanner() {
    if (!this.hasPreAlertaBannerTarget) return
    this.preAlertaBannerTarget.classList.add("hidden")
  }

  _fillAndLockClienteFromPreAlerta(data) {
    if (this.hasClienteIdTarget) this.clienteIdTarget.value = data.cliente_id
    if (this.hasClienteInputTarget) {
      // Mostrar "CEC-006 — Maria Lopez" todo en el mismo input cuando hay lock —
      // Jorge pidió que código y nombre vayan juntos en vez de separados.
      const codigo = data.cliente_codigo || ""
      const nombre = data.cliente_nombre || ""
      this.clienteInputTarget.value = nombre ? `${codigo} — ${nombre}` : codigo
      this.clienteInputTarget.setAttribute("readonly", "readonly")
      this.clienteInputTarget.setAttribute("tabindex", "-1")
      this.clienteInputTarget.classList.add(
        "bg-cec-teal/5", "dark:bg-cec-teal/15", "cursor-not-allowed",
        "ring-1", "ring-cec-teal/40"
      )
    }
    // El `<p>` separado de nombre completo deja de tener sentido cuando el
    // código+nombre ya están juntos en el input. Lo escondemos.
    if (this.hasClienteNombreTarget) {
      this.clienteNombreTarget.textContent = ""
      this.clienteNombreTarget.classList.add("hidden")
    }
    if (this.hasClienteLockHintTarget) {
      this.clienteLockHintTarget.classList.remove("hidden")
    }
    this.hideDropdown()

    // Si el cliente tiene notas Miami, mostrar banner + sonido alerta —
    // misma lógica que selectCliente() para mantener consistencia.
    const notas = (data.cliente_notas_miami || "").trim()
    if (notas !== "") {
      if (this.hasNotasTextoTarget) this.notasTextoTarget.textContent = notas
      if (this.hasNotasBannerTarget) this.notasBannerTarget.classList.remove("hidden")
      this.dispatch("clienteNotas")
    }
  }

  _unlockCliente() {
    if (this.hasClienteInputTarget) {
      this.clienteInputTarget.removeAttribute("readonly")
      this.clienteInputTarget.removeAttribute("tabindex")
      this.clienteInputTarget.classList.remove(
        "bg-cec-teal/5", "dark:bg-cec-teal/15", "cursor-not-allowed",
        "ring-1", "ring-cec-teal/40"
      )
    }
    if (this.hasClienteLockHintTarget) {
      this.clienteLockHintTarget.classList.add("hidden")
    }
  }

  _openDuplicateModal(data) {
    // Render info section.
    const info = this.duplicateInfoTarget
    info.textContent = ""
    const lines = [
      { text: "Este tracking ya está registrado en el sistema:", cls: "font-medium text-gray-800 dark:text-gray-100 mb-2" },
      { text: `Tracking: ${data.tracking_base || ""}`, cls: "mt-1 font-mono text-sm" },
      { text: `Cliente: ${data.cliente}`, cls: "" },
      { text: `Estado: ${data.estado} — Fecha: ${data.fecha}`, cls: "" },
      { text: `${data.count} paquete(s) con este tracking base`, cls: "text-xs text-gray-500 dark:text-gray-400 mt-1" }
    ]
    lines.forEach(({ text, cls }) => {
      const p = document.createElement("p")
      p.textContent = text
      if (cls) p.className = cls
      info.appendChild(p)
    })

    // Configure "Es duplicado real" button: requires next_suffix; if exhausted (Z),
    // disable + explain that needs manual intervention.
    this._duplicateData = data
    if (this.hasDuplicateNewBtnTarget) {
      if (data.next_suffix && data.next_tracking) {
        this.duplicateNewBtnTarget.disabled = false
        if (this.hasDuplicateNewHintTarget) {
          this.duplicateNewHintTarget.textContent =
            `Crea paquete nuevo con tracking ${data.next_tracking} (sufijo ${data.next_suffix}).`
        }
      } else {
        this.duplicateNewBtnTarget.disabled = true
        if (this.hasDuplicateNewHintTarget) {
          this.duplicateNewHintTarget.textContent =
            "Sufijos A-Z agotados. Pedí intervención manual del supervisor."
        }
      }
    }

    this.duplicateModalTarget.classList.remove("hidden")
  }

  closeDuplicate() {
    this.duplicateModalTarget.classList.add("hidden")
    this._duplicateData = null
  }

  // Opción 1: "Es actualización" — navega al edit del paquete original.
  // El digitador ajusta lo que ocupe en el form de edit estándar.
  duplicateAsUpdate() {
    const data = this._duplicateData
    if (!data || !data.edit_url) return
    window.location.href = data.edit_url
  }

  // PR-5: Opción 2 — "Cambio de Servicio". Navega al show del paquete
  // original con ?mode=edit&cambio_servicio=1 (no usamos edit_url porque
  // edit_paquete_path redirige sin preservar query params). El banner amber
  // se muestra y el flag solicito_cambio_servicio queda pre-marcado.
  // Al guardar, la Nota de Débito auto se genera en facturar! (pre_factura.rb).
  duplicateAsCambioServicio() {
    const data = this._duplicateData
    if (!data || !data.existing_paquete_id) return
    window.location.href =
      `/paquetes/${data.existing_paquete_id}?mode=edit&cambio_servicio=1`
  }

  // Opción 2: "Es duplicado real" — pre-rellena el tracking del form con
  // el siguiente sufijo libre (A, B, C…) y cierra el modal. El digitador
  // termina de llenar los demás campos y guarda normalmente.
  duplicateAsNew() {
    const data = this._duplicateData
    if (!data || !data.next_tracking) return
    this.trackingTarget.value = data.next_tracking
    this.duplicateModalTarget.classList.add("hidden")
    this._duplicateData = null
    this.clienteInputTarget.focus()
  }

  // Form actions
  clearForm() {
    this.formTarget.reset()
    this.clienteIdTarget.value = ""
    this.clienteNombreTarget.textContent = ""
    this.clienteNombreTarget.classList.add("hidden")
    this.notasBannerTarget.classList.add("hidden")
    this.duplicateModalTarget.classList.add("hidden")
    this._unlockCliente()
    this._hidePreAlertaBanner()
    this._closeCajasModal()
    this._resetCantidadPaquetes()
    if (this.hasTrackingSecundarioContainerTarget) this._hideTrackingSecundario()
    if (this.hasTipoEnvioTarget) {
      this.tipoEnvioTarget.focus()
    } else {
      this.trackingTarget.focus()
    }
  }

  submitForm() {
    this._removePrintField()
    this._resetCantidadPaquetes()
    this.formTarget.requestSubmit()
  }

  // PR-4: F9 / Guardar+Imprimir abre el modal de "¿cuántas cajas?" antes
  // de submit. Yusef: "cantidad de paquetes se lo vamos a poner después
  // de presionar F9". El modal sobrescribe el hidden cantidad_paquetes
  // y dispara el submit con print=true.
  submitFormWithPrint() {
    if (!this.hasCajasModalTarget) {
      // Fallback si por alguna razón el modal no está montado: submit directo.
      this._submitWithPrint()
      return
    }
    this._resetCantidadPaquetes()
    if (this.hasCajasInputTarget) {
      this.cajasInputTarget.value = "1"
    }
    if (typeof this.cajasModalTarget.showModal === "function") {
      this.cajasModalTarget.showModal()
    } else {
      this.cajasModalTarget.setAttribute("open", "")
    }
    setTimeout(() => {
      if (this.hasCajasInputTarget) {
        this.cajasInputTarget.focus()
        this.cajasInputTarget.select()
      }
    }, 50)
  }

  cancelCajas() {
    this._closeCajasModal()
  }

  cajasKeydown(e) {
    if (e.key === "Enter") {
      e.preventDefault()
      this.confirmCajas()
    } else if (e.key === "Escape") {
      e.preventDefault()
      this.cancelCajas()
    }
  }

  confirmCajas() {
    const raw = this.hasCajasInputTarget ? parseInt(this.cajasInputTarget.value, 10) : 1
    const n = Number.isFinite(raw) ? Math.max(1, Math.min(26, raw)) : 1
    if (this.hasCantidadPaquetesHiddenTarget) {
      this.cantidadPaquetesHiddenTarget.value = String(n)
    }
    this._closeCajasModal()
    this._submitWithPrint()
  }

  _closeCajasModal() {
    if (!this.hasCajasModalTarget) return
    if (typeof this.cajasModalTarget.close === "function") {
      this.cajasModalTarget.close()
    } else {
      this.cajasModalTarget.removeAttribute("open")
    }
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

  _resetCantidadPaquetes() {
    if (this.hasCantidadPaquetesHiddenTarget) {
      this.cantidadPaquetesHiddenTarget.value = "1"
    }
  }

  _removePrintField() {
    const existing = this.formTarget.querySelector("[data-print-field]")
    if (existing) existing.remove()
  }

  // Handle turbo stream events
  eventTargetConnected(el) {
    const action = el.dataset.action
    if (action === "paquete-saved") {
      // Trigger success audio
      this.dispatch("success")

      if (el.dataset.print === "true") {
        window.open(`/paquetes/${el.dataset.paqueteId}/label`, "_blank")
      }

      // Clear form after successful save
      setTimeout(() => this.clearForm(), 100)
      el.remove()
    }
  }
}
