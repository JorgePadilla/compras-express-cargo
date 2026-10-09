# Las tarifas de categoría que quedaron del backfill viejo y hoy están cobrando.
#
# A7-25. Yusef lo encontró navegando el sistema, sin que nadie se lo dijera:
#
#   > "**Ya me acordé.** Yo hice categoría de precios al inicio, y después esta
#   >  es la que hice reciente. **Hay unas incongruencias.** No me había fijado
#   >  que tenías otra tabla del otro lado."
#   > "En teoría este servicio y la otra categoría **debería ser la misma tabla**."
#
# Tenía razón, y el problema es peor de lo que se ve en pantalla. Cuando se creó
# `tarifas` (PR-10.a), la migración hizo un `CROSS JOIN categoria_precios` y
# copió `precio_libra_aereo` / `precio_libra_maritimo` a una fila por
# (servicio × categoría). Después `TarifasPropuesta2026` sembró los precios de
# la hoja de Yusef, pero **solo pisó las combinaciones que la hoja declara**.
#
# Las que la hoja NO declara siguen ahí, con los precios de la tabla vieja, y en
# la cascada de `Tarifa.resolver` el nivel "categoría" **gana sobre el precio de
# lista**. O sea que no son un vestigio: son lo que se le cobra a esos clientes.
#
# Esta clase las encuentra. Borrarlas es decisión de quien corra la tarea.
class TarifasHuerfanas
  Hallazgo = Struct.new(:tarifa, :categoria, :servicio, :motivo, :precio_actual,
                        :precio_si_se_borra, keyword_init: true)

  # A7-26. Yusef fue explícito, y hoy el sistema hace lo contrario:
  #
  #   > "Si es mayorista, se va a aplicar **solo a los marítimos**."
  #
  # El backfill le dejó a Mayorista tarifa en los cinco servicios, así que hoy
  # un mayorista tiene precio preferencial también en los aéreos.
  MARITIMOS = %w[cem ckm].freeze
  SOLO_MARITIMOS = [ "Mayorista" ].freeze

  def self.detectar = new.detectar

  def detectar
    Tarifa.includes(:categoria_precio, :tipo_envio, :sucursal)
          .where.not(categoria_precio_id: nil)
          .filter_map { |t| evaluar(t) }
  end

  private

  def evaluar(tarifa)
    categoria = tarifa.categoria_precio&.nombre
    servicio  = tarifa.tipo_envio&.codigo
    return nil if categoria.blank? || servicio.blank?

    motivo = motivo_de(categoria, servicio)
    return nil if motivo.nil?

    Hallazgo.new(
      tarifa: tarifa, categoria: categoria, servicio: servicio, motivo: motivo,
      precio_actual: tarifa.precio_libra,
      precio_si_se_borra: precio_de_lista(tarifa)
    )
  end

  def motivo_de(categoria, servicio)
    declarada = TarifasPropuesta2026::CATEGORIA_TARIFAS[categoria]

    # La hoja de Yusef no conoce esta categoría: es del backfill entero.
    return "la hoja de precios no declara la categoría" if declarada.nil?

    if SOLO_MARITIMOS.include?(categoria) && !MARITIMOS.include?(servicio)
      return "mayorista solo aplica a marítimos (A7-26)"
    end

    # La categoría existe pero este servicio no está en la hoja.
    return "la hoja no declara este servicio para la categoría" unless declarada.key?(servicio)

    nil
  end

  # Qué pagaría ese cliente si la fila desapareciera: la tarifa de lista del
  # mismo servicio y tramo. Es el número que importa — la diferencia entre las
  # dos es lo que cambia de precio.
  def precio_de_lista(tarifa)
    Tarifa.activas
          .where(tipo_envio_id: tarifa.tipo_envio_id, categoria_precio_id: nil,
                 cliente_id: nil, proveedor_id: nil, sucursal_id: nil)
          .where("desde_libras <= ? AND (hasta_libras IS NULL OR hasta_libras > ?)",
                 tarifa.desde_libras, tarifa.desde_libras)
          .first&.precio_libra
  end
end
