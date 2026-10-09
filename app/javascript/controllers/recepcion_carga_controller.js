import { Controller } from "@hotwired/stimulus"

// C21-07 · «El aparatito» de recibir carga.
//
// Yusef: *"aquí es donde yo te digo que quiero el aparatito: que vengan ellos,
// llegan a recibir carga, y **escanean la caja** y automáticamente el sistema lo
// [pone]"*. Con pistola, y sobre poco volumen — *"como solo son 5 o 10 cajas lo
// más que se recibe"*.
//
// Mismo esqueleto que la pantalla de empacar: la pistola dispara Enter, cada
// resultado suena distinto porque el que recibe está mirando el camión, y el
// guard `_seq` evita que una respuesta vieja pinte o suene por una caja que ya
// no está en pantalla.
//
// C30-09 · El mismo controller monta la pistola **de la lista**, la que recibe
// cajas de cualquier manifiesto pendiente sin elegirlo antes. Yusef: *"a veces
// vamos a recibir tres manifiestos de un solo y hay que estar seleccionando
// cada manifiesto"*. Lo único que cambia es la URL y que, además de la caja, se
// repinta la fila de su manifiesto: *"algo que te vaya diciendo cuál quedó
// pendiente… si 7 cajas iban 6 nada más, falta una"*.
export default class extends Controller {
  static targets = ["codigo", "aviso", "contador"]
  static values = { escanearUrl: String }

  connect() {
    this._seq = 0
    if (this.hasCodigoTarget) this.codigoTarget.focus()
  }

  teclado(e) {
    if (e.key !== "Enter") return
    e.preventDefault()
    this.escanear()
  }

  escanear() {
    const codigo = this.codigoTarget.value.trim()
    if (codigo === "") return

    const consulta = (this._seq += 1)
    this.codigoTarget.value = ""

    const token = document.querySelector("meta[name='csrf-token']")?.content
    fetch(this.escanearUrlValue, {
      method: "POST",
      headers: { "Content-Type": "application/json", "Accept": "application/json", "X-CSRF-Token": token },
      body: JSON.stringify({ codigo })
    })
      .then((r) => r.json())
      .then((data) => {
        if (consulta !== this._seq) return
        this._resolver(data)
      })
      .catch(() => {
        this.dispatch("noEsDeAqui")
        this._mostrar("noEsDeAqui", "No se pudo consultar. Probá de nuevo.")
      })
  }

  // Los `dispatch` van con el nombre literal, uno por rama, para que
  // `sonidos_cableados_test` pueda probarlos leyendo el archivo.
  //
  // C30-09 · La caja que **completa** su manifiesto suena a `completo`, el de
  // los tres tonos de la Medición (C28-11), y no al pip de siempre: Yusef pidió
  // *"algo como lo que hiciste de medición"*, y ahí se oye que terminó el
  // grupo, no que entró una caja más. Uno u otro, nunca los dos encimados.
  _resolver(data) {
    const completo = data.resultado === "ok" && data.manifiesto?.completo
    switch (data.resultado) {
      case "ok":
        if (completo) this.dispatch("completo")
        else this.dispatch("ok")
        break
      case "ya_recibida":   this.dispatch("yaRecibida"); break
      default:              this.dispatch("noEsDeAqui")
    }
    this._mostrar(this._tono(data.resultado), data.mensaje)
    if (data.resultado === "ok") this._marcarRecibida(data.caja_id, data.faltan)
    if (data.manifiesto) this._pintarFila(data.manifiesto)
    this.codigoTarget.focus()
  }

  // C30-09 · La fila del manifiesto en la lista: «6 de 7 · falta 1» y cuáles.
  // En la pantalla de un manifiesto no hay filas así y esto no hace nada.
  _pintarFila(progreso) {
    const fila = this.element.querySelector(`[data-manifiesto-fila="${progreso.id}"]`)
    if (!fila) return

    const texto = fila.querySelector("[data-progreso-texto]")
    if (texto) {
      texto.textContent = progreso.texto
      // Los dos colores, no solo uno: con `text-gray-900` puesto del server,
      // agregarle `text-cec-teal` encima no se vería — gana el que Tailwind
      // emite después, el mismo cuento que `.hidden` contra `.inline-flex`.
      texto.classList.toggle("text-cec-teal", progreso.completo)
      texto.classList.toggle("text-gray-900", !progreso.completo)
    }
    const faltan = fila.querySelector("[data-progreso-faltan]")
    if (faltan) {
      faltan.textContent = progreso.faltantes.length > 0 ? `Falta: ${progreso.faltantes.join(", ")}` : ""
    }
    // La última fila tocada queda marcada: con cinco manifiestos en la lista,
    // el que recibe tiene que ver **cuál** se movió, no buscarlo.
    this.element.querySelectorAll("[data-manifiesto-fila].bg-cec-teal\\/10")
      .forEach((otra) => otra.classList.remove("bg-cec-teal/10"))
    fila.classList.add("bg-cec-teal/10")
  }

  _tono(resultado) {
    return { ok: "ok", ya_recibida: "yaRecibida" }[resultado] || "noEsDeAqui"
  }

  _mostrar(evento, mensaje) {
    if (!this.hasAvisoTarget) return
    const tonos = {
      ok: "bg-cec-teal/10 text-cec-teal-dark",
      yaRecibida: "bg-cec-gold/15 text-cec-navy",
      noEsDeAqui: "bg-red-50 text-red-800"
    }
    this.avisoTarget.className = `mt-4 rounded-lg p-3 text-sm ${tonos[evento] || tonos.noEsDeAqui}`
    this.avisoTarget.textContent = mensaje
    this.avisoTarget.classList.remove("hidden")
  }

  _marcarRecibida(cajaId, faltan) {
    const celda = this.element.querySelector(`[data-caja-estado="${cajaId}"]`)
    if (celda) {
      celda.innerHTML = ""
      const badge = document.createElement("span")
      badge.className = "inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-cec-teal/10 text-cec-teal"
      badge.textContent = "Recibida"
      celda.appendChild(badge)
    }
    if (this.hasContadorTarget && typeof faltan === "number") {
      const total = this.element.querySelectorAll("[data-caja-fila]").length
      this.contadorTarget.textContent = `${total - faltan} de ${total} recibidas`
    }
  }
}
