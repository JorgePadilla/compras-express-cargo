# C30-19 · La **etiqueta de entrega** 4×6 de una pre-factura (PR-P.3).
#
# Es la etiqueta de `C26-12` —*"ésa es la que van a escanear para entregar"*—,
# y Yusef la describió así en el recorrido del 2026-10-09:
#
#   > "Viene siendo como una de éstas en grande. Solo que trae un **QR para
#   >  entregarle al cliente**, trae el **tipo de envío**, a qué
#   >  **prefactura** está amarrada, el **código del cliente, el nombre**, las
#   >  **libras a cobrar**… y el **volumen**, para que el cliente sepa cuánto
#   >  fue el volumen y cuánto fue el peso, la **sucursal donde se retira**, la
#   >  fecha."
#   > "Lo que ocupo más grande son **la sucursal y el nombre del cliente**… y
#   >  el tipo de envío."
#
# Acá se juntan los datos; cómo se ven lo decide
# `pre_facturas/etiqueta_entrega` con el layout `etiqueta_entrega`.
#
# ── Provisorio hasta `RP-82` ─────────────────────────────────────────────
#
# Yusef no dijo si es **una por pre-factura o una por volumen** («1 de 3»), ni
# qué es «el volumen»: ¿pies³, VLBS, o cuántos volúmenes? Mientras tanto:
#
#   · **una por pre-factura** — es la que se escanea al entregar, y lo que se
#     entrega es la pre-factura entera (*"y esto lo van a empacar en una
#     sola"*, `C26-12`);
#   · el volumen va como **VLBS totales y cuántos volúmenes** son, que es lo
#     que pone en la mano la cifra que se cobra y lo que hay que juntar.
#
# Si `RP-82` contesta otra cosa, cambia este archivo y la vista; el QR y el
# resto no se mueven.
class EtiquetaDeEntrega
  attr_reader :pre_factura

  def initialize(pre_factura)
    @pre_factura = pre_factura
  end

  # El QR de la entrega: `ENT PF-000123`. Con **espacio**, no `|`: es el mismo
  # razonamiento que el QR de medición (`etiqueta_qr_medicion`) — una pistola
  # por teclado en distribución es-419 puede no entregar la barra. El prefijo
  # dice qué es lo que se escaneó, como `MED`.
  def qr = "ENT #{pre_factura.numero}"

  def numero = pre_factura.numero

  def cliente = pre_factura.cliente

  def cliente_codigo = cliente&.codigo

  def cliente_nombre = cliente&.nombre_completo

  # Los tipos de envío de lo que se cobra: «CER», o «CER · CKA» si la
  # pre-factura mezcla. Sin paquetes —una pre-factura armada a mano solo con
  # cargos— no se inventa ninguno.
  def tipo_envio
    paquetes.filter_map { |p| p.tipo_envio&.nombre.presence }.uniq.sort.join(" · ").presence
  end

  # Las libras **a cobrar**: la suma del peso de las líneas de flete. Las
  # líneas automáticas (recolecta, cambio de servicio) y los cargos a mano sin
  # peso no son libras.
  def libras
    lineas_de_flete.sum { |i| i.peso_cobrar.to_d }
  end

  # ── El volumen (provisorio, `RP-82`) ──────────────────────────────────
  #
  # Un volumen es una **medición** de San Pedro (`Bulto`, `C27-06`: *"es una
  # etiqueta por medición"*). Un paquete que no pasó por Medición cuenta como
  # su propio volumen, con el volumétrico de Miami: así una pre-factura hecha a
  # mano también dice algo, en vez de «0».
  def volumenes = bultos.size + paquetes_sin_medir.size

  def vlbs
    bultos.sum { |b| b.peso_volumetrico.to_d } + paquetes_sin_medir.sum { |p| p.peso_volumetrico.to_d }
  end

  # Dónde retira: la del paquete (`paquetes.sucursal`, *"dónde RETIRA el
  # cliente"*), y si ningún paquete la tiene, la de la ficha del cliente. Si
  # los paquetes dicen dos, gana la que más se repite: la etiqueta va pegada
  # en **una** bolsa.
  def sucursal
    de_paquetes = paquetes.filter_map(&:sucursal)
    return de_paquetes.tally.max_by { |_s, n| n }.first if de_paquetes.any?

    cliente&.sucursal_retiro
  end

  def sucursal_nombre = sucursal&.nombre

  # La fecha **en que se le entrega** —*"no la que se entregó, sino la que
  # es"*—: la hora del aviso cuando exista (`notificar_at`, PR-P.2), y si no,
  # la fecha de trabajo de la pre-factura. Con hora solo cuando la hay.
  def fecha
    if pre_factura.respond_to?(:notificar_at) && pre_factura.notificar_at.present?
      pre_factura.notificar_at.strftime("%d/%m/%Y %H:%M")
    else
      (pre_factura.fecha_trabajo || pre_factura.created_at&.to_date)&.strftime("%d/%m/%Y")
    end
  end

  # C30-18 · Con F8 la pre-factura queda **consolidando** y la etiqueta sale
  # con la franja atravesada. La columna `consolidando_at` la trae PR-P.2:
  # hasta entonces esto contesta `false` y la franja no sale nunca. Se
  # pregunta con `respond_to?` y no con `has_attribute?` para que un test
  # pueda dar vuelta una pre-factura sin la columna.
  def consolidando?
    pre_factura.respond_to?(:consolidando_at) && pre_factura.consolidando_at.present?
  end

  private

  def lineas_de_flete
    @lineas_de_flete ||= pre_factura.pre_factura_items.select do |i|
      i.origen == "manual" && i.peso_cobrar.present?
    end
  end

  def paquetes
    @paquetes ||= pre_factura.paquetes.includes(:tipo_envio, :sucursal).to_a
  end

  def sesiones = paquetes.filter_map(&:medicion_sesion).uniq

  def bultos
    @bultos ||= sesiones.empty? ? [] : Bulto.where(sesion: sesiones).to_a
  end

  # Los que no tienen un `Bulto` que los ampare: sin sesión, o con una sesión
  # de antes de C27 que no dejó bulto. Si no, se caerían de la cuenta.
  def paquetes_sin_medir
    medidas = bultos.map(&:sesion).to_set
    paquetes.reject { |p| p.medicion_sesion.present? && medidas.include?(p.medicion_sesion) }
  end
end
