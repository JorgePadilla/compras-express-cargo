import { Controller } from "@hotwired/stimulus"
import { conEnterAvanza } from "controllers/enter_avanza"
import { enfocar } from "controllers/enfocar"

// C26-02/19 · La estación de Medición (San Pedro).
//
// Se escanea el warehouse receipt de la etiqueta de Miami y cada pip agrega
// una caja a la mesa. La pantalla es **una tarjeta** en el orden del bloque de
// /etiquetar —Jorge: *"a Yusef le gusta el agregar que estaba en etiqueta"*—:
// la pistola, la tanda (cliente una vez, y la línea de consolidación si la
// hay), la mesa, la captura con el cálculo al lado, los volúmenes con su
// «+ Agregar», y la barra. Sin grilla de cuadritos: la primera versión mostraba
// dos modelos a la vez y la última caja aparecía cuatro veces.
//
// C27-01 · La unidad de la pantalla no es la caja: es **la medición**. Yusef,
// el 2026-09-07, tres veces en la misma reunión:
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
// C28-08 · **Primero se escanea todo, después salen los volúmenes.** Hasta el
// 2026-10-03 cada volumen llevaba sus cajas —escanear tres, medir, escanear
// dos, medir—, y la línea lo probó y lo dio vuelta: *"la medición la va a
// decidir después de haber escaneado… para ellos es mejor solo escanear, que
// sí están ahí, y ellos lo acomodan como gustan para medir y pesar"*. Las cajas
// escaneadas (`_mesa`) son de la tanda; los volúmenes (`_volumenes`) son solo
// números, y F5 agrega el siguiente con el foco ya en el peso.
//
// Mismo esqueleto que /empacar: la pistola dispara Enter, cada resultado suena
// distinto, y el guard `_seq` evita que una respuesta vieja pinte por una caja
// que ya no está en pantalla. Los `dispatch` van con el nombre literal, uno por
// rama, para que `sonidos_cableados_test` los pueda leer del archivo; y el
// `showModal()` va en el mismo método que el `dispatch`, que es lo que el lint
// exige.

// «NO Mezclar» que se resuelve con el modal de dos salidas (quitar la última o
// empezar de nuevo). PR-P.11a suma los motivos que antes iban a la pre-factura
// a mano: otra sucursal de retiro, prepagadas con no prepagadas (RP-89), otra
// tarifa (RP-92) y otro trato de cobro (RP-72). Un motivo que no esté acá cae
// en el aviso de «repetida», así que cada uno nuevo tiene que entrar.
const TITULOS_DE_MEZCLA = {
  otro_cliente: "Es otro cliente",
  otro_servicio: "Es otro servicio",
  otra_sucursal: "Se retira en otra sucursal",
  prepago_mezclado: "Prepagadas y no prepagadas no se miden juntas",
  otra_tarifa: "Se cobra con otra tarifa",
  otro_trato_de_cobro: "Tiene otro trato de cobro"
}
export default class extends conEnterAvanza(Controller) {
  static targets = [
    "codigo", "aviso",
    "trabajo", "barra", "medir", "medirVacio", "tandaCliente", "tandaGrupo", "tandaConsolidado", "tandaCajas", "tandaAusentes", "plantillaDibujito",
    "tandaContador", "tandaFaltan", "tandaCompleto",
    "mesa", "plantillaMesa", "mesaTitulo",
    "notasBoton", "notasBotonTexto", "notasModal", "notasCliente", "notasLista", "notasEntendido", "plantillaNota",
    "volumenesContador", "volumenesVacio", "listaVolumenes", "plantillaVolumen", "agregarVolumen", "rotuloVolumen",
    "volumenesAnteriores",
    "form", "peso", "alto", "largo", "ancho", "guardar", "guardarTexto",
    "banner", "bannerTexto", "bannerFaltan", "bannerReimprimir", "bannerReimprimirTexto", "bannerFacturar",
    "manifiestoNumero", "manifiestoFechas", "manifiestoConteo", "pendientes", "sinPendientes",
    "plantillaPendiente", "descarteModal", "descarteCaja", "descarteMotivo", "descarteNota",
    "descarteError", "confirmarDescarte",
    "problemaModal", "problemaTitulo", "problemaTexto", "problemaEntendido", "medirDeNuevo",
    "reimprimirBulto", "remedirBulto", "medirIgual",
    "mezclaModal", "mezclaTitulo", "mezclaTexto", "mezclaQuitar",
    "consolidadoModal", "consolidadoTitulo", "consolidadoTexto", "consolidadoPreAlerta",
    "consolidadoPreFactura", "hacerConsolidado",
    "unirModal", "unirTexto", "unirPreAlerta", "unirError", "unirSi",
    "yaMedidoModal", "yaMedidoTexto", "yaMedidoLista", "yaMedidoJunto",
    "excepcionModal", "excepcionFaltantes", "excepcionError", "confirmarParcial",
    "autorizarModal", "autorizarFaltantes", "autorizarSupervisor", "autorizarPin", "autorizarMotivo",
    "autorizarError", "confirmarAutorizacion"
  ]
  static values = {
    escanearUrl: String, guardarUrl: String, panelUrl: String, unirUrlTemplate: String,
    etiquetaUrlTemplate: String, clases: Object, maximo: Number
  }

  connect() {
    this._seq = 0
    this._paquete = null
    this._grupo = null
    // La mesa: las cajas de la tanda, en el orden en que entraron. Los
    // volúmenes: los números ya agregados (C28-08: ninguno lleva cajas).
    // Nada de esto vive en el servidor hasta F9 — `MedirBulto` recibe la
    // tanda entera de un saque, porque el «1 de 2» del QR necesita saber
    // cuántas mediciones son antes de imprimir la primera.
    this._mesa = []
    this._volumenes = []
    // C30-11 · Los volúmenes que la tanda tenía antes de medirla de nuevo:
    // solo para mirarlos, nunca se guardan.
    this._anteriores = []
    // C27-14 · Las cajas que alguien autorizó a medir sin manifiesto. Se
    // mandan al guardar y el servidor las sella una por una.
    this._saltados = []
    // C29-19 · Las notas del cliente que ya se mostraron en esta tanda, por
    // texto: el modal se abre solo con lo que **no** se vio todavía.
    this._notas = []
    // F9 guarda e imprime (C29-13; F8 también, sin rótulo: C30-02), F4 reimprime,
    // F5 agrega volumen, F2 limpia — escuchando en `document`, porque el
    // atajo global ignora las F-keys cuando el foco está en un input, y acá
    // siempre está.
    this._teclaGlobal = this.teclaGlobal.bind(this)
    document.addEventListener("keydown", this._teclaGlobal)
    // Al cerrarse cualquier modal, el foco vuelve a donde toca, un frame
    // después: en el mismo tick el `open` todavía no se fue.
    this._alCerrarse = () => requestAnimationFrame(() => this._enfocarDondeToca())
    this.element.addEventListener("close", this._alCerrarse, true)
    if (this.hasCodigoTarget) this.codigoTarget.focus()
    // C26-17 · El panel de lo que falta (abajo desde C29-16) arranca con el
    // último manifiesto que todavía tiene algo que medir, para que la
    // pantalla no abra vacía.
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

  _escanear(codigo, { saltarManifiesto = false, remedir = false, aparte = false } = {}) {
    if (!codigo) return

    const consulta = (this._seq += 1)
    // `en_tanda` es **toda** la tanda, mesa y volúmenes: «NO Mezclar» es de la
    // sesión entera y no de cada medición. Mirando solo la mesa, la caja de
    // otro cliente entraría en el volumen 2 sin chistar y el error saldría
    // recién en F9, con el volumen 1 ya medido.
    this._post(this.escanearUrlValue,
               { codigo, en_tanda: this._idsDeLaTanda(), saltar_manifiesto: saltarManifiesto, remedir, aparte })
      .then((data) => {
        if (consulta !== this._seq) return  // llegó tarde: habla de otro escaneo
        this._resolver(data)
      })
      .catch(() => this._problema("No se pudo consultar", "Probá de nuevo."))
  }

  _idsDeLaTanda() {
    return this._mesa.map((p) => p.id)
  }

  _resolver(data) {
    // C29-18 · La caja que hay que escanear después de traer la tanda vieja.
    // Se toma y se suelta acá: si la remedición no vuelve, no queda colgada
    // para la próxima.
    const despues = this._despuesDeRemedir
    this._despuesDeRemedir = null
    if (data.resultado === "consolidado_ya_medido") { this._consolidadoYaMedido(data); return }
    if (data.resultado === "no_mezclar") { this._noMezclar(data); return }
    if (data.resultado === "ya_tiene_bulto") { this._yaTieneBulto(data); return }
    if (data.puede_saltar) { this._sinManifiesto(data); return }
    if (data.resultado !== "ok" && data.resultado !== "pre_alerta_ya_facturada") {
      this._problema(this._titulo(data.resultado), data.mensaje)
      return
    }

    // La caja entra a la mesa. Es lo único que agrega cajas: no hay checkbox
    // ni lista de dónde elegir.
    if (data.remedir_tanda) {
      // C27-33 · Medir de nuevo: la tanda entera vuelve —sus cajas— y al
      // guardar la tanda nueva reemplaza a la vieja.
      //
      // C30-11 · Los volúmenes viejos **no** vuelven a la lista: quedan
      // escritos como «volumen anterior», para mirarlos y nada más. Hasta el
      // 2026-10-09 volvían como volúmenes agregados, y en la prueba Jorge tuvo
      // que quitar el viejo con la X antes de guardar el nuevo. Yusef: *"desde
      // el instante que le dio que lo va a medir de nuevo… se le borre todo…
      // que solo le diga volumen anterior o algo por el estilo"* — *"lo que
      // hiciste fue borrar volumen físicamente"*. Con el viejo en la lista,
      // pesar el nuevo y apretar F9 guardaba **los dos**: dos etiquetas y
      // dos volúmenes cobrados por las mismas cajas.
      this._mesa.push(...data.hermanas.filter((h) => !this._mesa.some((p) => p.id === h.id)))
      this._reemplazaSesion = data.remedir_tanda.sesion
      this._volumenes = []
      this._anteriores = data.remedir_tanda.volumenes || []
      this._pintar(data)
      this.avisoTarget.textContent = data.mensaje
      this.dispatch("atencion")
      this._volverAPeso = true
      this._enfocarDondeToca()
      this._recibirNotas(data)
      if (despues) this._escanear(despues)
      return
    }
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
        `${data.medicion_previa.peso} lb · ${data.medicion_previa.medidas}. Entró a la tanda igual.`, { medirDeNuevo: true })
      this.problemaModalTarget.showModal()
      requestAnimationFrame(() => this.problemaEntendidoTarget.focus())
    } else if (data.grupo && !data.grupo.completo) {
      this.dispatch("unir")
    } else {
      this.dispatch("ok")
    }
    this._recibirNotas(data)
  }

  // ── C29-19 · Las notas del cliente ──────────────────────────────────────
  //
  // Yusef: *"el que necesita leer es las notas. Las notas en modal, las notas
  // en todo"*. Se abren **solas** la primera vez que aparecen en la tanda
  // —la primera caja trae las del cliente; una caja con su propia
  // instrucción trae la suya— y el botón de la tanda las vuelve a abrir. Si
  // ya hay otro modal arriba (una caja medida antes, una pre-alerta
  // facturada), no se apilan: queda el botón con el número, que avisa.
  _recibirNotas(data) {
    const nuevas = (data.notas || []).filter((n) => !this._notas.some((v) => this._mismaNota(v, n)))
    if (nuevas.length === 0) return

    this._notas.push(...nuevas)
    this._pintarBotonNotas()
    if (this._modalAbierto()) return
    this._abrirNotas()
  }

  // C30-10 · La misma nota es **el mismo texto**, venga con el rótulo que
  // venga. Una caja trae la nota de grupo como «Nota especial» y otra caja del
  // mismo consolidado la trae copiada como «Notas de consolidación» (la copia
  // que hace Miami al vincularla): para el operario es una nota, no dos. El
  // servidor ya las junta dentro de una caja (`PanelContextoHelper#sin_repetir`);
  // esto las junta entre cajas de la tanda.
  //
  // Salvo que las dos traigan `detalle` y sea distinto: la instrucción del
  // tracking A y la del B son dos notas aunque digan lo mismo (`sin_repetir`).
  _mismaNota(a, b) {
    if (a.detalle && b.detalle && a.detalle !== b.detalle) return false
    return this._textoDeNota(a) === this._textoDeNota(b)
  }

  _textoDeNota(n) { return String(n.texto || "").replace(/\s+/g, " ").trim().toLowerCase() }

  _pintarBotonNotas() {
    const n = this._notas.length
    this.notasBotonTarget.hidden = n === 0
    this.notasBotonTextoTarget.textContent = n === 1 ? "1 nota del cliente" : `${n} notas del cliente`
  }

  verNotas() {
    if (this._modalAbierto() || this._notas.length === 0) return
    this._abrirNotas()
  }

  _abrirNotas() {
    this.dispatch("atencion")
    const primera = this._mesa[0]
    this.notasClienteTarget.textContent = primera ? primera.cliente || "" : ""
    this.notasListaTarget.replaceChildren(...this._notas.map((n) => this._bloqueNota(n)))
    this.notasModalTarget.showModal()
    requestAnimationFrame(() => this.notasEntendidoTarget.focus())
  }

  _bloqueNota(n) {
    const nodo = this.plantillaNotaTarget.content.firstElementChild.cloneNode(true)
    const clases = n.clases || {}
    nodo.className += ` ${clases.wrap || ""}`
    const etiqueta = nodo.querySelector("[data-campo=etiqueta]")
    etiqueta.className += ` ${clases.label || ""}`
    etiqueta.textContent = [n.etiqueta, n.detalle].filter(Boolean).join(" · ")
    nodo.querySelector("[data-campo=texto]").textContent = n.texto
    return nodo
  }

  cerrarNotas() { this.notasModalTarget.close() }

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
    if (data.motivo in TITULOS_DE_MEZCLA) {
      this._mezcla(data)
    } else if (data.motivo === "unible") {
      this._unible(data)
    } else if (data.motivo === "otra_consolidacion" || data.motivo === "no_consolidada") {
      this._consolidado(data)
    } else {
      // "repetida": no hay nada que decidir, es un pip de más.
      this._problema("Esa caja ya la escaneaste", data.mensaje)
    }
  }

  // Yusef: *"escanea uno de Jorge y va y escanea otro y ese no es el mismo
  // Jorge… le tira error, es diferente cliente… ¿desea eliminar este último o
  // empezar todo de nuevo?"*. Las dos salidas son las de él.
  _mezcla(data) {
    this.dispatch("mezcla")
    this.mezclaTituloTarget.textContent = TITULOS_DE_MEZCLA[data.motivo]
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
    this.consolidadoPreFacturaTarget.hidden = !choque.pre_factura
    if (choque.pre_factura) {
      this.consolidadoPreFacturaTarget.textContent = `Ese consolidado ya tiene la pre-factura ${choque.pre_factura}.`
    }
    // C29-17 · «Hago el consolidado» solo si la que entra **es** de un
    // consolidado. Al revés —el consolidado en la mesa, la que entra suelta
    // con su propia pre-alerta— vaciaba la mesa y arrancaba con la suelta:
    // le borraba al operario lo que estaba haciendo.
    const puedeHacerlo = data.motivo === "otra_consolidacion"
    this.hacerConsolidadoTarget.hidden = !puedeHacerlo
    this.consolidadoModalTarget.showModal()
    requestAnimationFrame(() => (puedeHacerlo ? this.hacerConsolidadoTarget
                                              : this.consolidadoModalTarget.querySelector("button:not([hidden])"))?.focus())
  }

  // ── C29-17 · Unir una suelta al consolidado de la mesa ──────────────────
  //
  // Yusef: *"¿desea agregar este paquete a esta consolidación?… o sigo
  // procesando el que estoy trabajando, o dejarlo a un lado"* — y *"que el
  // mismo que está pesando y midiendo los agrega"*. La caja no entró: si la
  // agrega, se suma a la pre-alerta y se vuelve a escanear sola, por la puerta
  // de siempre.
  _unible(data) {
    this.dispatch("unir")
    this._paraUnir = { paquete: data.paquete, preAlertaId: data.choque && data.choque.id }
    this.unirTextoTarget.textContent = data.mensaje
    this.unirPreAlertaTarget.textContent = data.choque ? [data.choque.numero, data.choque.titulo].filter(Boolean).join(" · ") : ""
    this.unirErrorTarget.hidden = true
    this.unirModalTarget.showModal()
    requestAnimationFrame(() => this.unirSiTarget.focus())
  }

  unirSi() {
    const u = this._paraUnir
    if (!u || !u.preAlertaId) return

    this._post(this.unirUrlTemplateValue.replace("ID", u.preAlertaId), { paquete_id: u.paquete.id }, { conEstado: true })
      .then(({ ok, data }) => {
        if (!ok) {
          this.unirErrorTarget.textContent = (data.errores || []).join(" ")
          this.unirErrorTarget.hidden = false
          return
        }
        this._paraUnir = null
        this.unirModalTarget.close()
        this.avisoTarget.textContent = data.mensaje
        this._escanear(data.codigo)
      })
  }

  unirNo() {
    this._paraUnir = null
    this.unirModalTarget.close()
  }

  // ── C29-18 · Su consolidado ya se midió ─────────────────────────────────
  //
  // *"Este paquete está consolidando con otro, traer el resto y medir, y
  // unirlo… hay que volver a medir. Una remedición nueva."* «Medir de nuevo
  // todo junto» trae la tanda vieja (C27-33) y después escanea ésta.
  _consolidadoYaMedido(data) {
    this.dispatch("unir")
    this._yaMedido = data
    this.yaMedidoTextoTarget.textContent = data.mensaje
    this.yaMedidoListaTarget.replaceChildren(...(data.medidas || []).map((m) => {
      const li = document.createElement("li")
      li.textContent = [m.codigo, m.fecha && `medida el ${m.fecha}`, m.por].filter(Boolean).join(" · ")
      return li
    }))
    this.yaMedidoJuntoTarget.hidden = !data.puede_remedir
    this.yaMedidoModalTarget.showModal()
    requestAnimationFrame(() => (data.puede_remedir ? this.yaMedidoJuntoTarget
                                                    : this.yaMedidoModalTarget.querySelector("button"))?.focus())
  }

  yaMedidoJunto() {
    const d = this._yaMedido
    this.yaMedidoModalTarget.close()
    if (!d || !d.remedir_codigo) return
    this._despuesDeRemedir = d.paquete.codigo || d.paquete.tracking
    this._escanear(d.remedir_codigo, { remedir: true })
  }

  yaMedidoSola() {
    const d = this._yaMedido
    this.yaMedidoModalTarget.close()
    if (d) this._escanear(d.paquete.codigo || d.paquete.tracking, { aparte: true })
  }

  yaMedidoDejar() { this.yaMedidoModalTarget.close() }

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
    // C28-08 · Reimprimir saca las etiquetas de **toda la tanda**: la caja no
    // es de un volumen.
    this._bultoParaReimprimir = data.tanda && data.tanda.etiquetas_url
    this._cuantasParaReimprimir = (data.tanda && data.tanda.volumenes.length) || 1
    this._paraRemedir = data.paquete
    this._llenarProblema("Esta caja ya está medida", data.mensaje, { reimprimir: true, remedir: true })
    this.problemaModalTarget.showModal()
    requestAnimationFrame(() => this.problemaEntendidoTarget.focus())
  }

  _llenarProblema(titulo, texto, { medirDeNuevo = false, reimprimir = false, medirIgual = false, remedir = false }) {
    this.problemaTituloTarget.textContent = titulo
    this.problemaTextoTarget.textContent = texto
    this.medirDeNuevoTarget.hidden = !medirDeNuevo
    this.reimprimirBultoTarget.hidden = !reimprimir
    this.remedirBultoTarget.hidden = !remedir
    this.medirIgualTarget.hidden = !medirIgual
  }

  // C27-33 · «Medir de nuevo»: se vuelve a escanear con el permiso puesto, y
  // el servidor devuelve el bulto entero para la mesa. Jorge, en staging:
  // *"cuando un warehouse receipt ya tiene medidas y se vuelve a escanear no
  // me pregunta si quiero editarlo"*.
  remedirBulto() {
    const codigo = this._paraRemedir && (this._paraRemedir.codigo || this._paraRemedir.tracking)
    this.problemaModalTarget.close()
    if (codigo) this._escanear(codigo, { remedir: true })
  }

  avisoEntendido() { this.problemaModalTarget.close() }

  medirDeNuevo() {
    this._volverAPeso = true
    this.problemaModalTarget.close()
  }

  reimprimirBulto() {
    this.problemaModalTarget.close()
    if (this._bultoParaReimprimir) this._imprimir(this._bultoParaReimprimir, this._cuantasParaReimprimir)
  }

  // C20-13 · Escape no contesta un aviso: *"ellos no las leen"*.
  avisoCancelar(e) { e.preventDefault() }

  // ── Pintar ──────────────────────────────────────────────────────────────
  //
  // Mostrar y esconder va por el **atributo** `hidden`, nunca por la clase. En
  // el CSS compilado `.inline-flex`, `.flex` y `.inline-block` vienen después
  // de `.hidden`, así que un `ButtonComponent` con la clase `hidden` **se ve
  // igual**: los tres botones del modal rojo salían juntos, y el «×» de sacar
  // de la lista lo veía el operario que no es admin. El preflight de Tailwind
  // trae `[hidden]{display:none!important}`, y ése no pierde con nadie.

  _pintar(data) {
    this._paquete = data.paquete
    this._grupo = data.grupo || null
    // C28-08 · Los números de Miami ya **no** se copian al formulario: el
    // volumen 1 no es la caja 1, y un peso de Miami puesto de antemano es un
    // número que se guarda sin que nadie lo haya pesado.

    this._pintarManifiesto(data.manifiesto)
    this._repintar()
    this.bannerTarget.hidden = true
    this.formTarget.querySelectorAll("input").forEach((i) => i.dispatchEvent(new Event("input", { bubbles: true })))
  }

  // ── La tanda, una vez ───────────────────────────────────────────────────
  //
  // El cliente y el servicio salen **una sola vez** —en la primera versión
  // estaban en tres lugares—. Y si la caja viene en grupo, la línea que antes
  // repartían la grilla de cuadritos y los paneles de «dos lados»: con qué
  // pre-alerta, cuántas van en la mesa, cuáles ya se midieron (y quién, que es
  // C27-12) y cuáles faltan y dónde están. Es la «Notificación» de la pizarra
  // —*medir → notificación → buscar el resto*— sin nada que tocar.
  _pintarTanda() {
    const primera = this._mesa[0]
    this.tandaClienteTarget.textContent = primera
      ? [primera.cliente, primera.tipo_envio].filter(Boolean).join(" · ")
      : ""

    const g = this._grupo
    const hay = !!(g && g.total > 1)
    this.tandaGrupoTarget.hidden = !hay
    if (!hay) { this._yaCompleto = false; return }

    const enTanda = new Set(this._idsDeLaTanda())
    const enMesa = (c) => !!(c.id && enTanda.has(c.id))
    const cajasEnMesa = g.cajas.filter(enMesa).length
    const medidas = g.cajas.filter((c) => c.estado === "medida").length
    const faltan = g.cajas.filter((c) => c.estado !== "medida" && !enMesa(c))

    // C28-11 · El número, **grande**. Yusef, mirando la línea con el conteo:
    // *"eso sí se necesita hacer más grande. Así como está, pero más grande.
    // El número, a cuánto falta"*. Cuenta lo que ya está resuelto —escaneado
    // en esta tanda o medido antes— contra el total del envío.
    this.tandaContadorTarget.textContent = `${cajasEnMesa + medidas} de ${g.total}`
    this.tandaFaltanTarget.textContent = faltan.length > 0 ? `faltan ${faltan.length}` : ""
    // Y cuando no falta nada, que lo diga y que suene: *"Completado.
    // Completado. Pero literalmente quiero que salga al lado… sí, el
    // audio"*. Suena **una vez**, al pasar de faltar a completo, y no con
    // cada repintado.
    const completo = faltan.length === 0
    this.tandaCompletoTarget.hidden = !completo
    if (completo && !this._yaCompleto) this.dispatch("completo")
    this._yaCompleto = completo

    // La línea corta: los conteos y nada más. Los códigos van en los dibujitos.
    //
    // C29-16 · Lo suelto se cuenta por cliente y por manifiesto, y la línea lo
    // dice con las palabras de Yusef: *"Diego tiene cinco paquetes en el vuelo
    // y solo estás escaneando tres, y faltan dos en el mismo manifiesto"*.
    const encabezado = g.consolidada ? `Consolidando ${g.numero} · ${g.total} cajas`
      : g.del_manifiesto ? `${g.cliente} tiene ${g.total} en el manifiesto ${g.del_manifiesto}`
      : `Envío de ${g.total} cajas`
    const partes = [encabezado, g.del_manifiesto ? `llevás ${cajasEnMesa}` : `escaneadas ${cajasEnMesa}`,
                    `medidas ${medidas}`, `faltan ${faltan.length}`]
    if (g.parcial_autorizado) {
      partes.push(`se facturó incompleto el ${g.parcial_autorizado.fecha} por ${g.parcial_autorizado.por}`)
    }
    this.tandaConsolidadoTarget.textContent = partes.join(" · ")

    this.tandaCajasTarget.replaceChildren(...g.cajas.map((c) => this._dibujito(c, enMesa(c))))

    // Las que no están acá son las que hay que ir a buscar o reclamar; las
    // «acá, sin medir» ya se ven en el dibujo y no se listan.
    //
    // C29-16 · Salvo en la cuenta del cliente: ahí las «acá, sin medir" son
    // justamente las que hay que ir a buscar a la bodega, y Yusef pidió la
    // lista —*"que te dé el listado de lo de Diego que venía en ese
    // manifiesto"*—. Van todas las que faltan, con su warehouse y su caja.
    if (g.del_manifiesto) {
      this.tandaAusentesTarget.hidden = faltan.length === 0
      this.tandaAusentesTarget.textContent = faltan.length === 0 ? "" :
        `Faltan de ${g.cliente} en este manifiesto: ${faltan.map((c) => `${c.wr || c.tracking} (${c.donde})`).join(", ")}`
      return
    }
    const ausentes = faltan.filter((c) => c.estado === "en_camino" || c.estado === "esperada")
    this.tandaAusentesTarget.hidden = ausentes.length === 0
    this.tandaAusentesTarget.textContent = ausentes.length === 0 ? "" :
      `No están acá: ${ausentes.map((c) => `${c.wr || c.tracking} (${c.donde})`).join(", ")}`
  }

  // Un dibujito por caja. Solo el sufijo: el número madre ya está en la mesa y
  // en el cliente, y repetirlo diez veces es lo que hacía ilegible la frase.
  _dibujito(c, enMesa) {
    const nodo = this.plantillaDibujitoTarget.content.firstElementChild.cloneNode(true)
    const clases = this.clasesValue
    nodo.dataset.estado = c.estado
    if (enMesa) nodo.dataset.enMesa = "1"
    // La de la mesa **reemplaza** las clases del estado en vez de sumarse: dos
    // `bg-` en el mismo elemento las resuelve el orden del CSS, no el del
    // atributo (la lección de #438).
    nodo.className += ` ${enMesa ? clases.seleccionada : (clases[c.estado] || "")}`
    const codigo = c.wr || c.tracking || ""
    const donde = enMesa ? "escaneada" : c.donde
    nodo.querySelector("[data-campo=sufijo]").textContent = this._sufijo(c)
    // C27-12 · En la medida, quién la midió.
    nodo.querySelector("[data-campo=marca]").textContent =
      enMesa ? "LEÍDA" : (c.estado === "medida" ? (c.por || "OK") : "")
    nodo.title = `${codigo} · ${donde}`
    nodo.setAttribute("aria-label", `${codigo}: ${donde}`)
    return nodo
  }

  _sufijo(c) {
    if (c.wr) {
      // C29-16 · En la cuenta del cliente los dibujitos son de **envíos
      // distintos**, y «-2» solo no dice de cuál: va la cola del número con
      // su caja. En un envío partido todos comparten el número y basta la caja.
      if (this._grupo?.del_manifiesto) {
        const m = c.wr.match(/(\d{4})(-\d+)?$/)
        if (m) return `${m[1]}${m[2] || ""}`
      }
      const caja = c.wr.match(/-(\d+)$/)
      return caja ? `-${caja[1]}` : c.wr.slice(-4)
    }
    return (c.tracking || "").slice(-4)
  }

  // ── La mesa y los volúmenes ─────────────────────────────────────────────

  _repintar() {
    this._pintarTanda()
    this._pintarMesa()
    this._pintarVolumenes()
    this._textoDeLosBotones()
    // La tanda y la barra aparecen con la primera caja y se van con la última.
    const vacia = this._mesa.length === 0 && this._volumenes.length === 0
    this.trabajoTarget.hidden = vacia
    this.barraTarget.hidden = vacia
    // PR-C29.10 · La columna de MEDIR no desaparece con la tanda vacía: dice
    // qué va a pasar ahí, y la pantalla no salta con el primer pip.
    this.medirTarget.hidden = vacia
    this.medirVacioTarget.hidden = !vacia
  }

  _pintarMesa() {
    const n = this._mesa.length
    this.mesaTituloTarget.textContent = `${n} ${n === 1 ? "caja escaneada" : "cajas escaneadas"}`
    this.mesaTarget.replaceChildren(...this._mesa.map((p, i) => this._filaMesa(p, i)))
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
    // PR-C29.8 · El título de la captura dice qué volumen se está midiendo,
    // como /etiquetar dice «Caja 2»: con dos guardados, lo de arriba es el
    // tercero. En el tope no hay un «Volumen 11» que medir, así que se queda
    // en el último.
    this.rotuloVolumenTarget.textContent = `Volumen ${Math.min(n + 1, this.maximoValue || n + 1)}`
    this.volumenesVacioTarget.hidden = n > 0
    this.listaVolumenesTarget.replaceChildren(...this._volumenes.map((v, i) => this._filaVolumen(v, i)))
    this._pintarAnteriores()
  }

  // C30-11 · Lo que la tanda medía antes: texto, sin botones. Es la
  // referencia —*"que solo le diga volumen anterior"*—, no algo que se guarde.
  _pintarAnteriores() {
    const anteriores = this._anteriores || []
    this.volumenesAnterioresTarget.hidden = anteriores.length === 0
    if (anteriores.length === 0) { this.volumenesAnterioresTarget.textContent = ""; return }

    const uno = (v) => {
      const medidas = [v.alto, v.largo, v.ancho].filter(Boolean).join("x")
      return [v.peso && `${v.peso} lb`, medidas && `${medidas} in`].filter(Boolean).join(" · ")
    }
    this.volumenesAnterioresTarget.textContent = anteriores.length === 1
      ? `Volumen anterior: ${uno(anteriores[0])}. Se reemplaza al guardar.`
      : `Volúmenes anteriores: ${anteriores.map((v, i) => `${i + 1}) ${uno(v)}`).join("; ")}. Se reemplazan al guardar.`
  }

  _filaVolumen(v, i) {
    const nodo = this.plantillaVolumenTarget.content.firstElementChild.cloneNode(true)
    nodo.dataset.indice = i
    nodo.querySelector("[data-campo=orden]").textContent = `Volumen ${i + 1}`
    const medidas = [v.alto, v.largo, v.ancho].filter(Boolean).join("x")
    nodo.querySelector("[data-campo=numeros]").textContent =
      [v.peso && `${v.peso} lb`, medidas && `${medidas} in`].filter(Boolean).join(" · ")
    return nodo
  }

  // C26-04/19 · Los botones dicen lo que **va a pasar**. Jorge: *"veo «Guardar
  // e imprimir»… «Reimprimir etiqueta», no sé si solo hace una, ¿cuál hace?"*.
  // Con tres volúmenes salen tres etiquetas, y prometer una sería mentir.
  _textoDeLosBotones() {
    // Lo que está en el formulario sale como el último volumen, si tiene
    // números (C28-08: ya no importa si quedan cajas «en la mesa»).
    const total = this._volumenes.length + (this._tieneNumeros(this._numeros()) ? 1 : 0)
    this.guardarTextoTarget.textContent = total > 1
      ? `Guardar e imprimir ${total} etiquetas`
      : "Guardar e imprimir"
  }

  // C29-14 · La X de **cada** caja. Antes solo se podía quitar la última, y
  // en la prueba del 2026-10-08 Jorge preguntó *"¿cómo quito uno?"*. Yusef:
  // *"una X acá al lado, una X grande, porque acordate que va a hacer touch"*.
  //
  // Sacar una del medio no rompe «NO Mezclar»: todas las de la tanda son del
  // mismo cliente, del mismo servicio y de la misma consolidación, así que la
  // que queda primera vale igual que la que se fue. Y si era una que alguien
  // autorizó a medir sin manifiesto, el permiso se va con ella. En una tanda
  // que se está midiendo de nuevo, la que se saca queda **sin medir** al
  // guardar (`MedirBulto#reemplazar!`), que es lo que significa sacarla.
  quitarCaja(e) {
    if (this._modalAbierto()) return
    const id = Number(e.currentTarget.closest("li")?.dataset.paqueteId)
    if (!id) return

    this._mesa = this._mesa.filter((p) => p.id !== id)
    this._saltados = this._saltados.filter((s) => s !== id)
    if (this._mesa.length === 0) { this._grupo = null; this._reemplazaSesion = null; this._anteriores = [] }
    this._repintar()
    this.codigoTarget.focus()
  }

  // El «×» de un volumen ya agregado, como el de una caja en /etiquetar. Es
  // deshacer, no elegir: el volumen lo armó él y lo puede tirar.
  quitarVolumen(e) {
    if (this._modalAbierto()) return
    const i = Number(e.currentTarget.closest("li")?.dataset.indice)
    if (Number.isNaN(i)) return

    this._volumenes.splice(i, 1)
    this._repintar()
    this._enfocarPeso()
  }

  // «Corregir» un volumen ya agregado: sus números vuelven al formulario y la
  // fila se va; F5 lo agrega de nuevo. Es como se corrige al medir de nuevo.
  corregirVolumen(e) {
    if (this._modalAbierto()) return
    const i = Number(e.currentTarget.closest("li")?.dataset.indice)
    if (Number.isNaN(i)) return

    const [v] = this._volumenes.splice(i, 1)
    this.pesoTarget.value = v.peso || ""
    this.altoTarget.value = v.alto || ""
    this.largoTarget.value = v.largo || ""
    this.anchoTarget.value = v.ancho || ""
    this.formTarget.querySelectorAll("input").forEach((inp) => inp.dispatchEvent(new Event("input", { bubbles: true })))
    this._repintar()
    this._enfocarPeso()
  }

  // El texto de «Guardar e imprimir N etiquetas» depende de lo que se teclea.
  numerosCambiados() { this._textoDeLosBotones() }

  // ── Agregar un volumen ──────────────────────────────────────────────────
  //
  // Yusef: *"mide y pesa este, le da **agregar**; mide y pesa este por separado
  // porque no cuadra… y ahí le dice **imprimir**, y como son dos mediciones,
  // imprime dos"*. El operario les dice «volúmenes»: *"le voy a sacar tres
  // volúmenes, así lo dicen ellos, porque son diferentes de tamaño"*.
  agregarVolumen() {
    if (this._modalAbierto()) return
    // C28-08 · Lo único que pide es que la tanda tenga cajas: los volúmenes
    // ya no llevan las suyas. Jorge, en la prueba del 2026-10-03, con el
    // bloqueo viejo puesto: *"aquí es donde ya me dejaste amarrado, porque no
    // puedo meterle otra vez escaneas"*.
    if (this._mesa.length === 0) {
      this._problema("No hay cajas escaneadas", "Escaneá primero las cajas de la tanda, y después sacá los volúmenes.")
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

    this._volumenes.push(numeros)
    this._limpiarNumeros()
    this.dispatch("guardado")
    this._repintar()
    // C28-09 · *"F5 siempre tiene que ir al peso real"*: lo que sigue después
    // de agregar un volumen es **el próximo volumen**, no otra caja.
    this.pesoTarget.focus()
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

    if (this._mesa.length === 0) {
      this._problema("No hay nada que guardar", "Escaneá las cajas de la tanda y poné el peso.")
      return
    }
    // Lo que quedó en el formulario entra como el último volumen: Yusef no
    // dice «agregar» para el último — *"mide y pesa este por separado… y ahí
    // le dice imprimir"*.
    const volumenes = [...this._volumenes]
    if (this._tieneNumeros(this._numeros())) volumenes.push(this._numeros())
    if (volumenes.length === 0) {
      this._problema("Falta pesarlo", "Poné al menos el peso, o las tres medidas, antes de guardar.")
      return
    }

    this._enviarTanda({ paquete_ids: this._idsDeLaTanda(), volumenes, reemplaza_sesion: this._reemplazaSesion || null,
                        saltar_manifiesto: this._saltados })
  }

  _enviarTanda(cuerpo) {
    this._ultimaTanda = cuerpo
    this._post(this.guardarUrlValue, cuerpo, { conEstado: true })
      .then(({ ok, data }) => {
        if (!ok && data.necesita_autorizacion) {
          this._pedirAutorizacion(data)
          return
        }
        if (!ok) {
          this.dispatch("fallo")
          if (this.autorizarModalTarget.open) this.autorizarModalTarget.close()
          this._llenarProblema("No se guardó", (data.errores || []).join(" "), {})
          this.problemaModalTarget.showModal()
          requestAnimationFrame(() => this.problemaEntendidoTarget.focus())
          return
        }

        this.dispatch("guardado")
        if (this.autorizarModalTarget.open) this.autorizarModalTarget.close()
        this._pintarManifiesto(data.manifiesto)
        this.avisoTarget.textContent = data.mensaje
        // La tanda terminó: la pantalla se limpia para la siguiente y el banner
        // guarda el resultado. Jorge: *"cuando se facture o se termine de
        // imprimir se debería limpiar para que se comience con el siguiente"*.
        this._terminar(data.mensaje, data.imprimir_url, data.cantidad, data.grupo)
      })
  }

  // ── C28-13 · Faltan cajas que vinieron: el código de un supervisor ──────
  //
  // Yusef: *"si viene y venían más paquetes no lo debería dejar… para todos
  // estos bloqueos va a haber alguien que lo va a desbloquear, a autorizar…
  // con su código"*. El modal lista lo que falta y dónde está —*"ahí es donde
  // tienen que mandar a buscarlos"*—, y «Cancelar» deja la tanda como estaba
  // para ir a buscarlas.
  _pedirAutorizacion(data) {
    this.dispatch("problema")
    if (this.autorizarModalTarget.open) {
      // Segundo intento con el PIN malo: el modal se queda y dice por qué.
      this.autorizarErrorTarget.textContent = (data.errores || []).join(" ")
      this.autorizarErrorTarget.hidden = false
      this.autorizarPinTarget.value = ""
      this.autorizarPinTarget.focus()
      return
    }
    this.autorizarFaltantesTarget.replaceChildren(...(data.faltantes || []).map((f) => {
      const li = document.createElement("li")
      li.textContent = `${f.codigo} · ${f.donde}`
      return li
    }))
    this.autorizarErrorTarget.hidden = true
    this.autorizarPinTarget.value = ""
    this.autorizarMotivoTarget.value = ""
    this.autorizarModalTarget.showModal()
    requestAnimationFrame(() => this.autorizarSupervisorTarget.focus())
  }

  confirmarAutorizacion() {
    if (!this._ultimaTanda) return

    this._enviarTanda({ ...this._ultimaTanda, autorizacion: {
      supervisor_id: this.autorizarSupervisorTarget.value,
      pin: this.autorizarPinTarget.value,
      motivo: this.autorizarMotivoTarget.value
    } })
  }

  cerrarAutorizacion() { this.autorizarModalTarget.close() }

  // ── El panel de abajo: lo que falta de este manifiesto ──────────────────

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
    this.sinPendientesTarget.hidden = m.pendientes.length > 0
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
    unir.hidden = !pendiente.unir
    if (pendiente.unir) unir.textContent = `UNIR · ${pendiente.unir}`

    // Sacar de la lista es de administración y de nadie más.
    nodo.querySelector("button").hidden = !puedeDescartar
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
    this.descarteErrorTarget.hidden = true
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
          this.descarteErrorTarget.hidden = false
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
  _terminar(mensaje, url, cantidad, grupo = null) {
    this._vaciarTanda()

    this.bannerTextoTarget.textContent = cantidad > 1
      ? `${mensaje} Se imprimieron ${cantidad} etiquetas.`
      : mensaje
    this.bannerTarget.hidden = false

    // «Facturar lo que hay» **cambia de momento, no de sentido**: medir nunca
    // se frena, y la excepción aparece después de guardar, solo si el
    // consolidado quedó incompleto. Es el flujo de la pizarra —*medir →
    // notificación → buscar el resto*—, y el modal y el sello son los de
    // siempre (`PasarGrupoIncompleto`).
    this._grupo = grupo
    const forzable = !!(grupo && grupo.consolidada && !grupo.completo && !grupo.cerrada &&
                        !grupo.parcial_autorizado && grupo.facturar_parcial_url)
    this.bannerFaltanTarget.hidden = !forzable
    this.bannerFacturarTarget.hidden = !forzable
    if (forzable) {
      const faltan = grupo.cajas.filter((c) => c.estado !== "medida")
      this.bannerFaltanTarget.textContent =
        `Faltan ${faltan.length} ${faltan.length === 1 ? "caja" : "cajas"} de ${grupo.numero} para que salga a pre-factura: ` +
        faltan.map((c) => `${c.wr || c.tracking} (${c.donde})`).join(", ") + "."
    }

    this._imprimir(url, cantidad)
  }

  _imprimir(url, cantidad = 1) {
    if (!url) { this.codigoTarget.focus(); return }

    // «Reimprimir» significa **lo último que se imprimió**, y el texto del
    // botón lo dice: era la pregunta de Jorge, *"¿cuál hace?"*. Vive en el
    // banner y en ningún otro lado: mientras se arma la tanda no hay nada que
    // reimprimir.
    this._ultimaEtiquetaUrl = url
    this.bannerReimprimirTextoTarget.textContent =
      cantidad > 1 ? `Reimprimir las ${cantidad} etiquetas` : "Reimprimir la etiqueta"
    this.bannerReimprimirTarget.hidden = false

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

  // Toda la tanda al piso: la mesa, los volúmenes y el grupo.
  _vaciarTanda() {
    this._paquete = null
    this._grupo = null
    this._reemplazaSesion = null
    this._anteriores = []
    this._yaCompleto = false
    this._mesa = []
    this._volumenes = []
    this._saltados = []
    this._notas = []
    this._pintarBotonNotas()
    this._limpiarNumeros()
    this._repintar()
  }

  // El `input` es lo que escucha `calc-volumetrico`: sin él, después de F5 el
  // cálculo seguía mostrando el volumen anterior con los campos ya vacíos.
  _limpiarNumeros() {
    [this.pesoTarget, this.altoTarget, this.largoTarget, this.anchoTarget].forEach((i) => {
      i.value = ""
      i.dispatchEvent(new Event("input", { bubbles: true }))
    })
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
    this.excepcionErrorTarget.hidden = true
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
          this.excepcionErrorTarget.hidden = false
          return
        }
        this.dispatch("guardado")
        this.avisoTarget.textContent = data.mensaje
        this.excepcionModalTarget.close()
        // Las etiquetas ya salieron al guardar —una por medición—; acá solo se
        // sella la excepción y el banner dice que se pasó. Nada que reimprimir.
        this._grupo = null
        this.bannerTextoTarget.textContent = data.mensaje
        this.bannerFaltanTarget.hidden = true
        this.bannerFacturarTarget.hidden = true
        this.codigoTarget.focus()
      })
  }

  // ── Teclado ─────────────────────────────────────────────────────────────

  teclaGlobal(e) {
    // F5 recarga la página en Chrome, así que se frena **siempre**, con modal
    // abierto o sin él: si se escapa, el operario pierde la mesa entera y no
    // hay nada guardado que recuperar.
    if (e.key === "F5") e.preventDefault()
    if (this._modalAbierto()) return
    // C29-13 · F9 guarda e imprime, como en el resto de la app: *"F9 para
    // imprimir siempre… solo para que lo tengamos uniforme"*. Reimprimir pasa
    // a F4, la de «imprimir un documento».
    // C30-02 · Y F8 también guarda —es «guardar» en todos lados desde la hoja
    // de Yusef—, en lugar de F10, que queda libre.
    if (e.key === "F9" || e.key === "F8") { e.preventDefault(); this.guardar() }
    if (e.key === "F4")  { e.preventDefault(); this.reimprimir() }
    if (e.key === "F5")  { this.agregarVolumen() }
    if (e.key === "F2")  { e.preventDefault(); this.limpiar() }
  }

  _modalAbierto() {
    return this.problemaModalTarget.open || this.excepcionModalTarget.open ||
           this.descarteModalTarget.open || this.mezclaModalTarget.open ||
           this.consolidadoModalTarget.open || this.autorizarModalTarget.open ||
           this.notasModalTarget.open || this.unirModalTarget.open || this.yaMedidoModalTarget.open
  }

  _enfocarPeso() {
    if (this._mesa.length === 0) return

    enfocar(this.pesoTarget)
    this.pesoTarget.select()
  }

  // C27-02 · El foco vuelve **al escaneo**, siempre: la mesa se arma pip a pip
  // y el peso se toca (o se llega con Enter en el campo vacío). Antes volvía al
  // peso, y con el bulto eso mandaba el segundo warehouse al campo del peso.
  //
  // C30-10 · Con `enfocar` y no con `focus()`: cerrar un modal con el dedo
  // dejaba el campo con cara de enfocado y sordo a la pistola (`enfocar.js`).
  _enfocarDondeToca() {
    if (this._volverAPeso) { this._volverAPeso = false; this._enfocarPeso(); return }
    enfocar(this.codigoTarget)
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
