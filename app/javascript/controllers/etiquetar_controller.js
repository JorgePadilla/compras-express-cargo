import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "form", "tipoEnvio", "tracking",
    "trackingSecundario", "trackingSecundarioContainer",
    "trackingSecundarioToggle", "trackingSecundarioToggleLabel",
    "clienteInput", "clienteId", "clienteDropdown",
    "clienteNombre", "descripcion",
    "notasBanner", "notasTexto",
    "preAlertaBanner", "preAlertaNumero", "preAlertaCliente", "preAlertaDescripcion",
    "duplicateModal", "duplicateInfo", "duplicateNewBtn", "duplicateNewHint",
    "submitBtn", "event", "panel",
    "terceroContainer", "terceroToggle",
    "conflictoSesion", "conflictoSesionTexto"
  ]
  static values = {
    checkUrl: String,
    buscarUrl: String,
    // PR-C6.9: el tipo de envío del lote, para poder comparar contra el de la
    // pre-alerta sin otra vuelta al servidor.
    tipoEnvioSesion: String,
    tipoEnvioSesionNombre: String
  }

  connect() {
    this._searchTimeout = null
    this._clienteActiveIndex = -1
    this._handleGlobalKeydown = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this._handleGlobalKeydown)
    // Al cargar /etiquetar (incluida la navegación Turbo tras iniciar sesión),
    // el cursor arranca en el primer campo: tracking. `autofocus` no es
    // confiable en visitas Turbo, así que lo forzamos en connect.
    requestAnimationFrame(() => {
      if (this.hasTrackingTarget) this.trackingTarget.focus()
    })
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
    } else if (e.key === "F4") {
      // PR-10.c: Yusef — "funcion F4 para agregar un tercero, y que sea
      // oculto por defecto, porque confunde si no. De clientes tercero
      // recibimos 20% por mucho". Funciona en cualquier momento del form.
      e.preventDefault()
      this.toggleTercero()
    } else if (e.key === "F8" || e.key === "F10") {
      // F10 es guardar en todo el resto del sistema (pre-facturas, ventas,
      // caja, financiamientos) y Yusef lo apretó sin pensarlo. F8 se queda de
      // alias mientras Miami se acostumbra — allá ya lo tienen en el dedo.
      e.preventDefault()
      this.submitForm()
    } else if (e.key === "F9") {
      e.preventDefault()
      this.submitFormWithPrint()
    }
  }

  // ── Enter = siguiente campo, nunca guardar ────────────────────────────
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
  // tracking.
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
    if (!this._buscaCliente(query)) {
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

  // ¿Alcanza lo tecleado para buscar?
  //
  // PR-C6.16. Había un mínimo de 2 caracteres, y eso bloqueaba justo la forma
  // en que Miami trabaja. Yusef:
  //
  //   > "Solo le ponían el dos, ponele que el mío es el seis, solo poníamos el
  //   >  seis o el dos y ya con eso cae."
  //
  // Un dígito suelto es una búsqueda legítima —`2` cae en `CEC-002`, que el
  // backend ya pone primero (PR-C6.14b)— pero una letra suelta no: buscar "a"
  // devolvería la cartera entera y el dropdown sería ruido.
  _buscaCliente(query) {
    if (query.length >= 2) return true

    return /^\d$/.test(query)
  }

  renderDropdown(clientes) {
    if (clientes.length === 0) {
      this.clienteDropdownTarget.innerHTML = `
        <div class="px-4 py-3 text-sm text-gray-500">No se encontraron clientes</div>
      `
      this.showDropdown()
      return
    }

    this.clienteDropdownTarget.innerHTML = clientes.map((c, i) => `
      <button type="button"
        class="w-full text-left px-4 py-2 hover:bg-gray-100 flex items-center justify-between"
        data-action="click->etiquetar#selectCliente mousemove->etiquetar#hoverCliente"
        data-index="${i}"
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
    // Cargar el primer ítem como activo para confirmarlo con Enter sin mouse.
    this._clienteActiveIndex = 0
    this._highlightActiveCliente()
  }

  // ── Navegación por teclado del dropdown de cliente ──
  _clienteItems() {
    return Array.from(this.clienteDropdownTarget.querySelectorAll("[data-index]"))
  }

  _highlightActiveCliente() {
    const items = this._clienteItems()
    items.forEach((el, i) => {
      const active = i === this._clienteActiveIndex
      el.classList.toggle("bg-cec-teal/10", active)
      if (active) el.scrollIntoView({ block: "nearest" })
    })
  }

  _moveCliente(delta) {
    const items = this._clienteItems()
    if (items.length === 0) return
    const next = this._clienteActiveIndex + delta
    this._clienteActiveIndex = Math.max(0, Math.min(items.length - 1, next))
    this._highlightActiveCliente()
  }

  hoverCliente(e) {
    const idx = parseInt(e.currentTarget.dataset.index, 10)
    if (Number.isFinite(idx) && idx !== this._clienteActiveIndex) {
      this._clienteActiveIndex = idx
      this._highlightActiveCliente()
    }
  }

  clienteKeydown(e) {
    if (this.clienteDropdownTarget.classList.contains("hidden")) return
    const items = this._clienteItems()

    if (e.key === "ArrowDown") {
      e.preventDefault()
      this._moveCliente(1)
    } else if (e.key === "ArrowUp") {
      e.preventDefault()
      this._moveCliente(-1)
    } else if (e.key === "Enter") {
      const active = items[this._clienteActiveIndex]
      if (active) {
        e.preventDefault() // no enviar el form: solo seleccionar el cliente
        this._selectClienteEl(active)
      }
    } else if (e.key === "Escape") {
      e.preventDefault()
      this.hideDropdown()
    } else if (e.key === "Tab") {
      this.hideDropdown()
    }
  }

  selectCliente(e) {
    this._selectClienteEl(e.currentTarget)
  }

  _selectClienteEl(btn) {
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
      if (this.hasNotasTextoTarget) this.notasTextoTarget.textContent = notas
      if (this.hasNotasBannerTarget) this.notasBannerTarget.classList.remove("hidden")
      // Trigger audio alert for client notes
      this.dispatch("clienteNotas")
    } else if (this.hasNotasBannerTarget) {
      this.notasBannerTarget.classList.add("hidden")
    }

    // PR-9.b: jalar tareas + notas del cliente a la franja de la derecha.
    this.loadPanel(id)

    this.hideDropdown()
  }

  // Recarga el turbo-frame de la franja de contexto. Turbo se encarga del
  // fetch al cambiar el `src`; si el cliente es el mismo no lo tocamos para
  // no perder el estado de las tareas que el operario acaba de marcar.
  loadPanel(clienteId) {
    if (!this.hasPanelTarget) return

    const frame = this.panelTarget.querySelector("turbo-frame#panel_contexto")
    if (!frame) return

    const base = this.panelTarget.dataset.panelUrl
    const params = new URLSearchParams()
    if (clienteId) params.set("cliente_id", clienteId)

    const tracking = this.hasTrackingTarget ? this.trackingTarget.value.trim() : ""
    if (tracking) params.set("tracking", tracking)

    const url = params.toString() ? `${base}?${params}` : base
    if (frame.getAttribute("src") !== url) frame.setAttribute("src", url)
  }

  // Muestra/esconde el bloque de tercero y le pone el foco. Al esconderlo
  // limpia la seleccion, para no mandar un tercero que el operario ya no ve.
  toggleTercero() {
    if (!this.hasTerceroContainerTarget) return

    const oculto = this.terceroContainerTarget.classList.toggle("hidden")
    if (oculto) {
      const hidden = this.terceroContainerTarget.querySelector("input[name*='tercero_id']")
      const texto = this.terceroContainerTarget.querySelector("input[type='text']")
      if (hidden) hidden.value = ""
      if (texto) texto.value = ""
    } else {
      const texto = this.terceroContainerTarget.querySelector("input[type='text']")
      if (texto) texto.focus()
    }
    this._syncTerceroToggleLabel()
  }

  _syncTerceroToggleLabel() {
    if (!this.hasTerceroToggleTarget || !this.hasTerceroContainerTarget) return
    const oculto = this.terceroContainerTarget.classList.contains("hidden")
    this.terceroToggleTarget.innerHTML = oculto
      ? '+ Agregar tercero <kbd class="px-1 py-0.5 bg-gray-100 border rounded text-[10px]">F4</kbd>'
      : '- Quitar tercero <kbd class="px-1 py-0.5 bg-gray-100 border rounded text-[10px]">F4</kbd>'
  }

  hideDropdown() {
    this.clienteDropdownTarget.classList.add("hidden")
    this._clienteActiveIndex = -1
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
  //
  // PR-C6.21: el `fetch` iba suelto — sin cancelar el anterior, sin verificar
  // al volver que el campo siguiera diciendo lo mismo, y con un `catch` vacío
  // que se tragaba todo. La pistola manda Enter sola, así que escanear A y
  // enseguida B dejaba la respuesta de A pisando el formulario de B: banner de
  // pre-alerta equivocado, cliente auto-llenado equivocado, pito equivocado.
  //
  // Yusef, viéndolo: "le di enter y no lo reconoce... le di enter rápido y
  // mete rápido, aquí es donde tenés que ver cómo integrar eso. **Tiene que
  // ser rápido.**" — de ahí que la salida sea descartar respuestas viejas y no
  // meter un debounce, que sería justo lo contrario de lo que pidió.
  checkTracking() {
    const tracking = this.trackingTarget.value.trim()
    if (tracking.length < 5) return

    // Enter mueve el foco y el blur vuelve a disparar esto con el mismo valor.
    // Una consulta por escaneo, no dos.
    if (tracking === this._ultimoConsultado) return
    this._ultimoConsultado = tracking

    const consulta = (this._consultaSeq = (this._consultaSeq || 0) + 1)

    fetch(`${this.checkUrlValue}?tracking=${encodeURIComponent(tracking)}`, {
      headers: { "Accept": "application/json" }
    })
      .then(r => r.json())
      .then(data => {
        // Llegó tarde: ya salió otra consulta, o el operario ya está en otro
        // paquete. En los dos casos esta respuesta habla de algo que ya no
        // está en pantalla.
        if (consulta !== this._consultaSeq) return
        if (this.trackingTarget.value.trim() !== tracking) return

        // PR-2: si el tracking tiene pre-alerta, sonido distintivo + banner verde.
        // No abrimos el modal de duplicado en ese caso — la pre-alerta NO es un
        // duplicado, es un "paquete esperado" que el sistema reconciliará al guardar.
        if (data.pre_alerta_match) {
          this._showPreAlertaBanner(data)
          this.dispatch("preAlertaMatch")
          // PR-C6.9: si la pre-alerta pide otro tipo de envío que el de la
          // sesión, avisar YA — antes de que el operario siga llenando campos
          // que el servidor va a rechazar igual.
          this._avisarConflictoDeSesion(data)
          return
        }
        if (data.exists && !data.terminal) {
          this._openDuplicateModal(data)
        }
      })
      .catch((e) => {
        // No se puede seguir en silencio: si la consulta falla, el operario
        // cree que el tracking está limpio y graba un duplicado. Se permite
        // reintentar (el mismo valor vuelve a consultar) y queda registrado.
        if (consulta === this._consultaSeq) this._ultimoConsultado = null
        console.error("[etiquetar] falló la consulta del tracking", e)
      })
  }

  // El paquete escaneado pertenece a otro tipo de envío. Se avisa fuerte pero
  // NO se decide acá: el rechazo lo hace el servidor (`conflicto_con_la_sesion`),
  // porque el modal se puede saltar y el cobro no.
  //
  // Yusef lo consultó con Julián por videollamada y quedaron en las dos
  // salidas: finalizar la sesión para abrir la del tipo correcto, o seguir en
  // la misma y dejar el paquete de lado. En ninguna se graba.
  _avisarConflictoDeSesion(data) {
    const sesion = this.hasTipoEnvioSesionValue ? this.tipoEnvioSesionValue : null
    if (!sesion || !data.pre_alerta_tipo_envio_id) return
    if (String(data.pre_alerta_tipo_envio_id) === String(sesion)) return

    this.dispatch("tipoEnvioDistinto")
    if (this.hasConflictoSesionTarget) {
      if (this.hasConflictoSesionTextoTarget) {
        this.conflictoSesionTextoTarget.textContent =
          `Este paquete tiene pre-alerta de ${data.pre_alerta_tipo_envio}, ` +
          `y estás trabajando ${this.tipoEnvioSesionNombreValue}. No se puede guardar así.`
      }
      this.conflictoSesionTarget.classList.remove("hidden")
    }
  }

  _showPreAlertaBanner(data) {
    if (!this.hasPreAlertaBannerTarget) return
    if (this.hasPreAlertaNumeroTarget) this.preAlertaNumeroTarget.textContent = data.pre_alerta_numero || ""
    if (this.hasPreAlertaClienteTarget) this.preAlertaClienteTarget.textContent = data.pre_alerta_cliente || ""
    if (this.hasPreAlertaDescripcionTarget) this.preAlertaDescripcionTarget.textContent = data.pre_alerta_descripcion || ""
    this.preAlertaBannerTarget.classList.remove("hidden")

    // Auto-fill cliente cuando el JSON trae los campos. Queda editable
    // por si el operador necesita cambiarlo (Jorge), pero con pill
    // informativa indicando que vino de la PA.
    if (data.cliente_id) this._fillClienteFromPreAlerta(data)

    // Auto-fill descripción desde la PA (editable, NO se bloquea — Miami
    // a veces descubre que el contenido real difiere del declarado).
    // Solo rellena si el operador no escribió nada para no pisar input.
    if (data.pre_alerta_descripcion && this.hasDescripcionTarget &&
        this.descripcionTarget.value.trim() === "") {
      this.descripcionTarget.value = data.pre_alerta_descripcion
    }
  }

  _hidePreAlertaBanner() {
    if (!this.hasPreAlertaBannerTarget) return
    this.preAlertaBannerTarget.classList.add("hidden")
  }

  _fillClienteFromPreAlerta(data) {
    if (this.hasClienteIdTarget) this.clienteIdTarget.value = data.cliente_id
    if (this.hasClienteInputTarget) {
      // Mostrar "CEC-006 — Maria Lopez" todo junto en el input cuando viene
      // de PA. Queda editable — si el operador necesita cambiar, Ctrl+A o
      // borrar y escribir el nuevo código dispara el dropdown de búsqueda.
      const codigo = data.cliente_codigo || ""
      const nombre = data.cliente_nombre || ""
      this.clienteInputTarget.value = nombre ? `${codigo} — ${nombre}` : codigo
      // Ring teal sutil indica origen PA, pero sin cursor-not-allowed.
      this.clienteInputTarget.classList.add(
        "bg-cec-teal/5", "dark:bg-cec-teal/15", "ring-1", "ring-cec-teal/40"
      )
    }
    // El `<p>` separado de nombre completo deja de tener sentido cuando el
    // código+nombre ya están juntos en el input. Lo escondemos.
    if (this.hasClienteNombreTarget) {
      this.clienteNombreTarget.textContent = ""
      this.clienteNombreTarget.classList.add("hidden")
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

    // PR-9.b: con match de pre-alerta la franja además trae las "notas
    // especiales" (las instrucciones que el cliente escribió para ESTE
    // tracking) y las tareas que salieron de ellas.
    this.loadPanel(data.cliente_id)
  }

  // Limpia los estilos visuales del input cliente que ponemos cuando viene
  // de PA (anillo teal + pill informativa). Lo usa clearForm (F2) y se podría
  // disparar también si el operador empieza a editar el código manualmente.
  _resetClienteFromPreAlertaStyling() {
    if (this.hasClienteInputTarget) {
      this.clienteInputTarget.classList.remove(
        "bg-cec-teal/5", "dark:bg-cec-teal/15", "ring-1", "ring-cec-teal/40"
      )
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
      // PR-10.c: Yusef — "aqui solo agregarle el contenido... el contenido y
      // el tipo de servicio, esas son las dos cosas que mas te faltan ahi".
      { text: `Contenido: ${data.descripcion || "—"}`, cls: "mt-1" },
      { text: `Servicio: ${data.tipo_envio || "—"}`, cls: "" },
      { text: `Recepcion: ${data.numero_recepcion || "—"}`, cls: "font-mono text-xs text-gray-500 dark:text-gray-400" },
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

    // PR-C6.9: el modal de duplicado abría mudo. Yusef: "pita para dos
    // razones... pita, te decía, pre-alerta" y "el otro pito es porque te
    // tira que **ya existía**". Son dos avisos distintos, no uno.
    this.dispatch("trackingYaExiste")
    this.duplicateModalTarget.classList.remove("hidden")
  }

  closeDuplicate() {
    this.duplicateModalTarget.classList.add("hidden")
    this._duplicateData = null
  }

  // Opción 1: "Es actualización" — recarga ESTE formulario con los datos del
  // paquete, sin salir de /etiquetar.
  //
  // PR-C6.10. Antes mandaba a `/paquetes/:id/edit`, y Yusef lo cortó en seco:
  //
  //   > "Me mandaste a editar y yo no quiero editar mi paquete."
  //   > "Que te cargue aquí la lista. Esto te lo vuelve a llenar tal cual como
  //   >  quedó, y actualizan todo lo que quieran actualizar, porque eso es lo
  //   >  que ellos ocupan."
  //
  // Contó los pasos en voz alta —editar, guardar, volver, re-imprimir,
  // seleccionar— y ahí se le acabó la paciencia.
  duplicateAsUpdate() {
    const data = this._duplicateData
    if (!data || !data.existing_paquete_id) return
    window.location.href = `/etiquetar?paquete_id=${data.existing_paquete_id}`
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
    this._limpiarCampos()
    this.clienteIdTarget.value = ""
    this.clienteNombreTarget.textContent = ""
    this.clienteNombreTarget.classList.add("hidden")
    if (this.hasNotasBannerTarget) this.notasBannerTarget.classList.add("hidden")
    this.duplicateModalTarget.classList.add("hidden")
    // PR-9.b: la franja vuelve a su estado vacío junto con el formulario.
    this.loadPanel(null)
    if (this.hasTerceroContainerTarget) {
      this.terceroContainerTarget.classList.add("hidden")
      this._syncTerceroToggleLabel()
    }
    this._resetClienteFromPreAlertaStyling()
    this._hidePreAlertaBanner()
    if (this.hasConflictoSesionTarget) this.conflictoSesionTarget.classList.add("hidden")
    if (this.hasTrackingSecundarioContainerTarget) this._hideTrackingSecundario()
    if (this.hasTipoEnvioTarget) {
      this.tipoEnvioTarget.focus()
    } else {
      this.trackingTarget.focus()
    }
  }

  // F2 tiene que dejar el formulario en blanco, siempre. Yusef: "todo, todo.
  // Porque se equivocó y lo mejor es F2 y volvemos a empezar".
  //
  // Antes esto era `formTarget.reset()`, y ahí estaba el bug que reportó como
  // "le doy F2 y no limpia": `reset()` no vacía el formulario — lo devuelve a
  // los valores **renderizados**. Cuando el submit fallaba y el servidor
  // re-renderizaba con 422, esos valores eran los que él acababa de escribir,
  // así que F2 "limpiaba" de vuelta a lo mismo.
  //
  // No es problema de foco: el listener de F2 es a nivel `document`.
  _limpiarCampos() {
    // Los `hidden` quedan afuera a propósito: ahí viven el token CSRF y el
    // `_method` de Rails. Los dos que sí hay que limpiar (`cliente_id` y
    // `cantidad_paquetes`) los maneja `clearForm` explícitamente.
    const campos = this.formTarget.querySelectorAll(
      "input:not([type=hidden]), select, textarea"
    )

    campos.forEach((el) => {
      if (el.type === "checkbox" || el.type === "radio") {
        el.checked = false
      } else if (el.tagName === "SELECT") {
        el.selectedIndex = 0
      } else {
        el.value = ""
      }
    })

    // PR-C6.21: el formulario en blanco empieza un paquete nuevo, así que el
    // dedupe de consultas arranca de cero. Sin esto, re-escanear el mismo
    // tracking después de un F2 no volvería a consultarlo.
    this._ultimoConsultado = null
  }

  submitForm() {
    this._removePrintField()
    this.formTarget.requestSubmit()
  }

  // PR-4: F9 / Guardar+Imprimir abre el modal de "¿cuántas cajas?" antes
  // de submit. Yusef: "cantidad de paquetes se lo vamos a poner después
  // de presionar F9". El modal sobrescribe el hidden cantidad_paquetes
  // y dispara el submit con print=true.
  // F9 = guardar e imprimir, sin preguntar nada.
  //
  // PR-C6.18b. Acá vivía un modal que preguntaba "¿cuántas cajas?" antes de
  // enviar (PR-4). Jorge lo probó y fue directo: **"el F9 era como confuso"**
  // — la cantidad de cajas es un dato del paquete, no un paso de impresión, y
  // esconderla detrás de una tecla hacía que el campo visible del formulario
  // ("Cant. Productos") pareciera el que mandaba.
  //
  // Ahora vive en el formulario, junto al peso y las medidas, con las filas
  // por caja debajo (`cajas_controller.js`).
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

  // Handle turbo stream events
  eventTargetConnected(el) {
    const action = el.dataset.action
    if (action === "paquete-saved") {
      // Trigger success audio
      this.dispatch("success")

      if (el.dataset.print === "true") {
        // PR-10.d: la ETIQUETA (Dymo 2.25x1.25), no el Warehouse Receipt.
        // Yusef: "aqui esta tirando el warehouse, no la etiqueta".
        // `hermanas=1` saca una por caja cuando el tracking se dividio.
        window.open(`/paquetes/${el.dataset.paqueteId}/etiqueta?hermanas=1&print=true`, "_blank")
      }

      // Clear form after successful save
      setTimeout(() => this.clearForm(), 100)
      el.remove()
    }
  }
}
