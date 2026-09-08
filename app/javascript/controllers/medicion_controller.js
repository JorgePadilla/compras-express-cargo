import { Controller } from "@hotwired/stimulus"
import { conEnterAvanza } from "controllers/enter_avanza"

// C26-02/19 · La estación de Medición (San Pedro).
//
// Se escanea el warehouse receipt de la etiqueta de Miami y la pantalla
// contesta con **el grupo**, no con una caja: lo que declaró el cliente, cómo
// lo ingresó Miami, y la grilla de cuadritos con lo que está y lo que falta.
//
// C27-01 · Y desde el bulto, la unidad de la pantalla ya no es la caja: es
// **la medición**. Yusef, el 2026-09-07, tres veces en la misma reunión:
//
//   "No es una etiqueta por paquete, es una etiqueta por medición, y la
//    medición puede tener 100 paquetes."
//
// El operario junta cajas en la mesa hasta que le cuadran y mide el bulto
// entero, porque *"si yo mido esto [caja por caja], te estoy cobrando espacio
// vacío"*. La mesa se arma **escaneando**, nunca eligiendo de una lista:
//
//   — "¿Cómo los unís? ¿En pantalla, cómo te imaginás?"
//   — "No, no, porque se van a equivocar. Eso es un error ya. No van a leer."
//   — "¿Entonces cómo los unís?"
//   — "Escaneando. Escaneando cada uno."
//
// Por eso el foco se queda en el campo de escaneo después de un pip bueno, y
// no salta al peso como antes: el gesto normal es pip, pip, pip.
//
// Mismo esqueleto que /empacar: la pistola dispara Enter, cada resultado suena
// distinto, y el guard `_seq` evita que una respuesta vieja pinte por una caja
// que ya no está en pantalla. Los `dispatch` van con el nombre literal, uno por
// rama, para que `sonidos_cableados_test` los pueda leer del archivo; y el
// `showModal()` va en el mismo método que el `dispatch`, que es lo que el lint
// exige.
export default class extends conEnterAvanza(Controller) {
  static targets = [
    "codigo", "aviso",
    "dosLados", "panelPreAlerta", "paNumero", "paTitulo", "paDetalle", "paBanderas", "paNotas",
    "panelMiami", "miamiWr", "miamiDetalle", "miamiDescripcion", "miamiRetenido",
    "grupo", "grupoTitulo", "grupoSello", "grilla", "plantillaCuadrito", "facturarParcial",
    "panel", "codigoCaja", "tracking", "caja", "cliente", "tipoEnvio", "descripcion", "previa",
    "mesa", "plantillaMesa", "mesaTitulo", "mesaCliente", "quitarUltima",
    "acciones", "volumenesContador", "volumenesVacio", "listaVolumenes", "plantillaVolumen",
    "quitarVolumen", "agregarVolumen",
    "form", "peso", "alto", "largo", "ancho", "guardar", "guardarTexto", "reimprimir", "reimprimirTexto",
    "banner", "bannerTexto", "bannerReimprimir", "bannerReimprimirTexto",
    "manifiestoNumero", "manifiestoFechas", "manifiestoConteo", "pendientes", "sinPendientes",
    "plantillaPendiente", "descarteModal", "descarteCaja", "descarteMotivo", "descarteNota",
    "descarteError", "confirmarDescarte",
    "problemaModal", "problemaTitulo", "problemaTexto", "problemaEntendido", "medirDeNuevo",
    "reimprimirBulto", "medirIgual",
    "mezclaModal", "mezclaTitulo", "mezclaTexto", "mezclaQuitar",
    "consolidadoModal", "consolidadoTitulo", "consolidadoTexto", "consolidadoPreAlerta",
    "consolidadoPreFactura", "hacerConsolidado",
    "excepcionModal", "excepcionFaltantes", "excepcionError", "confirmarParcial"
  ]
  static values = {
    escanearUrl: String, guardarUrl: String, panelUrl: String,
    etiquetaUrlTemplate: String, clases: Object, maximo: Number
  }

  connect() {
    this._seq = 0
    this._paquete = null
    this._grupo = null
    // La mesa: las cajas del volumen que se está armando, en el orden en que
    // entraron. Los volúmenes: las mediciones ya agregadas de esta tanda.
    // Nada de esto vive en el servidor hasta F10 — `MedirBulto` recibe la
    // tanda entera de un saque, porque el «1 de 2» del QR necesita saber
    // cuántas mediciones son antes de imprimir la primera.
    this._mesa = []
    this._volumenes = []
    // C27-14 · Las cajas que alguien autorizó a medir sin manifiesto. Se
    // mandan al guardar y el servidor las sella una por una.
    this._saltados = []
    // F10 guarda, F9 reimprime, F5 agrega volumen, F2 limpia — escuchando en
    // `document`, porque el atajo global ignora las F-keys cuando el foco está
    // en un input, y acá siempre está.
    this._teclaGlobal = this.teclaGlobal.bind(this)
    document.addEventListener("keydown", this._teclaGlobal)
    // Al cerrarse cualquier modal, el foco vuelve a donde toca, un frame
    // después: en el mismo tick el `open` todavía no se fue.
    this._alCerrarse = () => requestAnimationFrame(() => this._enfocarDondeToca())
    this.element.addEventListener("close", this._alCerrarse, true)
    if (this.hasCodigoTarget) this.codigoTarget.focus()
    // C26-17 · El panel de la derecha arranca con el último manifiesto que
    // todavía tiene algo que medir, para que la pantalla no abra vacía.
    this._fetch("GET", this.panelUrlValue)
      .then((r) => r.json())
      .then((data) => this._pintarManifiesto(data.manifiesto))
      .catch(() => {})
  }

  disconnect() {
    document.removeEventListener("keydown", this._teclaGlobal)
    this.element.removeEventListener("close", this._alCerrarse, true)
  }

  // ── Escanear ────────────────────────────────────────────────────────────

  teclado(e) {
    if (e.key !== "Enter") return
    e.preventDefault()
    const codigo = this.codigoTarget.value.trim()
    this.codigoTarget.value = ""
    // Enter con el campo vacío es la salida al peso: el foco se queda acá
    // mientras se arma la mesa, así que hace falta una forma de salir sin
    // levantar la mano del teclado. En la pantalla táctil se toca el campo.
    if (!codigo) { this._enfocarPeso(); return }
    this._escanear(codigo)
  }

  // Tocar un cuadrito que ya llegó es lo mismo que escanearlo: el operario
  // tiene las tres cajas enfrente y no siempre quiere levantar la pistola.
  elegirCaja(e) {
    const wr = e.currentTarget.dataset.wr
    if (wr) this._escanear(wr)
  }

  _escanear(codigo, { saltarManifiesto = false } = {}) {
    if (!codigo) return

    const consulta = (this._seq += 1)
    // `en_tanda` es **toda** la tanda, mesa y volúmenes: «NO Mezclar» es de la
    // sesión entera y no de cada medición. Mirando solo la mesa, la caja de
    // otro cliente entraría en el volumen 2 sin chistar y el error saldría
    // recién en F10, con el volumen 1 ya medido.
    this._post(this.escanearUrlValue,
               { codigo, en_tanda: this._idsDeLaTanda(), saltar_manifiesto: saltarManifiesto })
      .then((data) => {
        if (consulta !== this._seq) return  // llegó tarde: habla de otro escaneo
        this._resolver(data)
      })
      .catch(() => this._problema("No se pudo consultar", "Probá de nuevo."))
  }

  _idsDeLaTanda() {
    return [...this._volumenes.flatMap((v) => v.paquete_ids), ...this._mesa.map((p) => p.id)]
  }

  _resolver(data) {
    if (data.resultado === "no_mezclar") { this._noMezclar(data); return }
    if (data.resultado === "ya_tiene_bulto") { this._yaTieneBulto(data); return }
    if (data.puede_saltar) { this._sinManifiesto(data); return }
    if (data.resultado !== "ok" && data.resultado !== "pre_alerta_ya_facturada") {
      this._problema(this._titulo(data.resultado), data.mensaje)
      return
    }

    // La caja entra a la mesa. Es lo único que agrega cajas: no hay checkbox
    // ni lista de dónde elegir.
    this._mesa.push({ ...data.paquete, salto_manifiesto: data.salto_manifiesto })
    if (data.salto_manifiesto) this._saltados.push(data.paquete.id)
    this._pintar(data)

    if (data.resultado === "pre_alerta_ya_facturada") {
      // Se avisa y se deja medir: esa caja se factura aparte.
      this._problema("Pre-alerta ya facturada", data.mensaje)
    } else if (data.medicion_previa) {
      // Medida con el camino viejo —`MedirPaquete`, sin bulto—. Se avisa y se
      // queda en la mesa: el número del bulto es el que va a mandar.
      this.dispatch("yaMedido")
      this._llenarProblema("Ya medida antes", `Medida el ${data.medicion_previa.fecha} por ${data.medicion_previa.por}: ` +
        `${data.medicion_previa.peso} lb · ${data.medicion_previa.medidas}. Entró a la mesa igual.`, { medirDeNuevo: true })
      this.problemaModalTarget.showModal()
      requestAnimationFrame(() => this.problemaEntendidoTarget.focus())
    } else if (data.grupo && !data.grupo.completo) {
      this.dispatch("unir")
    } else {
      this.dispatch("ok")
    }
  }

  _titulo(resultado) {
    return {
      no_encontrado: "No se encontró",
      ambiguo: "Escaneá la caja, no el tracking",
      en_pre_factura: "Ya está en una pre-factura",
      no_esta_en_honduras: "Todavía no se recibió"
    }[resultado] || "Problema"
  }

  // ── «NO Mezclar»: los dos modales que pidió Yusef ───────────────────────

  _noMezclar(data) {
    if (data.motivo === "otro_cliente" || data.motivo === "otro_servicio") {
      this._mezcla(data)
    } else if (data.motivo === "otra_consolidacion" || data.motivo === "no_consolidada") {
      this._consolidado(data)
    } else {
      // "repetida": no hay nada que decidir, es un pip de más.
      this._problema("Esa caja ya está en la mesa", data.mensaje)
    }
  }

  // Yusef: *"escanea uno de Jorge y va y escanea otro y ese no es el mismo
  // Jorge… le tira error, es diferente cliente… ¿desea eliminar este último o
  // empezar todo de nuevo?"*. Las dos salidas son las de él.
  _mezcla(data) {
    this.dispatch("mezcla")
    this.mezclaTituloTarget.textContent = data.motivo === "otro_cliente" ? "Es otro cliente" : "Es otro servicio"
    this.mezclaTextoTarget.textContent = data.mensaje
    this.mezclaModalTarget.showModal()
    requestAnimationFrame(() => this.mezclaQuitarTarget.focus())
  }

  // Yusef: *"ese está consolidando con tal pre-alerta, con tal número. Ese va
  // amarrado con otra"* — *"¿desea procesar el consolidado o lo va a poner a un
  // lado para terminar el que está haciendo?"*.
  _consolidado(data) {
    this.dispatch("consolidado")
    const choque = data.choque || {}
    this._consolidada = data.paquete
    this.consolidadoTituloTarget.textContent = data.motivo === "otra_consolidacion"
      ? "Está consolidando con otra pre-alerta"
      : "Ésta no está consolidando"
    this.consolidadoTextoTarget.textContent = data.mensaje
    this.consolidadoPreAlertaTarget.textContent = [choque.numero, choque.titulo].filter(Boolean).join(" · ")
    this.consolidadoPreFacturaTarget.classList.toggle("hidden", !choque.pre_factura)
    if (choque.pre_factura) {
      this.consolidadoPreFacturaTarget.textContent = `Ese consolidado ya tiene la pre-factura ${choque.pre_factura}.`
    }
    this.consolidadoModalTarget.showModal()
    requestAnimationFrame(() => this.hacerConsolidadoTarget.focus())
  }

  // «Quitar el último escaneado»: la caja rechazada nunca entró a la mesa, así
  // que esto es cerrar y seguir con lo que hay. Es lo que Yusef describe: él se
  // la imagina en la lista, y lo que pide es que no quede.
  mezclaQuitarUltimo() { this.mezclaModalTarget.close() }

  mezclaEmpezarDeNuevo() {
    this._vaciarTanda()
    this.mezclaModalTarget.close()
  }

  // «Lo dejo de lado» → *"no lo va a guardar, lo pone a un lado"*. No hay cola
  // de apartados ni nada que persistir: la caja no entró, se sigue con la mesa
  // como estaba y el foco vuelve al escaneo. Yusef: *"este es como un F2"*.
  dejarDeLado() { this.consolidadoModalTarget.close() }

  // «Hago el consolidado» → *"tiene que eliminar este del listado que escaneó,
  // porque ese no va a ir en la medición"*. Se vacía **la tanda entera** y no
  // solo la mesa: «NO Mezclar» corre sobre toda la sesión, así que un volumen
  // ya agregado de cajas sueltas dejaría la tanda imposible de guardar.
  // Después se vuelve a escanear la consolidada, que ahora es la primera.
  hacerConsolidado() {
    const codigo = this._consolidada && (this._consolidada.codigo || this._consolidada.tracking)
    this._vaciarTanda()
    this.consolidadoModalTarget.close()
    if (codigo) this._escanear(codigo)
  }

  // El modal rojo grande.
  _problema(titulo, texto) {
    this.dispatch("problema")
    this._llenarProblema(titulo, texto, {})
    this.problemaModalTarget.showModal()
    requestAnimationFrame(() => this.problemaEntendidoTarget.focus())
  }

  // C27-14 · El estado no bloquea: avisa y deja pasar. Yusef, mirando el
  // bloqueo en vivo: *"le tiene que eliminar eso porque nos va a llevar putas,
  // porque a más de alguno se le va a escapar. **Hay que poner una opción
  // ahí.**"* El modal rojo se queda —la caja de verdad no pasó por aduana— y le
  // crece una puerta.
  _sinManifiesto(data) {
    this.dispatch("problema")
    this._paraSaltar = data.paquete
    this._llenarProblema(this._titulo(data.resultado), data.mensaje, { medirIgual: true })
    this.problemaModalTarget.showModal()
    requestAnimationFrame(() => this.problemaEntendidoTarget.focus())
  }

  // Se vuelve a escanear con el permiso puesto: así la caja entra a la mesa por
  // el mismo camino que las demás, con su grupo y su manifiesto pintados.
  medirIgual() {
    const codigo = this._paraSaltar && (this._paraSaltar.codigo || this._paraSaltar.tracking)
    this.problemaModalTarget.close()
    if (codigo) this._escanear(codigo, { saltarManifiesto: true })
  }

  // C27-09 · Una caja que ya tiene bulto no se vuelve a medir: se reimprime.
  // Yusef: *"si se le cae… tendría que volver a escanear el warehouse"*.
  _yaTieneBulto(data) {
    this.dispatch("yaMedido")
    this._bultoParaReimprimir = data.bulto && data.bulto.etiqueta_url
    this._llenarProblema("Esta caja ya está medida", data.mensaje, { reimprimir: true })
    this.problemaModalTarget.showModal()
    requestAnimationFrame(() => this.problemaEntendidoTarget.focus())
  }

  _llenarProblema(titulo, texto, { medirDeNuevo = false, reimprimir = false, medirIgual = false }) {
    this.problemaTituloTarget.textContent = titulo
    this.problemaTextoTarget.textContent = texto
    this.medirDeNuevoTarget.classList.toggle("hidden", !medirDeNuevo)
    this.reimprimirBultoTarget.classList.toggle("hidden", !reimprimir)
    this.medirIgualTarget.classList.toggle("hidden", !medirIgual)
  }

  avisoEntendido() { this.problemaModalTarget.close() }

  medirDeNuevo() {
    this._volverAPeso = true
    this.problemaModalTarget.close()
  }

  reimprimirBulto() {
    this.problemaModalTarget.close()
    if (this._bultoParaReimprimir) this._imprimir(this._bultoParaReimprimir, 1)
  }

  // C20-13 · Escape no contesta un aviso: *"ellos no las leen"*.
  avisoCancelar(e) { e.preventDefault() }

  // ── Pintar ──────────────────────────────────────────────────────────────

  _pintar(data) {
    this._paquete = data.paquete
    const p = data.paquete
    this.codigoCajaTarget.textContent = p.codigo
    this.trackingTarget.textContent = p.tracking
    this.cajaTarget.textContent = p.caja ? `caja ${p.caja}` : ""
    this.clienteTarget.textContent = p.cliente || ""
    this.tipoEnvioTarget.textContent = p.tipo_envio || ""
    this.descripcionTarget.textContent = p.descripcion || ""
    this.previaTarget.classList.toggle("hidden", !data.medicion_previa)
    if (data.medicion_previa) {
      this.previaTarget.textContent = `Ya medida el ${data.medicion_previa.fecha} por ${data.medicion_previa.por}: ` +
        `${data.medicion_previa.peso} lb · ${data.medicion_previa.medidas}`
    }
    // Los números de Miami solo se copian con la **primera** caja de la mesa:
    // a partir de la segunda pisarían lo que el operario ya tecleó, y el peso
    // que vale es el del bulto entero.
    if (this._mesa.length <= 1) {
      this.pesoTarget.value = p.peso || ""
      this.altoTarget.value = p.alto || ""
      this.largoTarget.value = p.largo || ""
      this.anchoTarget.value = p.ancho || ""
    }

    this._pintarDosLados(data.pre_alerta, data.miami)
    this._pintarGrupo(data.grupo)
    this._pintarManifiesto(data.manifiesto)
    this._repintar()
    this.bannerTarget.classList.add("hidden")
    this.formTarget.querySelectorAll("input").forEach((i) => i.dispatchEvent(new Event("input", { bubbles: true })))
  }

  // Los dos lados del dato: lo que el cliente declaró y lo que Miami ingresó.
  // Pueden no coincidir, y esa diferencia es justamente la información.
  _pintarDosLados(preAlerta, miami) {
    this.panelPreAlertaTarget.classList.toggle("hidden", !preAlerta)
    if (preAlerta) {
      this.paNumeroTarget.textContent = preAlerta.numero
      this.paTituloTarget.textContent = preAlerta.titulo || ""
      const detalle = [preAlerta.proveedor, preAlerta.tipo_envio,
                       `${preAlerta.trackings} tracking${preAlerta.trackings === 1 ? "" : "s"}`].filter(Boolean)
      this.paDetalleTarget.textContent = detalle.join(" · ")
      const banderas = []
      if (preAlerta.consolidado) banderas.push("Pidió consolidar")
      if (preAlerta.con_reempaque) banderas.push("con reempaque")
      this.paBanderasTarget.textContent = banderas.join(" · ")
      this.paNotasTarget.textContent = preAlerta.notas || ""
    }

    this.panelMiamiTarget.classList.toggle("hidden", !miami)
    if (miami) {
      this.miamiWrTarget.textContent = miami.wr
      const detalle = [miami.recibido && `recibido ${miami.recibido}`, miami.por && `por ${miami.por}`,
                       miami.tipo_envio, miami.caja && `caja ${miami.caja}`].filter(Boolean)
      this.miamiDetalleTarget.textContent = detalle.join(" · ")
      this.miamiDescripcionTarget.textContent = miami.descripcion || ""
      this.miamiRetenidoTarget.classList.toggle("hidden", !miami.retenido)
    }
    this.dosLadosTarget.classList.toggle("hidden", !preAlerta && !miami)
  }

  // La grilla de cuadritos: uno por caja, con su estado.
  _pintarGrupo(grupo) {
    this._grupo = grupo
    this.grupoTarget.classList.toggle("hidden", !grupo)
    if (!grupo) return

    this.grupoTituloTarget.textContent = grupo.consolidada
      ? `UNIR · ${grupo.numero} · ${grupo.medidas} de ${grupo.total} medidas`
      : `Viene partido en ${grupo.total} cajas · ${grupo.medidas} medidas`
    this.grupoSelloTarget.textContent = grupo.parcial_autorizado
      ? `Se facturó incompleto el ${grupo.parcial_autorizado.fecha} por ${grupo.parcial_autorizado.por}`
      : ""

    this.grillaTarget.replaceChildren(...grupo.cajas.map((c) => this._cuadrito(c)))

    const forzable = !grupo.completo && !grupo.cerrada && !grupo.parcial_autorizado && grupo.facturar_parcial_url
    this.facturarParcialTarget.classList.toggle("hidden", !forzable)
  }

  _cuadrito(caja) {
    const nodo = this.plantillaCuadritoTarget.content.firstElementChild.cloneNode(true)
    const clases = this.clasesValue
    nodo.dataset.wr = caja.wr || ""
    nodo.dataset.estado = caja.estado
    nodo.disabled = !caja.medible
    // La seleccionada **reemplaza** las clases del estado en vez de sumarse:
    // dos `bg-` en el mismo elemento las resuelve el orden del CSS, no el del
    // atributo, así que sumarlas daba un resultado a medias. Jorge: *"la
    // seleccionada no se ve tan marcada"*.
    nodo.className += ` ${caja.seleccionada ? clases.seleccionada : (clases[caja.estado] || "")}`
    nodo.setAttribute("aria-label",
                      `${caja.wr || caja.tracking}: ${caja.seleccionada ? "midiendo esta" : caja.donde}`)
    nodo.querySelector("[data-campo=marca]").textContent = caja.seleccionada ? "MIDIENDO" : ""
    nodo.querySelector("[data-campo=wr]").textContent = caja.wr || caja.tracking
    nodo.querySelector("[data-campo=caja]").textContent = caja.caja || ""
    nodo.querySelector("[data-campo=estado]").textContent = caja.donde
    // C27-12 · Yusef, mirando este panel: *"lo que hace falta aquí es poner
    // **quién ingresó las medidas**"*. El dato ya venía en el JSON y se caía
    // acá al piso.
    nodo.querySelector("[data-campo=peso]").textContent =
      [caja.peso ? `${Number(caja.peso).toFixed(2)} lb` : "", caja.por].filter(Boolean).join(" · ")
    return nodo
  }

  // ── La mesa y los volúmenes ─────────────────────────────────────────────

  _repintar() {
    this._pintarMesa()
    this._pintarVolumenes()
    this._textoDeLosBotones()
  }

  _pintarMesa() {
    const n = this._mesa.length
    this.mesaTituloTarget.textContent =
      `Volumen ${this._volumenes.length + 1} · ${n} ${n === 1 ? "caja" : "cajas"} en la mesa`
    this.mesaClienteTarget.textContent = (this._mesa[0] && this._mesa[0].cliente) || ""
    this.mesaTarget.replaceChildren(...this._mesa.map((p, i) => this._filaMesa(p, i)))
    this.quitarUltimaTarget.classList.toggle("hidden", n === 0)
    this.panelTarget.classList.toggle("hidden", n === 0)
  }

  _filaMesa(p, i) {
    const nodo = this.plantillaMesaTarget.content.firstElementChild.cloneNode(true)
    nodo.dataset.paqueteId = p.id
    nodo.querySelector("[data-campo=orden]").textContent = i + 1
    nodo.querySelector("[data-campo=wr]").textContent = p.codigo || p.tracking
    nodo.querySelector("[data-campo=detalle]").textContent =
      [p.tipo_envio, p.caja && `caja ${p.caja}`,
       p.salto_manifiesto && "SIN MANIFIESTO", p.descripcion].filter(Boolean).join(" · ")
    return nodo
  }

  _pintarVolumenes() {
    const n = this._volumenes.length
    this.volumenesContadorTarget.textContent = n
    this.volumenesVacioTarget.classList.toggle("hidden", n > 0)
    this.quitarVolumenTarget.classList.toggle("hidden", n === 0)
    this.listaVolumenesTarget.replaceChildren(...this._volumenes.map((v, i) => this._filaVolumen(v, i)))
    this.accionesTarget.classList.toggle(
      "hidden", n === 0 && this._mesa.length === 0 && !this._ultimaEtiquetaUrl)
  }

  _filaVolumen(v, i) {
    const nodo = this.plantillaVolumenTarget.content.firstElementChild.cloneNode(true)
    nodo.querySelector("[data-campo=orden]").textContent = `Volumen ${i + 1}`
    const medidas = [v.alto, v.largo, v.ancho].filter(Boolean).join("x")
    nodo.querySelector("[data-campo=numeros]").textContent =
      [v.peso && `${v.peso} lb`, medidas && `${medidas} in`].filter(Boolean).join(" · ")
    const c = v.paquete_ids.length
    nodo.querySelector("[data-campo=cajas]").textContent = `${c} ${c === 1 ? "caja" : "cajas"}`
    return nodo
  }

  // C26-04/19 · Los botones dicen lo que **va a pasar**. Jorge: *"veo «Guardar
  // e imprimir»… «Reimprimir etiqueta», no sé si solo hace una, ¿cuál hace?"*.
  // Con tres volúmenes salen tres etiquetas, y prometer una sería mentir.
  _textoDeLosBotones() {
    const total = this._volumenes.length + (this._mesa.length > 0 ? 1 : 0)
    this.guardarTextoTarget.textContent = total > 1
      ? `Guardar e imprimir ${total} etiquetas`
      : "Guardar e imprimir"
  }

  // La única forma de sacar algo de la mesa: la última. No hay lista de dónde
  // elegir — *"no, no, porque se van a equivocar… no van a leer"*.
  quitarUltimaCaja() {
    if (this._modalAbierto() || this._mesa.length === 0) return

    this._mesa.pop()
    if (this._mesa.length === 0) {
      this._pintarGrupo(null)
      this.dosLadosTarget.classList.add("hidden")
    }
    this._repintar()
    this.codigoTarget.focus()
  }

  quitarUltimoVolumen() {
    if (this._modalAbierto() || this._volumenes.length === 0) return

    this._volumenes.pop()
    this._repintar()
    this.codigoTarget.focus()
  }

  // ── Agregar un volumen ──────────────────────────────────────────────────
  //
  // Yusef: *"mide y pesa este, le da **agregar**; mide y pesa este por separado
  // porque no cuadra… y ahí le dice **imprimir**, y como son dos mediciones,
  // imprime dos"*. El operario les dice «volúmenes»: *"le voy a sacar tres
  // volúmenes, así lo dicen ellos, porque son diferentes de tamaño"*.
  agregarVolumen() {
    if (this._modalAbierto()) return
    if (this._mesa.length === 0) {
      this._problema("La mesa está vacía", "Escaneá las cajas de este volumen antes de agregarlo.")
      return
    }
    if (this._volumenes.length >= this.maximoValue) {
      // C27-03 · El techo es de Yusef: *"máximo 10 warehouse, máximo 10 etiquetas… el
      // normal de nosotros es 2 a 3; 5 ya es demasiado"*. Se avisa acá y el
      // servidor lo vuelve a mirar en `MedirBulto`.
      this._problema("Son demasiados volúmenes",
                     `De una tanda salen ${this.maximoValue} mediciones como mucho. ` +
                     "Guardá e imprimí lo que llevás y seguí con la siguiente.")
      return
    }
    const numeros = this._numeros()
    if (!this._tieneNumeros(numeros)) {
      this._problema("Falta pesarlo", "Poné al menos el peso, o las tres medidas, antes de agregar el volumen.")
      return
    }

    this._volumenes.push({ ...numeros, paquete_ids: this._mesa.map((p) => p.id) })
    this._mesa = []
    this._limpiarNumeros()
    this._pintarGrupo(null)
    this.dosLadosTarget.classList.add("hidden")
    this.dispatch("guardado")
    this._repintar()
    this.codigoTarget.focus()
  }

  _numeros() {
    return { peso: this.pesoTarget.value.trim(), alto: this.altoTarget.value.trim(),
             largo: this.largoTarget.value.trim(), ancho: this.anchoTarget.value.trim() }
  }

  _tieneNumeros(n) {
    return [n.peso, n.alto, n.largo, n.ancho].some((v) => Number(v) > 0)
  }

  // ── Guardar ─────────────────────────────────────────────────────────────

  guardar() {
    if (this._modalAbierto()) return

    const mediciones = this._volumenes.map((v) => ({ paquete_ids: v.paquete_ids, peso: v.peso,
                                                     alto: v.alto, largo: v.largo, ancho: v.ancho }))
    // Lo que quedó en la mesa entra como el último volumen: Yusef no dice
    // «agregar» para el último — *"mide y pesa este por separado… y ahí le dice
    // imprimir"*.
    if (this._mesa.length > 0) {
      mediciones.push({ paquete_ids: this._mesa.map((p) => p.id), ...this._numeros() })
    }
    if (mediciones.length === 0) {
      this._problema("No hay nada que guardar", "Escaneá las cajas del bulto y poné el peso.")
      return
    }

    this._post(this.guardarUrlValue, { mediciones, saltar_manifiesto: this._saltados }, { conEstado: true })
      .then(({ ok, data }) => {
        if (!ok) {
          this.dispatch("fallo")
          this._llenarProblema("No se guardó", (data.errores || []).join(" "), {})
          this.problemaModalTarget.showModal()
          requestAnimationFrame(() => this.problemaEntendidoTarget.focus())
          return
        }

        this.dispatch("guardado")
        this._pintarManifiesto(data.manifiesto)
        this.avisoTarget.textContent = data.mensaje
        // La tanda terminó: la pantalla se limpia para la siguiente y el banner
        // guarda el resultado. Jorge: *"cuando se facture o se termine de
        // imprimir se debería limpiar para que se comience con el siguiente"*.
        this._terminar(data.mensaje, data.imprimir_url, data.cantidad)
      })
  }

  // ── El panel de la derecha: lo que falta de este manifiesto ─────────────

  _pintarManifiesto(m) {
    if (!m) return

    this.manifiestoNumeroTarget.textContent = [m.numero, m.guia && `guía ${m.guia}`].filter(Boolean).join(" · ")
    this.manifiestoFechasTarget.textContent = [
      m.enviado && `Salió de Miami el ${m.enviado}`,
      m.recibido && `recibido el ${m.recibido}`
    ].filter(Boolean).join(" · ")
    // El match con lo que Miami dijo que mandó.
    const partes = [`Miami mandó ${m.enviados}`, `medidos ${m.medidos}`]
    if (m.descartados > 0) partes.push(`sacados ${m.descartados}`)
    partes.push(`faltan ${m.faltan}`)
    this.manifiestoConteoTarget.textContent = partes.join(" · ")

    this.pendientesTarget.replaceChildren(...m.pendientes.map((p) => this._renglon(p, m.puede_descartar)))
    this.sinPendientesTarget.classList.toggle("hidden", m.pendientes.length > 0)
  }

  _renglon(pendiente, puedeDescartar) {
    const nodo = this.plantillaPendienteTarget.content.firstElementChild.cloneNode(true)
    nodo.dataset.paqueteId = pendiente.id
    nodo.dataset.descartarUrl = pendiente.descartar_url
    nodo.dataset.wr = pendiente.wr || ""
    if (pendiente.midiendo) nodo.classList.add("bg-cec-gold/15")
    if (!pendiente.aqui) nodo.classList.add("opacity-60")

    nodo.querySelector("[data-campo=wr]").textContent =
      [pendiente.wr, pendiente.caja && `caja ${pendiente.caja}`].filter(Boolean).join(" · ")
    nodo.querySelector("[data-campo=cliente]").textContent = pendiente.cliente || ""
    const donde = nodo.querySelector("[data-campo=donde]")
    donde.textContent = pendiente.donde
    donde.classList.add(pendiente.aqui ? "text-gray-500" : "text-amber-800")

    // C26-17 · Los que vienen consolidados se ven sin escanearlos.
    const unir = nodo.querySelector("[data-campo=unir]")
    unir.classList.toggle("hidden", !pendiente.unir)
    if (pendiente.unir) unir.textContent = `UNIR · ${pendiente.unir}`

    // Sacar de la lista es de administración y de nadie más.
    nodo.querySelector("button").classList.toggle("hidden", !puedeDescartar)
    return nodo
  }

  // ── Sacar una caja de la lista ──────────────────────────────────────────

  abrirDescarte(e) {
    // Suena aunque lo abra un clic y no la pistola: la regla de las pantallas
    // de escaneo es que ningún modal se abra mudo, y acá el operario puede
    // estar mirando la caja y no la pantalla.
    this.dispatch("atencion")
    const fila = e.currentTarget.closest("li")
    this._descartando = fila.dataset.descartarUrl
    this.descarteCajaTarget.textContent = fila.dataset.wr
    this.descarteNotaTarget.value = ""
    this.descarteErrorTarget.classList.add("hidden")
    this.descarteModalTarget.showModal()
    requestAnimationFrame(() => this.confirmarDescarteTarget.focus())
  }

  cerrarDescarte() { this.descarteModalTarget.close() }

  confirmarDescarte() {
    if (!this._descartando) return

    const motivo = this.descarteMotivoTargets.find((r) => r.checked)?.value
    this._post(this._descartando, { motivo: motivo, nota: this.descarteNotaTarget.value }, { conEstado: true })
      .then(({ ok, data }) => {
        if (!ok) {
          this.dispatch("fallo")
          this.descarteErrorTarget.textContent = (data.errores || []).join(" ")
          this.descarteErrorTarget.classList.remove("hidden")
          return
        }
        this.dispatch("guardado")
        this._pintarManifiesto(data.manifiesto)
        this.avisoTarget.textContent = data.mensaje
        this.descarteModalTarget.close()
      })
  }

  // ── Terminar: imprimir, limpiar y dejar dicho qué pasó ──────────────────
  //
  // C27-06 · Salen **tantas etiquetas como mediciones**: *"como son dos
  // mediciones, imprime dos"*. En los dos casos la pantalla queda limpia para
  // la tanda siguiente, y el banner guarda el resultado y la única acción que
  // todavía sirve: reimprimir.
  _terminar(mensaje, url, cantidad) {
    this._vaciarTanda()

    this.bannerTextoTarget.textContent = cantidad > 1
      ? `${mensaje} Se imprimieron ${cantidad} etiquetas.`
      : mensaje
    this.bannerTarget.classList.remove("hidden")

    this._imprimir(url, cantidad)
  }

  _imprimir(url, cantidad = 1) {
    if (!url) { this.codigoTarget.focus(); return }

    // «Reimprimir» significa **lo último que se imprimió**, y el texto de los
    // botones lo dice: era la pregunta de Jorge, *"¿cuál hace?"*.
    this._ultimaEtiquetaUrl = url
    const texto = cantidad > 1 ? `Reimprimir las ${cantidad} etiquetas` : "Reimprimir la etiqueta"
    this.reimprimirTextoTarget.textContent = texto
    this.bannerReimprimirTextoTarget.textContent = texto
    this.reimprimirTarget.classList.remove("hidden")
    this.bannerReimprimirTarget.classList.remove("hidden")
    // El botón vive adentro del bloque de acciones, que está escondido cuando
    // no hay nada en la mesa: sin esto, reimprimir después de guardar no tiene
    // dónde apretarse.
    this.accionesTarget.classList.remove("hidden")

    window.open(url, "_blank")
    window.addEventListener("focus", () => this.codigoTarget.focus(), { once: true })
    this.codigoTarget.focus()
  }

  reimprimir() {
    if (!this._ultimaEtiquetaUrl || this._modalAbierto()) return

    window.open(this._ultimaEtiquetaUrl, "_blank")
    window.addEventListener("focus", () => this.codigoTarget.focus(), { once: true })
  }

  // ── Limpiar ─────────────────────────────────────────────────────────────

  limpiar() {
    if (this._modalAbierto()) return
    this._vaciarTanda()
    this.codigoTarget.focus()
  }

  // Toda la tanda al piso: la mesa, los volúmenes, la grilla y los dos lados.
  _vaciarTanda() {
    this._paquete = null
    this._mesa = []
    this._volumenes = []
    this._saltados = []
    this._limpiarNumeros()
    this._pintarGrupo(null)
    this.dosLadosTarget.classList.add("hidden")
    this._repintar()
  }

  _limpiarNumeros() {
    [this.pesoTarget, this.altoTarget, this.largoTarget, this.anchoTarget].forEach((i) => { i.value = "" })
  }

  // ── Facturar lo que hay ─────────────────────────────────────────────────

  abrirExcepcion() {
    if (!this._grupo) return

    this.dispatch("problema")
    this.excepcionFaltantesTarget.replaceChildren(...this._grupo.cajas.filter((c) => c.estado !== "medida").map((c) => {
      const li = document.createElement("li")
      li.textContent = `${c.wr || c.tracking} · ${c.donde}`
      return li
    }))
    this.excepcionErrorTarget.classList.add("hidden")
    this.excepcionModalTarget.showModal()
    requestAnimationFrame(() => this.confirmarParcialTarget.focus())
  }

  cerrarExcepcion() { this.excepcionModalTarget.close() }

  confirmarParcial() {
    if (!this._grupo?.facturar_parcial_url) return

    this._post(this._grupo.facturar_parcial_url, {}, { conEstado: true })
      .then(({ ok, data }) => {
        if (!ok) {
          this.dispatch("fallo")
          this.excepcionErrorTarget.textContent = (data.errores || []).join(" ")
          this.excepcionErrorTarget.classList.remove("hidden")
          return
        }
        this.dispatch("guardado")
        this.avisoTarget.textContent = data.mensaje
        this.excepcionModalTarget.close()
        // Facturar lo que hay cierra el envío: imprime lo medido y limpia.
        this._terminar(data.mensaje, data.imprimir_url, data.grupo.medidas)
      })
  }

  // ── Teclado ─────────────────────────────────────────────────────────────

  teclaGlobal(e) {
    // F5 recarga la página en Chrome, así que se frena **siempre**, con modal
    // abierto o sin él: si se escapa, el operario pierde la mesa entera y no
    // hay nada guardado que recuperar.
    if (e.key === "F5") e.preventDefault()
    if (this._modalAbierto()) return
    if (e.key === "F10") { e.preventDefault(); this.guardar() }
    if (e.key === "F9")  { e.preventDefault(); this.reimprimir() }
    if (e.key === "F5")  { this.agregarVolumen() }
    if (e.key === "F2")  { e.preventDefault(); this.limpiar() }
  }

  _modalAbierto() {
    return this.problemaModalTarget.open || this.excepcionModalTarget.open ||
           this.descarteModalTarget.open || this.mezclaModalTarget.open ||
           this.consolidadoModalTarget.open
  }

  _enfocarPeso() {
    if (this._mesa.length === 0) return

    this.pesoTarget.focus()
    this.pesoTarget.select()
  }

  // C27-02 · El foco vuelve **al escaneo**, siempre: la mesa se arma pip a pip
  // y el peso se toca (o se llega con Enter en el campo vacío). Antes volvía al
  // peso, y con el bulto eso mandaba el segundo warehouse al campo del peso.
  _enfocarDondeToca() {
    if (this._volverAPeso) { this._volverAPeso = false; this._enfocarPeso(); return }
    this.codigoTarget.focus()
  }

  // ── Red ─────────────────────────────────────────────────────────────────

  _post(url, cuerpo, { conEstado = false } = {}) {
    return this._fetch("POST", url, cuerpo)
      .then((r) => (conEstado ? r.json().then((data) => ({ ok: r.ok, data })) : r.json()))
  }

  _fetch(method, url, cuerpo) {
    const token = document.querySelector("meta[name='csrf-token']")?.content
    return fetch(url, {
      method,
      headers: { "Content-Type": "application/json", "Accept": "application/json", "X-CSRF-Token": token },
      body: JSON.stringify(cuerpo)
    })
  }
}
