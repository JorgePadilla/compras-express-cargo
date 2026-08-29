import ClienteAutocomplete from "controllers/cliente_autocomplete"
import { conEnterAvanza } from "controllers/enter_avanza"

// El color del encabezado según de qué avisa. Yusef: *"el cerebro hasta el color
// asocia"*. Rojo para lo que frena el paquete, ámbar para lo que hay que hacer,
// navy para lo que hay que leer.
const TONOS_DE_AVISO = {
  retencion: "bg-red-600 text-white",
  tarea: "bg-cec-gold text-cec-navy",
  nota: "bg-cec-navy text-white"
}

// PR-C6.32: la búsqueda de cliente vive en `ClienteAutocomplete`, compartida
// con /entrega_personal. Acá solo queda lo propio de etiquetar: el banner de
// notas de Miami, vía el gancho `_alSeleccionarCliente`.
export default class extends conEnterAvanza(ClienteAutocomplete) {
  static targets = [
    "form", "tipoEnvio", "tracking",
    "trackingSecundario", "trackingSecundarioContainer",
    "trackingSecundarioToggle", "trackingSecundarioToggleLabel",
    "clienteInput", "clienteId", "clienteDropdown",
    "clienteNombre", "descripcion",
    "notasBanner", "notasTexto",
    "preAlertaBanner", "preAlertaNumero", "preAlertaCliente", "preAlertaDescripcion",
    "duplicateModal", "duplicateInfo", "duplicateUpdateBtn", "duplicateNewBtn", "duplicateNewHint",
    "submitBtn", "event", "panel",
    "terceroContainer", "terceroToggle",
    "conflictoSesionModal", "conflictoSesionTexto", "conflictoSesionDejarBtn",
    "sucursalBanner", "sucursalTexto", "sucursalModal", "sucursalModalTexto",
    "quitarCobroModal",
    "etiquetasModal", "etiquetasInput",
    "avisoModal", "avisoEncabezado", "avisoTipo", "avisoTitulo", "avisoTexto",
    "avisoPrincipal", "avisoSecundario"
  ]
  static values = {
    checkUrl: String,
    buscarUrl: String,
    // PR-C6.9: el tipo de envío del lote, para poder comparar contra el de la
    // pre-alerta sin otra vuelta al servidor.
    tipoEnvioSesion: String,
    tipoEnvioSesionNombre: String,
    // El paquete que se está actualizando. Vacío al dar de alta.
    actualizandoId: String,
    // Cuántas cajas tiene ya, para que el modal no arranque en 1 y borrarlas
    // quede a un Enter de distancia.
    cajasActuales: Number
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
      if (this._preguntaAbierta()) return
      this.submitForm()
    } else if (e.key === "F9") {
      e.preventDefault()
      if (this._preguntaAbierta()) return
      this.submitFormWithPrint()
    }
  }

  // C19-08 · Jorge: "podemos hacer que los modales salgan en orden,
  // actualmente salen montados". La regla que lo garantiza: mientras haya una
  // pregunta en pantalla sin contestar, las teclas de guardar no actúan — así
  // ningún modal nuevo (¿cuántas etiquetas?, la bolsa) se abre encima del que
  // espera respuesta. CUALQUIER <dialog> abierto cuenta a propósito: el aviso
  // en fila, el de etiquetas, el PIN, las listitas de retener/política — todos
  // son preguntas. F2 queda libre: es la salida que los propios modales
  // ofrecen. Contestar cuesta un Enter; guardar por encima costaba un error.
  _preguntaAbierta() {
    if (document.querySelector("dialog[open]")) return true
    if (this._conflictoVisible()) return true
    return this.hasDuplicateModalTarget &&
           !this.duplicateModalTarget.classList.contains("hidden")
  }

  _conflictoVisible() {
    return this.hasConflictoSesionModalTarget &&
           !this.conflictoSesionModalTarget.classList.contains("hidden")
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
    // C16-05: el campo se vacía por F3, por F2 y por «Dejarlo de lado», y los
    // tres son un secundario nuevo. La memoria que evita consultar dos veces
    // el mismo valor (`_ultimoSecundario`) se quedaba puesta, así que volver a
    // usar el mismo tracking secundario en el paquete siguiente **ni siquiera
    // consultaba** — Yusef: *"ya lo había detectado, y se quedó esto así,
    // mirá: no lo limpió"*. El primario ya lo hacía desde PR-C6.21; el
    // secundario no.
    this._ultimoSecundario = null
    this._secundarioPreAlerta = null
    if (this.hasTrackingSecundarioToggleLabelTarget) {
      this.trackingSecundarioToggleLabelTarget.textContent = "+ Agregar tracking secundario"
    }
  }

  // Lo que etiquetar hace de más al elegir un cliente: avisar de sus notas de
  // Miami. La franja de contexto la carga `loadPanel`, que acá además manda el
  // tracking del paquete.
  // PR-C6.24: a qué sucursal va la caja. Se muestra apenas se elige el
  // cliente, no al guardar: es una decisión física —en qué bolsa cae— y si se
  // entera tarde hay que volver a abrir la bolsa.
  _mostrarSucursal(sucursal, esLaDeSiempre = false) {
    this._sucursalActual = (sucursal || "").trim()
    // Yusef: *"esa de San Pedro Sula hay que eliminarlo, porque es el default…
    // el cerebro trabaja en default; cuando querés que haga una cosa diferente,
    // tenés que ponerle la nota que es diferente"*. El 80% de la carga se queda
    // ahí: un aviso que sale siempre deja de leerse, y con él el del día que
    // dice Tegucigalpa — que era el único que importaba.
    //
    // El banner sí se queda: es pasivo y no interrumpe a nadie. Lo que deja de
    // salir para la de siempre es el **modal** del final, que tapa la pantalla.
    this._avisarLaBolsa = this._sucursalActual !== "" && !esLaDeSiempre

    if (!this.hasSucursalBannerTarget) return
    if (this._sucursalActual === "") {
      this.sucursalBannerTarget.classList.add("hidden")
      return
    }

    if (this.hasSucursalTextoTarget) this.sucursalTextoTarget.textContent = this._sucursalActual
    this.sucursalBannerTarget.classList.remove("hidden")
  }

  // El segundo aviso: "solo quiero un modal al principio y uno al final".
  // Sale después de imprimir, que es cuando el operario tiene la etiqueta en
  // la mano y va a guardar la caja.
  _avisarSucursalAlFinal() {
    if (!this._sucursalActual || !this.hasSucursalModalTarget) return
    if (!this._avisarLaBolsa) return

    if (this.hasSucursalModalTextoTarget) {
      this.sucursalModalTextoTarget.textContent = this._sucursalActual
    }
    // RP-20: Yusef pidió "un pin antes de que salga cualquier modal" (A1-10).
    // La vista escuchaba `modalAbierto` desde `PR-C6.16` y nadie lo disparaba
    // nunca: este modal y el del PIN abrían mudos, con el operario mirando la
    // pistola. El cable estaba puesto; le faltaba este extremo.
    this.dispatch("modalAbierto")
    if (this.sucursalModalTarget.showModal) this.sucursalModalTarget.showModal()
    else this.sucursalModalTarget.classList.remove("hidden")
  }

// PR-C6.28: el modal donde el supervisor pone su PIN para quitarle al
// paquete el cobro por cambio de servicio.
abrirQuitarCobro() {
  if (!this.hasQuitarCobroModalTarget) return

  this.dispatch("modalAbierto")
  if (this.quitarCobroModalTarget.showModal) this.quitarCobroModalTarget.showModal()
  else this.quitarCobroModalTarget.classList.remove("hidden")
  this.quitarCobroModalTarget.querySelector("select, input")?.focus()
}

cerrarQuitarCobro() {
  if (!this.hasQuitarCobroModalTarget) return

  if (this.quitarCobroModalTarget.close) this.quitarCobroModalTarget.close()
  else this.quitarCobroModalTarget.classList.add("hidden")
}

  cerrarSucursalModal() {
    if (!this.hasSucursalModalTarget) return

    if (this.sucursalModalTarget.close) this.sucursalModalTarget.close()
    else this.sucursalModalTarget.classList.add("hidden")
    // C19-02: `showModal()` se llevó el foco; al cerrar, de vuelta al
    // tracking para el siguiente escaneo.
    this._volverAlTracking()
  }

  // C16-04 · Yusef, 2026-08-25: "mirá a ver si lo podés lograr que quede al
  // mismo Tab: que vos lo seleccionás, se pase". Enter sobre el cliente elegía
  // y se quedaba en el campo; el segundo Enter recién avanzaba. Ahora elegir
  // con el teclado ya es avanzar, como en cualquier otro campo.
  _despuesDeElegirConTeclado(e) {
    this._focusSiguiente(e.target)
  }

  _alSeleccionarCliente({ id, notas, sucursalRetiro, retiroPorDefecto }) {
    this._mostrarSucursal(sucursalRetiro, retiroPorDefecto === "true" || retiroPorDefecto === true)

    if (notas && notas.trim() !== "") {
      if (this.hasNotasTextoTarget) this.notasTextoTarget.textContent = notas
      if (this.hasNotasBannerTarget) this.notasBannerTarget.classList.remove("hidden")
      this.dispatch("clienteNotas")
    } else if (this.hasNotasBannerTarget) {
      this.notasBannerTarget.classList.add("hidden")
    }

    this.loadPanel(id)
    this._revisarSecundarioPendiente()
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
  // El secundario se revisa igual que el primario.
  //
  // Yusef: *"aquí no me dio alerta del Secundario"*. El campo no tenía ninguna
  // acción cableada: un secundario ya usado no avisaba nada. `buscar_escaneado`
  // ya lo cubre del lado del server (`paquete.rb:344`) — faltaba preguntarle.
  //
  // No auto-rellena cliente: el segundo número es del mismo bulto que se está
  // cargando, y el cliente ya lo puso el primero.
  //
  // 2026-08-18: pero **una pre-alerta no es un duplicado**. Yusef escaneó un
  // secundario que también tenía la suya y le salió el modal de "¿es una
  // actualización?":
  //
  //   > "Esto, según tus reglas del inicio, no debería pasar… aquí está
  //   >  agarrando la regla de que existe el tracking y no la regla de que es
  //   >  una pre-alerta."
  //
  // Es la misma divergencia de siempre: `checkTracking` tiene esa rama desde
  // `PR-2` y acá se copió **solo** el chequeo de duplicado.
  checkTrackingSecundario() {
    if (!this.hasTrackingSecundarioTarget) return
    const valor = this.trackingSecundarioTarget.value.trim()
    if (valor.length < 5) return
    if (valor === this._ultimoSecundario) return
    this._ultimoSecundario = valor

    // El mismo guard que `checkTracking` (PR-C6.21): la respuesta que llega
    // tarde habla de un valor que ya no está en pantalla.
    const consulta = (this._secundarioSeq = (this._secundarioSeq || 0) + 1)

    fetch(this._urlDeConsulta(valor), {
      headers: { "Accept": "application/json" }
    })
      .then(r => r.json())
      .then(data => {
        if (consulta !== this._secundarioSeq) return
        if (this.trackingSecundarioTarget.value.trim() !== valor) return
        if (data.pre_alerta_match) return this._revisarSecundarioConPreAlerta(data)
        if (data.exists && !data.terminal) this._openDuplicateModal(data)
      })
      .catch(() => { if (consulta === this._secundarioSeq) this._ultimoSecundario = null })
  }

  // El secundario también venía anunciado. Lo que hay que hacer con eso lo
  // dictó Yusef, y son dos mitades:
  //
  //   > "Si los dos tienen pre-alerta pero el tipo de envío está correcto, no
  //   >  es necesario hacer nada. Ahora, si hay una incongruencia… hay que
  //   >  avisarle al usuario: hay una diferencia en el tipo de envío."
  //   > "Cuando tiene nombres diferentes, igual: hay incongruencia en el
  //   >  nombre, está a nombre de dos personas diferentes."
  //
  // Contra qué se compara: el **cliente que ya está en el formulario** (lo puso
  // el primer escaneo, o el operario a mano) y el **tipo de envío de la
  // sesión**. Él calcula que en el 80% de los casos solo uno de los dos
  // trackings trae pre-alerta, así que comparar contra la pre-alerta del
  // primero no serviría — muchas veces no hay.
  //
  // **No marca nada solo.** Jorge se lo preguntó derecho —"¿el sistema va y
  // marca la casillita?"— y contestó que no: *"ahí mismo le dice: este paquete
  // tiene dos tipos de envío. Lo va a retener, o lo va a enviar así"*. Decide
  // el operario.
  _revisarSecundarioConPreAlerta(data) {
    this.dispatch("preAlertaMatch")

    // C16-05: el secundario está **arriba** del cliente en el formulario, así
    // que en el orden natural esto corre con el cliente todavía vacío y la
    // comparación no tiene contra qué comparar — la primera vez que Yusef lo
    // probó avisó solo porque la pre-alerta del primario ya había puesto al
    // cliente. Se guarda lo que dijo el servidor y se vuelve a comparar cuando
    // el cliente aparezca (`_alSeleccionarCliente`).
    this._secundarioPreAlerta = data
    const hayCliente = this.hasClienteIdTarget && this.clienteIdTarget.value !== ""
    if (hayCliente && this._avisarSiEsDeOtroCliente(data)) return

    // La otra mitad ya está escrita para el primario: el tipo de envío de la
    // pre-alerta contra el de la sesión.
    this._avisarConflictoDeSesion(data)
  }

  // ¿El secundario está pre-alertado a nombre de otro cliente que el del
  // formulario? Avisa y devuelve `true`. No suena la voz de pre-alerta acá:
  // eso ya sonó cuando el servidor contestó, y volver a llamarlo cada vez que
  // se cambia el cliente la repetiría.
  _avisarSiEsDeOtroCliente(data) {
    const clienteActual = this.hasClienteIdTarget ? this.clienteIdTarget.value : ""
    const otroCliente = clienteActual && data.cliente_id &&
                        String(data.cliente_id) !== String(clienteActual)
    if (!otroCliente) return false

    this._avisarIncongruenciaDelSecundario(
      `El tracking secundario está pre-alertado a nombre de ${data.pre_alerta_cliente}, ` +
      `y este paquete va a nombre de otro cliente. Revisá antes de guardar: ` +
      `puede que haya que retenerlo en Miami.`)
    return true
  }

  // El secundario que se revisó con el cliente vacío, ahora que hay cliente.
  _revisarSecundarioPendiente() {
    const data = this._secundarioPreAlerta
    if (!data) return
    if (!this.hasTrackingSecundarioTarget || this.trackingSecundarioTarget.value.trim() === "") return

    this._avisarSiEsDeOtroCliente(data)
  }

  _avisarIncongruenciaDelSecundario(texto) {
    // C19-08: por el camino único del conflicto — que además cierra el aviso
    // que estuviera en pantalla, porque el secundario se teclea con los
    // avisos del primario ya saliendo y acá se montaban.
    this._mostrarConflicto(texto)
  }

  // El paquete que se está actualizando NO es un duplicado de sí mismo.
  //
  // Jorge, 2026-08-19: *"cuando estamos actualizando hay un comportamiento
  // raro: cierro el modal y doy click en la forma y se vuelve a abrir el
  // modal"*. Al entrar por `?paquete_id=` el tracking viene puesto, y el primer
  // blur salía a preguntar si existía — claro que existía: **era él**. Así que
  // el operario que entró justamente a actualizarlo recibía "ya está en el
  // sistema, ¿es una actualización?" sobre el paquete que ya estaba
  // actualizando, y volvía a salir cada vez que el campo perdía el foco.
  //
  // `excluir_paquete_id` ya existe para esto — `PR-C6.44` lo agregó cuando el
  // editor de pre-alertas se avisaba a sí mismo. El comentario del server decía
  // *"/etiquetar nunca manda el parámetro"*, y era cierto mientras solo diera
  // de alta.
  _urlDeConsulta(valor) {
    const url = new URL(this.checkUrlValue, window.location.origin)
    url.searchParams.set("tracking", valor)
    if (this.hasActualizandoIdValue && this.actualizandoIdValue) {
      url.searchParams.set("excluir_paquete_id", this.actualizandoIdValue)
    }
    return url.pathname + url.search
  }

  checkTracking() {
    const tracking = this.trackingTarget.value.trim()
    if (tracking.length < 5) return

    // Enter mueve el foco y el blur vuelve a disparar esto con el mismo valor.
    // Una consulta por escaneo, no dos.
    if (tracking === this._ultimoConsultado) return
    this._ultimoConsultado = tracking

    const consulta = (this._consultaSeq = (this._consultaSeq || 0) + 1)

    fetch(this._urlDeConsulta(tracking), {
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
          // C19-08 · Jorge: "si hay varias notas y alertas como la del paquete
          // de otro tipo de envío hay que mostrarlas en orden y no montadas,
          // el orden que haga más sentido". El orden con sentido es que el
          // conflicto de sesión decide PRIMERO — y como sus dos salidas
          // (finalizar la sesión / dejarlo de lado) abandonan el paquete en
          // esta sesión, no hay "después": los avisos de retención, tareas y
          // notas pertenecen a la sesión donde el paquete sí se va a recibir,
          // y vuelven a salir enteros al escanearlo ahí. Antes acá salían el
          // beep de match, la fila de avisos Y el conflicto, montados: el
          // aviso (un <dialog>, top-layer) tapaba al conflicto (un overlay).
          //
          // El banner y el auto-fill sí quedan: dicen QUÉ pre-alerta es, que
          // es contexto para decidir. Y suena solo el error — el beep alegre
          // de match sobre un paquete que no se puede guardar era mentirle al
          // oído del operario (cambia lo de PR-C6.9, que mandaba los dos).
          if (this._hayConflictoDeSesion(data)) {
            this._mostrarConflicto(
              `Este paquete tiene pre-alerta de ${data.pre_alerta_tipo_envio}, ` +
              `y estás trabajando ${this.tipoEnvioSesionNombreValue}. No se puede guardar así.`)
            return
          }
          this.dispatch("preAlertaMatch")
          this._encolarAvisos(data)
          return
        }
        if (data.exists && !data.terminal) {
          this._openDuplicateModal(data)
          return
        }
        this._avisarTrackingLibre()
      })
      .catch((e) => {
        // No se puede seguir en silencio: si la consulta falla, el operario
        // cree que el tracking está limpio y graba un duplicado. Se permite
        // reintentar (el mismo valor vuelve a consultar) y queda registrado.
        if (consulta === this._consultaSeq) this._ultimoConsultado = null
        console.error("[etiquetar] falló la consulta del tracking", e)
      })
  }

  // El pin de «podés seguir» cuando el chequeo vuelve limpio: ni duplicado ni
  // pre-alerta. Yusef, 2026-08-25 (C16-02): *"¿cuándo escuchás el pip? Cuando
  // el sistema buscó en los paquetes y vio que no existía"* · *"siempre hay
  // pitos para decir: ok, podés seguir"*. El operario mira la pistola, no la
  // pantalla, y sin este pito no sabe si el chequeo terminó.
  //
  // Un tracking terminal (entregado, anulado) también está libre: se puede
  // volver a usar, y PR-C6.9 ya lo deja pasar sin modal.
  //
  // No suena al actualizar: ahí el tracking viene puesto desde el servidor y
  // el primer blur no es un escaneo — pitaría sin que nadie hubiera hecho
  // nada.
  _avisarTrackingLibre() {
    if (this.hasActualizandoIdValue && this.actualizandoIdValue) return
    this.dispatch("trackingLibre")
  }

  // El paquete escaneado pertenece a otro tipo de envío.
  //
  // Yusef lo consultó con Julián por videollamada y quedaron en las dos
  // salidas: finalizar la sesión para abrir la del tipo correcto, o seguir en
  // la misma y dejar el paquete de lado. En ninguna se graba.
  //
  // A7-17: esto avisaba con un banner inline y el operario podía seguir
  // llenando el formulario igual — Yusef lo hizo delante de Jorge: "mira lo
  // que pasa ahora: **yo lo puedo recibir**". Ahora es un modal que tapa la
  // pantalla y obliga a elegir una de las dos.
  //
  // El rechazo de verdad lo sigue haciendo el servidor
  // (`conflicto_con_la_sesion`): el modal es para que el operario se entere
  // antes de llenar diez campos, no para reemplazar la validación.
  _hayConflictoDeSesion(data) {
    const sesion = this.hasTipoEnvioSesionValue ? this.tipoEnvioSesionValue : null
    if (!sesion || !data.pre_alerta_tipo_envio_id) return false
    return String(data.pre_alerta_tipo_envio_id) !== String(sesion)
  }

  // C19-08: el único lugar que abre el modal de conflicto — lo comparten el
  // tipo de envío distinto y la incongruencia del secundario. El conflicto
  // MANDA: si había un aviso en pantalla o en fila (el secundario se teclea
  // con el paquete ya escaneado y sus avisos ya saliendo), se cierran y la
  // cola muere ANTES de abrir — el `close()` directo no pasa por
  // `_cerrarAviso`, así que nada la vuelve a avanzar. Los avisos no se
  // pierden: vuelven a salir enteros al escanear el paquete en la sesión
  // que corresponde.
  _mostrarConflicto(texto) {
    this.dispatch("tipoEnvioDistinto")
    if (!this.hasConflictoSesionModalTarget) return

    this._colaDeAvisos = []
    this._avisoActual = null
    if (this.hasAvisoModalTarget && this.avisoModalTarget.open) this.avisoModalTarget.close()

    if (this.hasConflictoSesionTextoTarget) this.conflictoSesionTextoTarget.textContent = texto
    this.conflictoSesionModalTarget.classList.remove("hidden")

    // Se intenta llevar el foco al modal. Va en el frame siguiente porque esto
    // corre al resolverse el `fetch`, y en ese mismo tick todavía se están
    // acomodando el auto-llenado del cliente y la navegación con Enter.
    //
    // Es un extra, no el bloqueo: lo que impide guardar mal es el overlay —que
    // tapa el formulario, y desde C19-08 también apaga F8/F9/F10— y, si
    // alguien igual llega a mandar el POST, el rechazo del servidor
    // (`conflicto_con_la_sesion`), que tiene sus tests.
    if (this.hasConflictoSesionDejarBtnTarget) {
      requestAnimationFrame(() => this.conflictoSesionDejarBtnTarget.focus())
    }
  }

  // "Dejarlo de lado y seguir" — cierra el modal y limpia el formulario. Es la
  // misma acción que F2, y por eso pasa por `clearForm`: si algún día F2 hace
  // algo más, esto no se queda atrás.
  descartarPorConflicto() {
    this.clearForm()
    if (this.hasTrackingTarget) this.trackingTarget.focus()
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

    this._marcarRetencionDeLaPreAlerta(data)
  }

  // ── Lo que el que recibe TIENE que ver ────────────────────────────────
  //
  // Yusef, 2026-08-19, señalando la franja donde esto salía como texto al
  // costado: *"estas informaciones ellos no las leen… a puro huevos leen esto"*.
  // Digitan de 500 a 1.000 paquetes al día mirando la pistola.
  //
  // **Uno por cosa, no uno con todo**: él arrancó pidiendo uno solo y Jorge
  // argumentó que cada uno necesita su propia respuesta —retenido / se hizo /
  // leída—. Salen en fila y solo los que el paquete tiene: si no hay retención
  // ni tareas ni notas, no sale nada.
  _encolarAvisos(data) {
    const cola = []

    if (data.retener_miami) {
      const motivos = (data.motivo_retencion_nombres || []).join(" · ")
      cola.push({
        tipo: "Retener en Miami",
        titulo: "NO DESPACHAR",
        texto: [motivos, data.notas_retencion].filter(Boolean).join("\n") ||
               "Sin motivo anotado.",
        principal: "Retenido, confirmado",
        tono: "retencion"
      })
    }

    ;(data.tareas || []).forEach(t => cola.push({
      tipo: "Tarea pendiente",
      titulo: t.titulo,
      texto: "",
      principal: "Se hizo",
      secundario: "Todavía no",
      completarUrl: t.url,
      tono: "tarea"
    }))

    ;(data.notas || []).forEach(n => cola.push({
      tipo: n.titulo,
      titulo: "Nota del cliente",
      texto: n.texto,
      principal: "Leída",
      tono: "nota"
    }))

    this._colaDeAvisos = cola
    this._siguienteAviso()
  }

  _siguienteAviso() {
    if (!this.hasAvisoModalTarget) return
    // C19-08: con el conflicto en pantalla la fila muere — un aviso abriéndose
    // encima (es un <dialog>: top-layer, tapa cualquier overlay) era
    // exactamente el "salen montados" de Jorge.
    if (this._conflictoVisible()) {
      this._colaDeAvisos = []
      return
    }
    const aviso = (this._colaDeAvisos || []).shift()
    if (!aviso) return

    this._avisoActual = aviso
    if (this.hasAvisoTipoTarget) this.avisoTipoTarget.textContent = aviso.tipo
    if (this.hasAvisoTituloTarget) this.avisoTituloTarget.textContent = aviso.titulo
    if (this.hasAvisoTextoTarget) this.avisoTextoTarget.textContent = aviso.texto
    if (this.hasAvisoPrincipalTarget) this.avisoPrincipalTarget.textContent = aviso.principal
    if (this.hasAvisoSecundarioTarget) {
      this.avisoSecundarioTarget.textContent = aviso.secundario || ""
      this.avisoSecundarioTarget.classList.toggle("hidden", !aviso.secundario)
    }
    if (this.hasAvisoEncabezadoTarget) {
      this.avisoEncabezadoTarget.className =
        `px-6 py-4 text-center ${TONOS_DE_AVISO[aviso.tono] || TONOS_DE_AVISO.nota}`
    }

    // A1-10: "un pin antes de que salga cualquier modal".
    this.dispatch("modalAbierto")
    this.avisoModalTarget.showModal()
  }

  // "Se hizo" en una tarea la marca de verdad, por donde ya se marcaba: el
  // endpoint del checkbox de la franja, que registra **quién** la completó. Un
  // endpoint nuevo sería la gemela separada otra vez.
  avisoSi() {
    const aviso = this._avisoActual
    if (aviso?.completarUrl) {
      const token = document.querySelector("meta[name='csrf-token']")?.content
      fetch(aviso.completarUrl, {
        method: "POST",
        headers: { "X-CSRF-Token": token, "Accept": "text/vnd.turbo-stream.html" }
      }).catch(e => console.error("[etiquetar] no se pudo completar la tarea", e))
    }
    this._cerrarAviso()
  }

  avisoNo() {
    this._cerrarAviso()
  }

  _cerrarAviso() {
    this.avisoModalTarget.close()
    this._avisoActual = null
    // El siguiente en el frame que viene: dos `showModal()` en el mismo tick
    // dejan el segundo sin foco.
    requestAnimationFrame(() => this._siguienteAviso())
  }

  // La retención que viene anunciada.
  //
  // El checkbox arranca desmarcado y un checkbox desmarcado manda `"0"`, así que
  // el escaneo **apagaba** la bandera que la pre-alerta acababa de traer — y con
  // ella los motivos. Lo que Yusef pidió el 17-ago llegaba al paquete esperado y
  // se borraba en el momento de recibirlo.
  //
  // Se marca en la pantalla y **no** se fuerza desde el servidor a propósito: el
  // que recibe tiene que poder desmarcarlo si al ver el bulto decide que no. Es
  // la misma decisión que tomó para el aviso del secundario — *"lo va a retener,
  // o lo va a enviar así"*.
  _marcarRetencionDeLaPreAlerta(data) {
    if (!data.retener_miami) return

    const check = this.formTarget.querySelector("input[name='paquete[retener_miami]'][type='checkbox']")
    if (!check || check.checked) return
    check.checked = true

    const ids = (data.motivo_retencion_ids || []).map(String)
    this.formTarget
      .querySelectorAll("input[name='paquete[motivo_retencion_ids][]'][type='checkbox']")
      .forEach(input => { if (ids.includes(String(input.value))) input.checked = true })

    const notas = this.formTarget.querySelector("[name='paquete[notas_retencion]']")
    if (notas && notas.value.trim() === "" && data.notas_retencion) notas.value = data.notas_retencion
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

    // PR: acá vivía una COPIA de lo que hace `_alSeleccionarCliente` — las
    // notas y la franja— y el comentario decía "misma lógica que
    // selectCliente() para mantener consistencia". No lo era: se copiaron las
    // notas y **se olvidó el aviso de sucursal**, así que al escanear un
    // tracking con pre-alerta el operario nunca se enteraba de a qué sucursal
    // iba la caja. Yusef lo reportó dos veces.
    //
    // Ahora los dos caminos —elegir el cliente a mano y que lo traiga la
    // pre-alerta— pasan por el mismo gancho. Lo que se agregue ahí vale para
    // los dos por construcción, no por acordarse.
    this._alSeleccionarCliente({
      id: data.cliente_id,
      notas: data.cliente_notas_miami,
      sucursalRetiro: data.cliente_sucursal_retiro,
      retiroPorDefecto: data.cliente_retiro_por_defecto
    })
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

    // C16-03 · Yusef: "le da Enter y se queda ahí". El overlay tapaba la
    // pantalla pero el cursor seguía en el campo de atrás, así que el Enter
    // siguiente —el de la pistola, o el del operario— caía en el formulario y
    // el modal ni se enteraba. Mismo patrón que el modal de conflicto: el foco
    // va a la opción de siempre, «Es actualización», en el frame siguiente
    // porque esto corre al resolverse el `fetch`.
    if (this.hasDuplicateUpdateBtnTarget) {
      requestAnimationFrame(() => this.duplicateUpdateBtnTarget.focus())
    }
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

  // Opción 2: "Cambio de Servicio" — igual que la de arriba, sin salir de
  // /etiquetar.
  //
  // PR-C6.23. Antes navegaba a `/paquetes/:id?mode=edit&cambio_servicio=1`, y
  // eso es literalmente lo que Yusef reportó:
  //
  //   > "Cambio de servicio **envía donde no es**."
  //   > "Para mí que si hacemos cambio de servicio nada más al producto, nos
  //   >  tire de un solo a esta ventana. Si yo presiono cambio de servicio,
  //   >  **me tire aquí de un solo a esto**."
  //   > "Es que ellos no manejan la página de paquetes."
  //
  // Es la misma queja que ya había hecho por "Es actualización" (PR-C6.10):
  // Miami trabaja en /etiquetar y /paquetes es una pantalla ajena. Quedó a
  // medias porque solo se arregló una de las dos opciones del modal.
  //
  // El `cambio_servicio=1` hace que el index marque el checkbox y abra el
  // modal del tipo de envío destino de una vez — sin un clic de más.
  duplicateAsCambioServicio() {
    const data = this._duplicateData
    if (!data || !data.existing_paquete_id) return
    window.location.href =
      `/etiquetar?paquete_id=${data.existing_paquete_id}&cambio_servicio=1`
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
    // Las cajas cargadas son de ESTE paquete: se van con él.
    this.formTarget.dispatchEvent(new CustomEvent("cajas:limpiar", { bubbles: true }))
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
    if (this.hasConflictoSesionModalTarget) this.conflictoSesionModalTarget.classList.add("hidden")
    if (this.hasTrackingSecundarioContainerTarget) this._hideTrackingSecundario()
    // C16-05: lo demás que era de ESTE paquete y sobrevivía a la limpieza — la
    // cola de avisos pendientes, el aviso abierto y lo que el modal de
    // duplicado tenía cargado. Un aviso en cola es un modal que le sale al
    // paquete siguiente hablando del anterior.
    this._colaDeAvisos = []
    this._avisoActual = null
    this._duplicateData = null
    if (this.hasAvisoModalTarget && this.avisoModalTarget.open) this.avisoModalTarget.close()
    // C19-02: al tracking, que es donde escanea el siguiente. (El branch que
    // prefería `tipoEnvio` era de cuando el form tenía ese select; con la
    // sesión por tipo de envío el target ya no existe en la vista.)
    this._volverAlTracking()
  }

  // C19-02. Yusef: "el cursor… regrese a donde está el [campo de] tracking…
  // se queda como en el aire… ellos ya solo vienen y escanean el siguiente".
  // Y el scroll aparte: "era que se fue para arriba… que se mantenga en el
  // área donde ellos en realidad se mueven".
  //
  // Si el modal rojo de la bolsa está abierto, el resto de la página es
  // inerte y un focus() acá no hace nada — el foco lo devuelve
  // `cerrarSucursalModal()`. El guard de `isConnected` es por el listener de
  // window "focus" del flujo de actualización: `Turbo.visit` reemplaza la
  // página y ese listener puede disparar sobre un controller ya muerto.
  _volverAlTracking() {
    if (!this.element.isConnected) return
    if (this.hasSucursalModalTarget && this.sucursalModalTarget.open) return
    if (this.hasAvisoModalTarget && this.avisoModalTarget.open) return
    if (!this.hasTrackingTarget) return

    this.trackingTarget.focus()
    this.trackingTarget.scrollIntoView({ block: "center" })
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

    // PR-C6.24: y el aviso de sucursal se va con el paquete que lo trajo. Si
    // quedara puesto, el siguiente bulto se guardaría en la bolsa anterior.
    this._mostrarSucursal(null)
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
  //
  // 2026-08-18: y vuelve a preguntar, pero **solo cuando no se midió nada**.
  // Yusef: *"en etiquetar casi nunca medimos y pesamos… cuando la cantidad de
  // cajas guardadas sea cero, que pregunte cuántas son"*. Esa condición es la
  // diferencia con el modal viejo: si hay aunque sea una caja cargada, ella
  // manda y acá no se pregunta nada — nunca hay dos fuentes para el número.
  submitFormWithPrint() {
    if (this._cajasCargadas() > 0) return this._submitWithPrint()
    if (!this.hasEtiquetasModalTarget) return this._submitWithPrint()

    if (this.hasEtiquetasInputTarget) this.etiquetasInputTarget.value = String(this._etiquetasPorDefecto())
    // A1-10: "un pin antes de que salga cualquier modal". El operario está
    // mirando la pistola, no la pantalla — un modal mudo se lo pierde.
    this.dispatch("modalAbierto")
    this.etiquetasModalTarget.showModal()
    // `select()` y no solo `focus()`: el operario teclea el número encima sin
    // tener que borrar el 1.
    if (this.hasEtiquetasInputTarget) this.etiquetasInputTarget.select()
  }

  // Con qué número arranca el modal.
  //
  // Al dar de alta, 1. **Al actualizar, las que el paquete ya tiene**: con el 1
  // de siempre, abrir un envío de tres cajas y darle Enter lo bajaría a una, y
  // `ajustar_split!` borra las sobrantes sin preguntar —el PIN de supervisor
  // solo cuida las que ya se cobraron—. Yusef estaba subiendo de 3 a 5; bajar
  // estaba a un Enter de distancia.
  _etiquetasPorDefecto() {
    const actuales = this.hasCajasActualesValue ? this.cajasActualesValue : 0
    return actuales > 1 ? actuales : 1
  }

  // Cuántas filas de caja hay cargadas. Se cuentan las filas y no un contador
  // aparte: es la misma fuente que usa `cajas-repetidor#_renumerar`, y la
  // lección de `PR-C6.31` es que dos fuentes para el mismo número terminan
  // discrepando.
  _cajasCargadas() {
    const filas = this.formTarget.querySelectorAll(".caja-fila").length
    return filas + this._cajaTecleadaSinAgregar()
  }

  // C18-05 · Yusef, 2026-08-26: *"yo puse que eran dos cajas… y me tiró siempre
  // la pregunta"*. Tecleó peso y medidas arriba sin darle «Agregar» —la
  // pantalla misma le dice que no hace falta— y el repetidor agrega esa caja
  // recién al enviar (`_agregarPendiente`), después de que acá ya se decidió
  // preguntar. Si hay peso tecleado, esa caja cuenta. Solo al dar de alta: al
  // actualizar el campo viene pre-llenado con el peso del paquete, y ahí el
  // modal se queda a propósito (es donde se cambia la cantidad).
  _cajaTecleadaSinAgregar() {
    if (this.hasActualizandoIdValue && this.actualizandoIdValue) return 0

    const captura = this.formTarget.querySelector("[data-caja-campo='peso']")
    return captura && captura.value.trim() !== "" ? 1 : 0
  }

  // Enter confirma; Escape cancela. Ojo: acá Enter **sí** actúa, al revés que
  // en el formulario —donde la pistola dispara Enter y por eso Enter pasa al
  // campo siguiente—. El modal no es el formulario: no hay campo siguiente y
  // el operario ya decidió imprimir.
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

  cerrarEtiquetas() {
    this.etiquetasModalTarget.close()
  }

  // Un número mal tecleado no puede grabar 500 paquetes ni tirar 500 etiquetas.
  // El servidor lo acota igual; esto es para que el operario se entere acá.
  _etiquetasPedidas() {
    if (!this.hasEtiquetasInputTarget) return 1
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

    // Va suelto y NO como `paquete[cantidad_paquetes]`: el bug de `PR-C6.31`
    // fue tener dos campos con el mismo `name` —ganaba el último y el split se
    // caía en silencio—. Con un nombre propio no hay con quién chocar.
    //
    // C20-04: y va SIEMPRE que el operario haya contestado, incluido el 1.
    // Con el `> 1` de antes, confirmar «1» no mandaba nada: el servidor no
    // recibía cantidad, no ajustaba el split, y el paquete seguía en tres
    // cajas mientras la pantalla decía "actualizado" y salían tres etiquetas.
    // Bajar un envío a una sola caja era **inexpresable** — justo el caso que
    // Yusef describió: *"ese celular hay que devolverlo, entonces ya pasa de
    // ser 3 a 2"*, y de 2 a 1 igual.
    //
    // Al dar de alta `etiquetas=1` es lo mismo que no mandarlo
    // (`etiquetas_pedidas` contesta 1 cuando falta), así que ese camino no
    // cambia. Y el modal arranca en la cantidad actual, así que un Enter sin
    // tocar nada manda N==actual y el servidor no ajusta nada.
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
  // el campo de la cantidad, son dos los que hay que limpiar. Con el singular,
  // el segundo sobrevivía al guardado y el paquete siguiente heredaba la
  // cantidad del anterior — exactamente el bug de `PR-C6.31`, otra vez.
  _removePrintField() {
    this.formTarget.querySelectorAll("[data-print-field]").forEach(el => el.remove())
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
        // C19-02: la pestaña de impresión se lleva el foco de la ventana; al
        // cerrarse (afterprint → window.close) la ventana vuelve, y acá se
        // vuelve al tracking. {once}: es un viaje por impresión.
        window.addEventListener("focus", () => this._volverAlTracking(), { once: true })
        // PR-C6.24: el segundo aviso, con la etiqueta ya en la mano.
        this._avisarSucursalAlFinal()
      }

      // Al actualizar un paquete existente no alcanza con limpiar los campos:
      // el `form` viene del servidor apuntando a `PATCH /etiquetar/:id`, y
      // `clearForm` no toca la acción. El paquete siguiente se guardaría
      // **encima del anterior**, y el banner de "Actualizando …" quedaba en
      // pantalla diciéndolo — Jorge lo vio por el banner.
      //
      // Volver a `/etiquetar` deja la pantalla en modo alta, que es donde tiene
      // que estar para el siguiente escaneo. La sesión de etiquetado vive en el
      // server, así que no se pierde.
      if (el.dataset.volver === "true") {
        el.remove()
        // Después de la ventana de impresión: si se navega antes, el navegador
        // puede cancelarla.
        setTimeout(() => Turbo.visit(window.location.pathname), 150)
        return
      }

      // Clear form after successful save
      setTimeout(() => this.clearForm(), 100)
      el.remove()
    }
  }
}
