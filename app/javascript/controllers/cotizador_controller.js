import { Controller } from "@hotwired/stimulus"

// PR-10.b: consulta el cobro estimado del flete mientras el operario llena el
// formulario. Yusef: "hay que agregarle para poder ver el valor a pagar...
// valor a pagar en dólares y lempiras".
//
// Solo display — el cobro definitivo lo calcula Pre-Factura. Este controller
// vive junto a `calc-volumetrico` en el mismo bloque; aquel hace el peso, este
// hace el dinero.
export default class extends Controller {
  static targets = ["panel", "precio", "subtotal", "isv", "total", "avisoMinimo", "nota"]
  static values = { url: String }

  connect() {
    // El cliente y el tipo de envío viven fuera de este bloque, así que se
    // escuchan a nivel de formulario en vez de por target.
    this._form = this.element.closest("form")
    this._onChange = () => this.cotizar()
    if (this._form) this._form.addEventListener("change", this._onChange)
    this.cotizar()
  }

  disconnect() {
    if (this._form) this._form.removeEventListener("change", this._onChange)
    clearTimeout(this._timeout)
  }

  cotizar() {
    clearTimeout(this._timeout)
    this._timeout = setTimeout(() => this._fetch(), 300)
  }

  async _fetch() {
    if (!this.hasUrlValue || !this._form) return

    const datos = new FormData(this._form)
    const params = new URLSearchParams()
    const campos = {
      tipo_envio_id: "paquete[tipo_envio_id]",
      cliente_id: "paquete[cliente_id]",
      proveedor_id: "paquete[proveedor_id]",
      sucursal_id: "paquete[sucursal_id]",
      peso: "paquete[peso]",
      alto: "paquete[alto]",
      largo: "paquete[largo]",
      ancho: "paquete[ancho]"
    }
    for (const [param, campo] of Object.entries(campos)) {
      const v = datos.get(campo)
      if (v) params.set(param, v)
    }

    // PR-C7.17: las cajas ya agregadas.
    //
    // Antes se cotizaba solo con los campos de captura, que `cajas-repetidor`
    // vacía al agregar — así que con dos cajas cargadas el cobro se desplomaba
    // al mínimo de servicio. Jorge lo vio: L.200 por un envío de 80 lb.
    //
    // Se mandan tal como viajan en el form (`paquete[cajas][N][campo]`) y el
    // servidor las totaliza. La suma NO se hace acá a propósito: la regla de
    // A9-03 —el mayor de cada caja, y después se suman— ya vive en Ruby, y una
    // tercera copia es la duplicación que PR-C7.11 vino a matar.
    let cajas = 0
    for (const [nombre, valor] of datos.entries()) {
      const m = nombre.match(/^paquete\[cajas\]\[(\d+)\]\[(\w+)\]$/)
      if (!m || !valor) continue
      params.append(`cajas[${m[1]}][${m[2]}]`, valor)
      cajas = Math.max(cajas, Number(m[1]))
    }
    // Con cajas cargadas manda el envío entero: la caja en curso todavía no es
    // una caja, y sumarla contaría lo que el operario aún está tecleando.
    if (cajas > 0) ["peso", "alto", "largo", "ancho"].forEach(c => params.delete(c))

    if (!params.get("tipo_envio_id")) return this._limpiar("Elegí el tipo de envío para ver el cobro.")

    try {
      const res = await fetch(`${this.urlValue}?${params}`, {
        headers: { Accept: "application/json" }
      })
      if (!res.ok) return this._limpiar("No se pudo calcular el cobro.")
      const d = await res.json()
      if (!d.ok) return this._limpiar("Elegí el tipo de envío para ver el cobro.")
      this._pintar(d)
    } catch (e) {
      console.warn("[cotizador] fallo la consulta:", e)
      this._limpiar("No se pudo calcular el cobro.")
    }
  }

  _pintar(d) {
    // Sin `precio_libra` el envío tiene cajas en escalones distintos: no hay un
    // precio por libra que mostrar. Se dice, en vez de dejar el de la consulta
    // anterior, que sería un número de otra cosa.
    if (d.precio_libra) {
      this._set(this.precioTarget, d.precio_libra)
    } else if (this.hasPrecioTarget) {
      this.precioTarget.textContent = "varía por caja"
    }
    this._set(this.subtotalTarget, d.subtotal)
    this._set(this.isvTarget, d.impuesto)
    this._set(this.totalTarget, d.total)

    if (this.hasAvisoMinimoTarget) {
      this.avisoMinimoTarget.classList.toggle("hidden", !d.aplico_minimo)
    }
    if (this.hasNotaTarget) {
      this.notaTarget.textContent = d.tarifa_encontrada
        ? `Tarifa del cliente · tasa L.${d.tasa}. El cobro definitivo se calcula en Pre-Factura.`
        : `Sin tarifa cargada para este servicio: se usa el precio base. Tasa L.${d.tasa}.`
    }
  }

  // "en dólares y lempiras" — los dos juntos, el lempira primero porque es la
  // moneda en la que se factura.
  _set(target, par) {
    if (!target || !par) return
    target.textContent = `L. ${this._fmt(par.lps)} · $${this._fmt(par.usd)}`
  }

  _limpiar(mensaje) {
    for (const t of [this.precioTarget, this.subtotalTarget, this.isvTarget, this.totalTarget]) {
      if (t) t.textContent = "—"
    }
    if (this.hasAvisoMinimoTarget) this.avisoMinimoTarget.classList.add("hidden")
    if (this.hasNotaTarget && mensaje) this.notaTarget.textContent = mensaje
  }

  _fmt(n) {
    return Number(n || 0).toLocaleString("en-US", {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2
    })
  }
}
